import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../providers/memo_provider.dart';
import '../services/ringing_service.dart';
import '../utils/time_util.dart';
import '../widgets/platform_adaptive.dart';

/// =============================================================
/// 闹钟新建 / 编辑页
/// -------------------------------------------------------------
/// 两种进入方式：
///   1. 闹钟页点"新建/编辑"：memoId 为空，是独立闹钟
///   2. 备忘录点"设置提醒"：传入 memoId，保存后自动与备忘录建立绑定
/// =============================================================
class AlarmEditPage extends StatefulWidget {
  const AlarmEditPage({super.key, this.alarm, this.memoId, this.memoTitle});

  /// 编辑已有闹钟
  final Alarm? alarm;

  /// 从备忘录进入时的备忘录 id
  final String? memoId;

  /// 从备忘录进入时的默认标题
  final String? memoTitle;

  @override
  State<AlarmEditPage> createState() => _AlarmEditPageState();
}

class _AlarmEditPageState extends State<AlarmEditPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  late int _hour;
  late int _minute;
  late List<int> _repeatDays;
  late String _ringtoneId;
  late bool _vibrate;
  late DateTime _oneShotDate;

  /// 当前正在编辑的闹钟（新建时为 null）
  Alarm? _existing;

  @override
  void initState() {
    super.initState();

    // 优先级：直接传入的 alarm > 该备忘录已绑定的闹钟
    Alarm? alarm = widget.alarm;
    if (alarm == null && widget.memoId != null) {
      alarm = context.read<AlarmProvider>().byMemoId(widget.memoId!);
    }
    _existing = alarm;

    final DateTime now = DateTime.now();
    if (alarm != null) {
      _hour = alarm.hour;
      _minute = alarm.minute;
      _repeatDays = List<int>.from(alarm.repeatDays);
      _ringtoneId = alarm.ringtoneId;
      _vibrate = alarm.vibrate;
      _oneShotDate = alarm.oneShotDate ?? now;
      _titleCtrl.text = alarm.title;
      _noteCtrl.text = alarm.note ?? '';
    } else {
      // 默认：下一个整点（避免默认时间已过导致立刻响铃）
      _hour = now.hour;
      _minute = 0;
      _repeatDays = <int>[];
      _ringtoneId = kRingtones.first.id;
      _vibrate = true;
      _oneShotDate = now;
      _titleCtrl.text = widget.memoTitle ?? '工作提醒';
    }
  }

  @override
  void dispose() {
    // 离开页面时停止试听，避免铃声一直响
    RingingService.instance.stopPreview();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => _existing != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑闹钟' : '新建闹钟'),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('保存',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          // ---------- 时间 ----------
          _sectionTitle('提醒时间（24 小时制）'),
          _card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickTime,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---------- 重复周期 ----------
          _sectionTitle('重复周期'),
          _card(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(7, (int i) {
                    final int day = i + 1; // 1=周一 ... 7=周日
                    return _weekdayItem(day);
                  }),
                ),
                const SizedBox(height: 12),
                // 快捷选择
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _quickChip('每天', <int>[1, 2, 3, 4, 5, 6, 7]),
                    _quickChip('工作日', <int>[1, 2, 3, 4, 5]),
                    _quickChip('周末', <int>[6, 7]),
                    _quickChip('仅一次', <int>[]),
                  ],
                ),
              ],
            ),
          ),

          // ---------- 一次性日期（未设置重复时显示） ----------
          if (_repeatDays.isEmpty) ...<Widget>[
            _sectionTitle('提醒日期'),
            _card(
              child: InkWell(
                onTap: _pickDate,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        TimeUtil.mmdd(_oneShotDate) == TimeUtil.mmdd(DateTime.now())
                            ? '今天（${TimeUtil.mmdd(_oneShotDate)}）'
                            : TimeUtil.full(_oneShotDate).substring(0, 10),
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],

          // ---------- 标题 / 备注 ----------
          _sectionTitle('提醒内容'),
          _card(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: '标题，例如：提交周报',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const Divider(color: AppColors.divider),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '备注（可选，会显示在通知上）',
                    border: InputBorder.none,
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          // ---------- 铃声 ----------
          _sectionTitle('铃声'),
          _card(
            child: InkWell(
              onTap: _pickRingtone,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.music_note_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ringtoneById(_ringtoneId).name,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // ---------- 震动 ----------
          _sectionTitle('震动'),
          _card(
            child: Row(
              children: <Widget>[
                const Icon(Icons.vibration, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('响铃时同时震动',
                      style:
                          TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                ),
                adaptiveSwitch(
                  value: _vibrate,
                  activeColor: AppColors.accent,
                  onChanged: (bool v) => setState(() => _vibrate = v),
                ),
              ],
            ),
          ),

          // ---------- 下次响铃提示 ----------
          const SizedBox(height: 12),
          Center(
            child: Text(
              _nextFireTip(),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),

          // ---------- 删除 ----------
          if (_isEdit) ...<Widget>[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除这个闹钟'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          // 后台保活提示（安卓尤其重要）
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '为保证后台准时响铃，请在「设置」中开启通知权限、精确闹钟权限，'
                    '并将本应用加入电池优化白名单（安卓）。',
                    style: TextStyle(
                        fontSize: 12, height: 1.5, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 选择时间（平台自适应）
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showAdaptiveTimePicker(
      context,
      TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null && mounted) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  /// 选择一次性提醒的日期
  Future<void> _pickDate() async {
    final DateTime? picked = await showAdaptiveDatePicker(context, _oneShotDate);
    if (picked != null && mounted) {
      setState(() => _oneShotDate = picked);
    }
  }

  /// 星期选择按钮
  Widget _weekdayItem(int day) {
    final bool selected = _repeatDays.contains(day);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        setState(() {
          if (selected) {
            _repeatDays.remove(day);
          } else {
            _repeatDays.add(day);
            _repeatDays.sort();
          }
        });
      },
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          TimeUtil.weekdayShort[day],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 快捷选择标签
  Widget _quickChip(String label, List<int> days) {
    bool same() {
      if (_repeatDays.length != days.length) return false;
      final List<int> a = List<int>.from(_repeatDays)..sort();
      final List<int> b = List<int>.from(days)..sort();
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    final bool selected = same();
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _repeatDays = List<int>.from(days)),
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  /// 选择铃声（底部弹窗，可试听）
  Future<void> _pickRingtone() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('选择铃声',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              ...kRingtones.map((RingtoneItem item) {
                return ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: _ringtoneId == item.id
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  title: Text(item.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 试听
                      TextButton(
                        onPressed: () =>
                            RingingService.instance.preview(item.id),
                        child: const Text('试听'),
                      ),
                      if (_ringtoneId == item.id)
                        const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ),
                  onTap: () {
                    setState(() => _ringtoneId = item.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    // 关闭弹窗后停止试听
    await RingingService.instance.stopPreview();
  }

  /// 底部提示：下次什么时候响
  String _nextFireTip() {
    final DateTime next = TimeUtil.nextOccurrence(
      hour: _hour,
      minute: _minute,
      weekday: _repeatDays.isEmpty ? null : _nearestWeekday(_repeatDays),
      oneShotDate: _repeatDays.isEmpty ? _oneShotDate : null,
    );
    return '将在 ${TimeUtil.friendly(next)} 响铃（${TimeUtil.countdownText(next)}）';
  }

  int _nearestWeekday(List<int> days) {
    final int today = DateTime.now().weekday;
    final List<int> sorted = List<int>.from(days)..sort();
    for (final int d in sorted) {
      if (d >= today) return d;
    }
    return sorted.first;
  }

  /// 保存
  Future<void> _save() async {
    final AlarmProvider alarmProvider = context.read<AlarmProvider>();
    final String title =
        _titleCtrl.text.trim().isEmpty ? '工作提醒' : _titleCtrl.text.trim();

    Alarm target;
    if (_existing != null) {
      // 编辑
      target = _existing!.copyWith(
        title: title,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        hour: _hour,
        minute: _minute,
        repeatDays: _repeatDays,
        ringtoneId: _ringtoneId,
        vibrate: _vibrate,
        // 重复闹钟不需要日期；一次性闹钟保存日期
        oneShotDate: _repeatDays.isEmpty ? _oneShotDate : null,
      );
      await alarmProvider.update(target);
    } else {
      // 新建
      target = Alarm(
        id: 'alarm_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        hour: _hour,
        minute: _minute,
        repeatDays: _repeatDays,
        ringtoneId: _ringtoneId,
        vibrate: _vibrate,
        source: widget.memoId != null ? AlarmSource.memo : AlarmSource.manual,
        memoId: widget.memoId,
        oneShotDate: _repeatDays.isEmpty ? _oneShotDate : null,
        notifBase: alarmProvider.nextNotifBase(),
      );
      await alarmProvider.add(target);
    }

    // 如果是从备忘录进来的，把闹钟 id 回写到备忘录
    if (widget.memoId != null) {
      await context.read<MemoProvider>().setAlarmId(widget.memoId!, target.id);
    }

    if (!mounted) return;
    showAdaptiveToast(context, _isEdit ? '闹钟已更新' : '闹钟已创建');
    Navigator.of(context).pop('saved');
  }

  /// 删除
  Future<void> _delete() async {
    final Alarm? alarm = _existing;
    if (alarm == null) return;
    final bool? ok = await showAdaptiveConfirmDialog(
      context: context,
      title: '删除闹钟',
      content: widget.memoId != null
          ? '删除后，该备忘录将不再有提醒。'
          : '删除后不可恢复。',
      confirmText: '删除',
      destructive: true,
    );
    if (ok == true && mounted) {
      await context.read<AlarmProvider>().remove(alarm.id);
      if (widget.memoId != null && mounted) {
        await context.read<MemoProvider>().setAlarmId(widget.memoId!, null);
      }
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
