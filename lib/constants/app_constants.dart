import 'package:flutter/material.dart';

/// =============================================================
/// 全局常量集中管理
/// -------------------------------------------------------------
/// 包含：商务简约风格配色、内置铃声清单、本地存储键名、通知相关常量。
/// 集中放置的目的是：改主题色 / 加铃声 / 调贪睡时长时，只改这一个文件。
/// =============================================================

/// 商务清爽风格配色（浅色为主，卡片白色 + 浅灰蓝背景 + 深蓝主色）
class AppColors {
  /// 主色：沉稳商务蓝
  static const Color primary = Color(0xFF2C5F8D);

  /// 主色浅色变体（用于选中态背景）
  static const Color primaryLight = Color(0xFFE8F1F8);

  /// 强调色：用于主按钮、浮动按钮
  static const Color accent = Color(0xFF3D8BD4);

  /// 页面背景色
  static const Color background = Color(0xFFF4F6F9);

  /// 卡片背景色
  static const Color card = Color(0xFFFFFFFF);

  /// 主文本
  static const Color textPrimary = Color(0xFF22303F);

  /// 次要文本（时间、说明）
  static const Color textSecondary = Color(0xFF7A869A);

  /// 分隔线
  static const Color divider = Color(0xFFE6EAF0);

  /// 高优先级：红
  static const Color priorityHigh = Color(0xFFE5534B);

  /// 中优先级：橙
  static const Color priorityMedium = Color(0xFFF2A33C);

  /// 低优先级：绿
  static const Color priorityLow = Color(0xFF3BA776);

  /// 已完成文本灰
  static const Color doneGrey = Color(0xFFB4BCC8);
}

/// 内置铃声模型
/// [id] 唯一标识，保存在闹钟数据里
/// [name] 展示给用户的中文名
/// [assetPath] Flutter assets 路径，用于 App 内试听与响铃页循环播放
/// [nativeName] 原生资源名（不带扩展名）：
///   - Android 对应 android/app/src/main/res/raw/<nativeName>.wav
///   - iOS 对应 拷贝到 Runner 主 bundle 的 <nativeName>.wav
class RingtoneItem {
  const RingtoneItem({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.nativeName,
  });

  final String id;
  final String name;
  final String assetPath;
  final String nativeName;
}

/// 内置铃声清单（新增铃声时：① 生成 wav 放 assets/ringtones ② 拷贝到双端原生目录 ③ 此处加一行）
const List<RingtoneItem> kRingtones = <RingtoneItem>[
  RingtoneItem(
    id: 'classic',
    name: '经典闹铃',
    assetPath: 'ringtones/classic_alarm.wav',
    nativeName: 'alarm_classic',
  ),
  RingtoneItem(
    id: 'gentle',
    name: '柔和晨曦',
    assetPath: 'ringtones/gentle_morning.wav',
    nativeName: 'alarm_gentle_morning',
  ),
  RingtoneItem(
    id: 'digital',
    name: '电子滴答',
    assetPath: 'ringtones/digital_tick.wav',
    nativeName: 'alarm_digital_tick',
  ),
  RingtoneItem(
    id: 'bell',
    name: '商务钟声',
    assetPath: 'ringtones/business_bell.wav',
    nativeName: 'alarm_business_bell',
  ),
];

/// 根据 id 取铃声配置，取不到时回退到第一个（防止旧数据里存了已删除的铃声）
RingtoneItem ringtoneById(String id) {
  for (final RingtoneItem item in kRingtones) {
    if (item.id == id) return item;
  }
  return kRingtones.first;
}

/// 本地存储（SharedPreferences）键名
class StorageKeys {
  /// 备忘录列表（JSON 数组字符串）
  static const String memos = 'memo_list';

  /// 闹钟列表（JSON 数组字符串）
  static const String alarms = 'alarm_list';

  /// 通知自增 ID 计数器（保证每条闹钟的通知 ID 不冲突）
  static const String notifIdSeed = 'notif_id_seed';

  /// 备忘录排序方式（create_desc / create_asc / priority_desc / priority_asc）
  static const String memoSort = 'memo_sort_mode';

  /// 是否已完成首次权限引导
  static const String permissionGuided = 'permission_guided';
}

/// 通知 / 闹钟相关常量
class NotificationConfig {
  /// 通知渠道 ID 前缀。安卓 8.0+ 的声音与震动绑定在渠道上，
  /// 为了让"每条闹钟可以选不同铃声"，这里为每种铃声创建一个独立渠道。
  static String channelIdFor(String ringtoneId) => 'work_alarm_$ringtoneId';

  /// 通知渠道名称（系统设置里可见）
  static const String channelName = '工作提醒闹钟';

  /// 通知渠道描述
  static const String channelDescription = '备忘录与闹钟到点时的提醒通知';

  /// 通知按钮：贪睡
  static const String actionSnooze = 'snooze';

  /// 通知按钮：关闭
  static const String actionStop = 'stop';

  /// iOS 通知分类标识（需在初始化时注册，锁屏通知才会显示操作按钮）
  static const String darwinCategory = 'workAlarmCategory';

  /// 贪睡时长（分钟）
  static const int snoozeMinutes = 10;

  /// 每条闹钟占用 10 个通知 ID：
  /// base + 0   → 一次性闹钟
  /// base + 1~7 → 周一~周日各自的重复通知
  /// base + 8   → 贪睡通知
  static const int idSpanPerAlarm = 10;
  static const int snoozeIdOffset = 8;
}
