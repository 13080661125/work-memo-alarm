import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// =============================================================
/// 权限服务（双端差异集中在这里处理）
/// -------------------------------------------------------------
/// Android 需要：
///   1. 通知权限（Android 13 / API 33 起运行时申请）
///   2. 精确闹钟权限（Android 12 / API 31 起默认关闭，需用户手动授权）
///   3. 电池优化白名单（不申请的话，Doze 模式与国产 ROM 会杀掉后台，闹钟延迟）
/// iOS 需要：
///   1. 通知权限（首次弹系统弹窗，一旦拒绝只能去系统设置里改）
/// =============================================================
class PermissionService {
  /// 当前通知权限是否已授予（Android 13+ / iOS 通用）
  static Future<bool> hasNotificationPermission() async {
    final PermissionStatus status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 申请通知权限，返回是否授予成功
  static Future<bool> requestNotificationPermission() async {
    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 是否已获得"精确闹钟"权限（仅 Android；iOS 直接返回 true）
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final PermissionStatus status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// 申请精确闹钟权限。
  /// 注意：Android 12+ 这个权限不能像普通权限那样弹窗授予，
  /// 系统会跳转到"闹钟和提醒"设置页，需要用户手动打开开关。
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final PermissionStatus status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// 是否已在电池优化白名单（仅 Android；iOS 返回 true）
  /// 不在白名单时，系统可能在息屏后延迟甚至拦截闹钟。
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    final PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// 申请加入电池优化白名单（系统弹窗，用户确认即可）
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    final PermissionStatus status =
        await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// 打开系统设置页（用户在里面手动开启通知/自启动/后台运行）
  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// 一次性检查所有关键权限，返回诊断结果（设置页里展示用）
  static Future<PermissionReport> checkAll() async {
    return PermissionReport(
      notification: await hasNotificationPermission(),
      exactAlarm: await hasExactAlarmPermission(),
      batteryOptimized: !(await isBatteryOptimizationDisabled()),
    );
  }
}

/// 权限诊断结果
class PermissionReport {
  const PermissionReport({
    required this.notification,
    required this.exactAlarm,
    required this.batteryOptimized,
  });

  /// 通知权限是否已授予
  final bool notification;

  /// 精确闹钟权限是否已授予
  final bool exactAlarm;

  /// true 表示仍被电池优化限制（即未加入白名单）
  final bool batteryOptimized;

  /// 是否全部 OK
  bool get allGranted => notification && exactAlarm && !batteryOptimized;
}
