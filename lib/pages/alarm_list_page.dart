import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../widgets/alarm_card.dart';
import '../widgets/empty_view.dart';
import '../widgets/platform_adaptive.dart';
import 'alarm_edit_page.dart';
import 'settings_page.dart';

/// =============================================================
/// 闹钟列表页（首页第二个标签页）
/// -------------------------------------------------------------
/// 展示全部闹钟（含备忘录绑定的提醒），支持开关、编辑、滑动删除
/// =============================================================
class AlarmListPage extends StatelessWidget {
  const AlarmListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AlarmProvider provider = context.watch<AlarmProvider>();
    final List<Alarm> list = provider.alarms;

    // 排序：已开启的在前，其次按时间从早到晚
    final List<Alarm> sorted = List<Alarm>.from(list)
      ..sort((Alarm a, Alarm b) {
        if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
        final int t = (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
        if (t != 0) return t;
        return a.createdAt.compareTo(b.createdAt);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('闹钟提醒'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '共 ${list.length} 个闹钟 · 已开启 ${provider.enabledCount} 个',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const EmptyView(
                    icon: Icons.alarm_outlined,
                    title: '还没有闹钟',
                    subtitle: '点击右下角新建闹钟，也可以在备忘录里直接绑定提醒时间',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: sorted.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Alarm alarm = sorted[index];
                      return AlarmCard(
                        alarm: alarm,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AlarmEditPage(alarm: alarm),
                            ),
                          );
                        },
                        onToggle: (bool v) => context
                            .read<AlarmProvider>()
                            .setEnabled(alarm.id, v),
                        onDelete: () => _confirmDelete(context, alarm),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AlarmEditPage()),
          );
        },
        icon: const Icon(Icons.add_alarm),
        label: const Text('新建闹钟'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// 删除确认
  Future<void> _confirmDelete(BuildContext context, Alarm alarm) async {
    final bool? ok = await showAdaptiveConfirmDialog(
      context: context,
      title: '删除闹钟',
      content: '确定删除「${alarm.title}」这个闹钟吗？',
      confirmText: '删除',
      destructive: true,
    );
    if (ok == true && context.mounted) {
      await context.read<AlarmProvider>().remove(alarm.id);
      if (context.mounted) showAdaptiveToast(context, '已删除');
    }
  }
}
