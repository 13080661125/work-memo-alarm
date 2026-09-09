import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// =============================================================
/// 备忘录数据模型
/// -------------------------------------------------------------
/// 一条工作笔记 = 标题 + 正文 + 优先级 + 完成状态 + 时间 + （可选）绑定的提醒闹钟。
/// 说明：提醒时间本身不存两份，而是通过 [alarmId] 关联到闹钟模块的 Alarm 对象，
///     这样"备忘录提醒"与"独立闹钟"在数据层面完全统一，避免两边数据不同步。
/// =============================================================

/// 备忘录优先级
enum MemoPriority {
  low, // 低
  medium, // 中
  high, // 高
}

/// 优先级扩展：中文名、颜色、排序权重
extension MemoPriorityExt on MemoPriority {
  /// 中文显示名
  String get label {
    switch (this) {
      case MemoPriority.high:
        return '高';
      case MemoPriority.medium:
        return '中';
      case MemoPriority.low:
        return '低';
    }
  }

  /// 卡片左侧色条 / 标签颜色（红=高、橙=中、绿=低，符合国内使用习惯）
  Color get color {
    switch (this) {
      case MemoPriority.high:
        return AppColors.priorityHigh;
      case MemoPriority.medium:
        return AppColors.priorityMedium;
      case MemoPriority.low:
        return AppColors.priorityLow;
    }
  }

  /// 排序权重：值越大越靠前（用于"按优先级排序"）
  int get weight {
    switch (this) {
      case MemoPriority.high:
        return 3;
      case MemoPriority.medium:
        return 2;
      case MemoPriority.low:
        return 1;
    }
  }

  /// 存储用的字符串
  String get key => name;

  /// 从字符串还原（老数据兼容：读不到时默认"中"）
  static MemoPriority fromKey(String? key) {
    return MemoPriority.values.firstWhere(
      (MemoPriority p) => p.name == key,
      orElse: () => MemoPriority.medium,
    );
  }
}

/// 备忘录排序方式
enum MemoSortMode {
  createDesc, // 创建时间：最新在前（默认）
  createAsc, // 创建时间：最早在前
  priorityDesc, // 优先级：高 → 低
  priorityAsc, // 优先级：低 → 高
}

/// 排序方式扩展：下拉菜单显示名与存储 key
extension MemoSortModeExt on MemoSortMode {
  String get label {
    switch (this) {
      case MemoSortMode.createDesc:
        return '创建时间（新→旧）';
      case MemoSortMode.createAsc:
        return '创建时间（旧→新）';
      case MemoSortMode.priorityDesc:
        return '优先级（高→低）';
      case MemoSortMode.priorityAsc:
        return '优先级（低→高）';
    }
  }

  static MemoSortMode fromKey(String? key) {
    return MemoSortMode.values.firstWhere(
      (MemoSortMode m) => m.name == key,
      orElse: () => MemoSortMode.createDesc,
    );
  }
}

/// 备忘录实体（可变对象，编辑页面直接改字段后调用 Provider 保存）
class Memo {
  Memo({
    required this.id,
    required this.title,
    required this.content,
    this.priority = MemoPriority.medium,
    this.done = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.alarmId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 唯一 ID（使用 时间戳+随机 保证不重复）
  final String id;

  /// 标题
  String title;

  /// 正文
  String content;

  /// 优先级
  MemoPriority priority;

  /// 是否已完成（待办勾选）
  bool done;

  /// 创建时间（排序用）
  final DateTime createdAt;

  /// 最后修改时间
  DateTime updatedAt;

  /// 绑定的闹钟 ID；为空表示未设置提醒
  String? alarmId;

  /// 是否已绑定提醒
  bool get hasReminder => alarmId != null && alarmId!.isNotEmpty;

  /// 把对象转成 Map，便于 JSON 序列化后存到 SharedPreferences
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'content': content,
        'priority': priority.key,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'alarmId': alarmId,
      };

  /// 从 Map 还原对象（字段缺失时给安全默认值，保证老版本数据可读）
  factory Memo.fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now();
    return Memo(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      priority: MemoPriorityExt.fromKey(json['priority'] as String?),
      done: json['done'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      alarmId: json['alarmId'] as String?,
    );
  }

  /// 复制一份并覆盖指定字段（Provider 中更新数据时使用）
  Memo copyWith({
    String? title,
    String? content,
    MemoPriority? priority,
    bool? done,
    String? alarmId,
  }) {
    return Memo(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      done: done ?? this.done,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      alarmId: alarmId ?? this.alarmId,
    );
  }
}
