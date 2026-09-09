import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../utils/time_util.dart';
import 'platform_adaptive.dart';

/// =============================================================
/// 闹钟卡片
/// -------------------------------------------------------------
/// 结构：大号 24 小时制时间 + 标题/重复规则 + 下次响铃倒计时 + 开关
/// =============================================================
class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Alarm alarm;

  /// 点击进入编辑
  final VoidCallback onTap;

  /// 开关切换
  final ValueChanged<bool> onToggle;

  /// 删除
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool enabled = alarm.enabled;

    // 计算下一次响铃时间
    final DateTime next = TimeUtil.nextOccurrence(
      hour: alarm.hour,
      minute: alarm.minute,
      weekday: alarm.repeatDays.isEmpty ? null : _nearestWeekday(alarm.repeatDays),
      oneShotDate: alarm.oneShotDate,
    );

    return Dismissible(
      key: ValueKey<String>('alarm_${alarm.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // 交给 Provider 删除
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: AppColors.card,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                // 左侧：时间 + 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          // 24 小时制大号时间
                          Text(
                            TimeUtil.alarmTime(alarm),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              letterSpacing: 0.5,
                              color: enabled
                                  ? AppColors.textPrimary
                                  : AppColors.doneGrey,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // 来源标签
                          if (alarm.fromMemo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '来自备忘录',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 标题
                      Text(
                        alarm.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.doneGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 重复规则 + 下次响铃
                      Text(
                        enabled
                            ? '${TimeUtil.repeatText(alarm.repeatDays)} · ${TimeUtil.countdownText(next)}响铃'
                            : '${TimeUtil.repeatText(alarm.repeatDays)} · 已关闭',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // 正在贪睡时给出提示
                      if (alarm.snoozedUntil != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '已贪睡至 ${TimeUtil.hhmm(alarm.snoozedUntil!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.priorityMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 右侧：开关
                adaptiveSwitch(
                  value: enabled,
                  activeColor: AppColors.accent,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 找到离今天最近的重复星期（用于展示"还有多久响铃"）
  int _nearestWeekday(List<int> days) {
    final int today = DateTime.now().weekday;
    final List<int> sorted = List<int>.from(days)..sort();
    for (final int d in sorted) {
      if (d >= today) return d;
    }
    return sorted.first;
  }
}
