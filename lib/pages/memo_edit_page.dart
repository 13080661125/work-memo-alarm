import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../models/memo.dart';
import '../providers/alarm_provider.dart';
import '../providers/memo_provider.dart';
import '../utils/time_util.dart';
import '../widgets/platform_adaptive.dart';
import 'alarm_edit_page.dart';

/// =============================================================
/// 备忘录新建 / 编辑页
/// -------------------------------------------------------------
/// 字段：标题、正文、优先级、完成状态、绑定提醒
/// 保存时若该备忘录绑定了闹钟，会把闹钟 id 一起写回备忘录。
/// =============================================================
class MemoEditPage extends StatefulWidget {
  const MemoEditPage({super.key, this.memo});

  /// 传入表示编辑，不传表示新建
  final Memo? memo;

  @override
  State<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends State<MemoEditPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();

  MemoPriority _priority = MemoPriority.medium;
  bool _done = false;

  bool get _isEdit => widget.memo != null;

  @override
  void initState() {
    super.initState();
    final Memo? memo = widget.memo;
    if (memo != null) {
      // 编辑：回填已有数据
      _titleCtrl.text = memo.title;
      _contentCtrl.text = memo.content;
      _priority = memo.priority;
      _done = memo.done;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  /// 当前绑定的闹钟（从闹钟 Provider 里实时查，避免本地缓存不同步）
  Alarm? get _boundAlarm {
    final String? memoId = widget.memo?.id;
    if (memoId == null) return null;
    return context.read<AlarmProvider>().byMemoId(memoId);
  }

  @override
  Widget build(BuildContext context) {
    // watch 闹钟数据：设置/修改提醒后，本页面显示的提醒信息会自动刷新
    context.watch<AlarmProvider>();
    final Alarm? bound = _boundAlarm;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑备忘录' : '新建备忘录'),
        actions: <Widget>[
          // 保存按钮
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
          // ---------- 标题 ----------
          _sectionTitle('标题'),
          _inputCard(
            child: TextField(
              controller: _titleCtrl,
              maxLength: 50,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '例如：周会纪要 / 客户需求确认',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),

          // ---------- 正文 ----------
          _sectionTitle('正文'),
          _inputCard(
            child: TextField(
              controller: _contentCtrl,
              maxLines: 8,
              minLines: 6,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: '记录工作内容、待办事项……',
                border: InputBorder.none,
              ),
            ),
          ),

          // ---------- 优先级 ----------
          _sectionTitle('优先级'),
          _inputCard(
            child: Row(
              children: <Widget>[
                _priorityItem(MemoPriority.high),
                _priorityItem(MemoPriority.medium),
                _priorityItem(MemoPriority.low),
              ],
            ),
          ),

          // ---------- 完成状态（仅编辑时显示） ----------
          if (_isEdit) ...<Widget>[
            _sectionTitle('状态'),
            _inputCard(
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_outline,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('标记为已完成',
                        style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                  ),
                  adaptiveSwitch(
                    value: _done,
                    activeColor: AppColors.accent,
                    onChanged: (bool v) => setState(() => _done = v),
                  ),
                ],
              ),
            ),
          ],

          // ---------- 提醒闹钟 ----------
          _sectionTitle('提醒闹钟'),
          _inputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.alarm, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: bound == null
                          ? const Text('未设置提醒',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textSecondary))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${TimeUtil.alarmTime(bound)} · ${TimeUtil.repeatText(bound.repeatDays)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bound.enabled ? '提醒已开启' : '提醒已关闭',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    // 设置 / 修改提醒
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openAlarmEdit(context),
                        icon: Icon(bound == null ? Icons.add_alarm : Icons.edit),
                        label: Text(bound == null ? '设置提醒' : '修改提醒'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    // 清除提醒
                    if (bound != null) ...<Widget>[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _clearAlarm(context, bound),
                          icon: const Icon(Icons.alarm_off),
                          label: const Text('清除提醒'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
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
                label: const Text('删除这条备忘录'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          // 说明：为什么新备忘录要先保存
          if (!_isEdit) ...<Widget>[
            const SizedBox(height: 16),
            const Text(
              '提示：新建的备忘录保存后，才能设置提醒闹钟。',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// 打开闹钟编辑页（为该备忘录绑定提醒）
  Future<void> _openAlarmEdit(BuildContext context) async {
    final Memo? memo = widget.memo;
    if (memo == null) {
      showAdaptiveToast(context, '请先保存备忘录，再设置提醒');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => AlarmEditPage(
          memoId: memo.id,
          memoTitle: _titleCtrl.text.trim().isEmpty ? memo.title : _titleCtrl.text.trim(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 清除该备忘录绑定的提醒
  Future<void> _clearAlarm(BuildContext context, Alarm alarm) async {
    final bool? ok = await showAdaptiveConfirmDialog(
      context: context,
      title: '清除提醒',
      content: '将删除这条备忘录绑定的闹钟，备忘录本身不受影响。',
      confirmText: '清除',
      destructive: true,
    );
    if (ok == true && mounted) {
      await context.read<AlarmProvider>().remove(alarm.id);
      if (mounted) setState(() {});
    }
  }

  /// 优先级选择项
  Widget _priorityItem(MemoPriority priority) {
    final bool selected = _priority == priority;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _priority = priority),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? priority.color.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? priority.color : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (selected)
                  Icon(Icons.check, size: 16, color: priority.color)
                else
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: priority.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  '${priority.label}优先级',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? priority.color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 保存
  Future<void> _save() async {
    final String title = _titleCtrl.text.trim();
    final String content = _contentCtrl.text.trim();

    if (title.isEmpty && content.isEmpty) {
      showAdaptiveToast(context, '标题和正文不能同时为空');
      return;
    }

    final MemoProvider provider = context.read<MemoProvider>();
    final AlarmProvider alarmProvider = context.read<AlarmProvider>();

    if (_isEdit) {
      // 编辑：在旧对象基础上覆盖字段
      final Memo old = widget.memo!;
      final Memo updated = old.copyWith(
        title: title.isEmpty ? '（无标题）' : title,
        content: content,
        priority: _priority,
        done: _done,
      );
      await provider.update(updated);
    } else {
      // 新建
      final Memo memo = Memo(
        id: 'memo_${DateTime.now().microsecondsSinceEpoch}',
        title: title.isEmpty ? '（无标题）' : title,
        content: content,
        priority: _priority,
      );
      await provider.add(memo);
    }

    if (!mounted) return;
    showAdaptiveToast(context, '已保存');
    Navigator.of(context).pop();
  }

  /// 删除
  Future<void> _delete() async {
    final Memo? memo = widget.memo;
    if (memo == null) return;
    final bool? ok = await showAdaptiveConfirmDialog(
      context: context,
      title: '删除备忘录',
      content: '删除后不可恢复，绑定的提醒闹钟也会一并删除。',
      confirmText: '删除',
      destructive: true,
    );
    if (ok == true && mounted) {
      await context.read<MemoProvider>().remove(memo.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  /// 分区标题
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

  /// 白色卡片容器
  Widget _inputCard({required Widget child}) {
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
