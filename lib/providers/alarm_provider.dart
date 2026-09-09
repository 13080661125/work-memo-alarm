import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// =============================================================
/// 闹钟状态管理
/// -------------------------------------------------------------
/// 职责：维护闹钟列表 + 把数据变化同步给系统通知调度器。
/// 关键：任何一次增删改，都要重新注册系统通知，否则改了时间不生效。
/// =============================================================
class AlarmProvider extends ChangeNotifier {
  AlarmProvider(this._storage);

  final StorageService _storage;

  List<Alarm> _alarms = <Alarm>[];

  /// 从本地读取数据，并重新向系统注册所有通知
  /// （APP 每次启动都调用，可防止重启手机后闹钟失效）
  void load() {
    _alarms = _storage.loadAlarms();
    notifyListeners();
    rescheduleAll();
  }

  List<Alarm> get alarms => List<Alarm>.unmodifiable(_alarms);

  /// 已开启的闹钟数量
  int get enabledCount => _alarms.where((Alarm a) => a.enabled).length;

  /// 根据 id 查找
  Alarm? byId(String id) {
    for (final Alarm a in _alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 根据备忘录 id 查找其绑定的闹钟
  Alarm? byMemoId(String memoId) {
    for (final Alarm a in _alarms) {
      if (a.memoId == memoId) return a;
    }
    return null;
  }

  /// 重新注册所有闹钟（启动时自动调用一次；设置页也可手动触发）
  Future<void> rescheduleAll() async {
    for (final Alarm alarm in _alarms) {
      if (alarm.enabled) {
        await NotificationService.instance.scheduleAlarm(alarm);
      } else {
        await NotificationService.instance.cancelAlarm(alarm);
      }
    }
  }

  /// 新增闹钟
  Future<void> add(Alarm alarm) async {
    _alarms.add(alarm);
    await _persist();
    if (alarm.enabled) {
      await NotificationService.instance.scheduleAlarm(alarm);
    }
  }

  /// 更新闹钟
  Future<void> update(Alarm alarm) async {
    final int index = _alarms.indexWhere((Alarm a) => a.id == alarm.id);
    if (index >= 0) {
      _alarms[index] = alarm;
    } else {
      _alarms.add(alarm);
    }
    await _persist();
    if (alarm.enabled) {
      await NotificationService.instance.scheduleAlarm(alarm);
    } else {
      await NotificationService.instance.cancelAlarm(alarm);
    }
  }

  /// 删除闹钟
  Future<void> remove(String id) async {
    final Alarm? alarm = byId(id);
    _alarms.removeWhere((Alarm a) => a.id == id);
    await _persist();
    if (alarm != null) {
      await NotificationService.instance.cancelAlarm(alarm);
    }
  }

  /// 删除某条备忘录绑定的闹钟
  Future<void> removeByMemoId(String memoId) async {
    final Alarm? alarm = byMemoId(memoId);
    if (alarm == null) return;
    await remove(alarm.id);
  }

  /// 开启 / 关闭闹钟
  Future<void> setEnabled(String id, bool enabled) async {
    final Alarm? alarm = byId(id);
    if (alarm == null) return;
    alarm.enabled = enabled;
    if (!enabled) {
      // 关闭时清掉贪睡状态
      alarm.snoozedUntil = null;
      await NotificationService.instance.cancelAlarm(alarm);
    }
    await _persist();
    if (enabled) {
      await NotificationService.instance.scheduleAlarm(alarm);
    }
  }

  /// 贪睡 10 分钟
  /// 返回下次响铃时间；若闹钟不存在则返回 null
  Future<DateTime?> snooze(String id) async {
    final Alarm? alarm = byId(id);
    if (alarm == null) return null;
    final DateTime when = await NotificationService.instance.scheduleSnooze(alarm);
    alarm.snoozedUntil = when;
    await _persist();
    return when;
  }

  /// 停止响铃 / 取消贪睡
  Future<void> stopRinging(String id) async {
    final Alarm? alarm = byId(id);
    if (alarm == null) return;
    alarm.snoozedUntil = null;
    await NotificationService.instance.cancelSnooze(alarm);
    // 一次性闹钟响完后自动关闭，避免第二天又响
    if (!alarm.isRepeat) {
      alarm.enabled = false;
      await NotificationService.instance.cancelAlarm(alarm);
    }
    await _persist();
  }

  /// 清空贪睡标记（贪睡闹钟响过之后调用）
  Future<void> clearSnooze(String id) async {
    final Alarm? alarm = byId(id);
    if (alarm == null) return;
    alarm.snoozedUntil = null;
    await _persist();
  }

  /// 生成一个新的通知 ID 基址
  int nextNotifBase() => _storage.nextNotifBase();

  /// 写入本地存储并刷新界面
  Future<void> _persist() async {
    await _storage.saveAlarms(_alarms);
    notifyListeners();
  }

  /// 调试用：当前系统里已排队通知的条数
  Future<int> pendingNotificationCount() =>
      NotificationService.instance.pendingCount();

  /// 常量引用（UI 里展示贪睡时长用）
  static int get snoozeMinutes => NotificationConfig.snoozeMinutes;
}
