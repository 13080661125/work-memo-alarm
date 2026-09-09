import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../models/memo.dart';
import '../utils/time_util.dart';

/// =============================================================
/// 备忘录卡片
/// -------------------------------------------------------------
/// 结构：左侧优先级色条 + 勾选框 + 标题/正文/时间 + 提醒标签
/// =============================================================
class MemoCard extends StatelessWidget {
  const MemoCard({
    super.key,
    required this.memo,
    required this.boundAlarm,
    required this.onTap,
    required this.onToggleDone,
    required this.onDelete,
  });

  final Memo memo;

  /// 该备忘录绑定的闹钟（可能为 null，由列表页查出来传进来）
  final Alarm? boundAlarm;

  /// 点击进入编辑
  final VoidCallback onTap;

  /// 勾选完成
  final VoidCallback onToggleDone;

  /// 删除
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool done = memo.done;

    return Dismissible(
      key: ValueKey<String>('memo_${memo.id}'),
      // 从右往左滑动删除
      direction: DismissDirection.endToStart,
      confirmDismiss: (DismissDirection direction) async {
        onDelete();
        // 返回 false：不真正 dismiss，交给 Provider 删除后重建列表，避免动画与数据不同步
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
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
          child: Container(
            // 左侧优先级色条
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: done ? AppColors.doneGrey : memo.priority.color,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 完成勾选框
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: done,
                        onChanged: (_) => onToggleDone(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        activeColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 标题
                    Expanded(
                      child: Text(
                        memo.title.isEmpty ? '（无标题）' : memo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: done ? AppColors.doneGrey : AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 优先级标签
                    _PriorityChip(priority: memo.priority, dimmed: done),
                  ],
                ),
                // 正文预览（最多两行）
                if (memo.content.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      memo.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: done ? AppColors.doneGrey : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // 底部：时间 + 提醒标签
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        TimeUtil.friendly(memo.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // 绑定了提醒 → 显示提醒时间
                      if (boundAlarm != null) ...<Widget>[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.alarm,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '${TimeUtil.alarmTime(boundAlarm!)} · ${TimeUtil.repeatText(boundAlarm!.repeatDays)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 优先级小标签
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority, required this.dimmed});

  final MemoPriority priority;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (dimmed ? AppColors.doneGrey : priority.color).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: dimmed ? AppColors.doneGrey : priority.color,
        ),
      ),
    );
  }
}
