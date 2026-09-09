import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import 'storage_service.dart';

/// =============================================================
/// 通知 / 闹钟调度服务（整个 APP 的核心）
/// -------------------------------------------------------------
/// 设计要点：
/// 1. **不用前台服务保活**：Android 上持续跑前台服务既耗电又容易被国产 ROM 杀掉。
///    本项目全部依赖系统的 AlarmManager 定时通知（flutter_local_notifications 内部实现），
///    即使 APP 进程被杀、手机重启，只要权限到位，系统依然会按时弹出通知。
/// 2. **精确闹钟**：使用 AndroidScheduleMode.exactAllowWhileIdle，允许在 Doze 低电耗模式下
///    依然精确触发（这是"后台也能响"的关键）。
/// 3. **全屏意图**：Android 通知设置 fullScreenIntent=true，锁屏时也能直接弹出 APP 的响铃页。
/// 4. **重复闹钟**：对每一个选中的星期各注册一条通知，使用 dayOfWeekAndTime 匹配，
///    这样每周固定时间都会触发，且不用我们自己算下次时间。
/// =============================================================

/// 后台 isolate 的回调入口（必须是顶层函数 + @pragma 注解，否则 release 包会被摇树优化掉）
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(
    NotificationResponse response) async {
  // 注意：这里运行在独立的后台 isolate，拿不到 UI，也拿不到主 isolate 的 Provider。
  // 因此只做一件事：把"用户点了什么"写进本地存储，等 APP 回到前台后再处理。
  try {
    final StorageService storage = StorageService();
    await storage.init();
    await storage.savePendingAction(<String, dynamic>{
      'actionId': response.actionId,
      'payload': response.payload,
      'time': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    debugPrint('后台通知回调处理失败: $e');
  }
}

class NotificationService {
  NotificationService._();

  /// 单例
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 通知点击/按钮事件广播流，UI 层订阅后做跳转或贪睡处理
  final StreamController<NotificationResponse> _responseController =
      StreamController<NotificationResponse>.broadcast();

  Stream<NotificationResponse> get onResponse => _responseController.stream;

  bool _initialized = false;

  /// 冷启动时"用户点击通知进入 APP"所携带的 payload（在 main 中读取后交给首页处理）
  String? launchPayload;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// ---------------------------------------------------------------
  /// 初始化：时区 → 插件 → 通知渠道
  /// ---------------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    // 1) 初始化时区数据库（定时通知必须使用带时区的绝对时间）
    tz_data.initializeTimeZones();
    try {
      final String zoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (e) {
      // 兜底：某些设备返回的时区名不在数据库里，退化为东八区，保证功能可用
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }

    // 2) 初始化插件
    //    注意：这里不自动申请 iOS 权限（requestAlertPermission: false），
    //    权限统一在首页引导流程里申请，方便我们自定义说明文案。
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        // 注册通知分类后，iOS 锁屏/横幅通知才会显示"关闭 / 贪睡"两个按钮
        DarwinNotificationCategory(
          NotificationConfig.darwinCategory,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              NotificationConfig.actionSnooze,
              '贪睡10分钟',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationConfig.actionStop,
              '关闭',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );

    // 3) 为每种铃声创建独立的通知渠道（Android 8+ 铃声绑定在渠道上，必须提前创建）
    await _createAndroidChannels();

    // 4) 读取"点击通知启动 APP"的信息，交由首页在首帧后处理
    final NotificationAppLaunchDetails? launchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      launchPayload = launchDetails.notificationResponse?.payload;
    }

    _initialized = true;
  }

  /// 前台/已启动状态下收到通知响应
  void _onForegroundResponse(NotificationResponse response) {
    if (!_responseController.isClosed) {
      _responseController.add(response);
    }
  }

  /// 为每种铃声创建通知渠道
  Future<void> _createAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    for (final RingtoneItem ring in kRingtones) {
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        NotificationConfig.channelIdFor(ring.id),
        '${NotificationConfig.channelName}·${ring.name}',
        description: NotificationConfig.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(ring.nativeName),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 800, 400, 800, 400, 800]),
        enableLights: true,
        showBadge: true,
      );
      await androidImpl.createNotificationChannel(channel);
    }
  }

  /// ---------------------------------------------------------------
  /// 权限申请
  /// ---------------------------------------------------------------

  /// Android 13+ 申请通知权限（走插件的原生实现）
  Future<bool> requestAndroidNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// iOS 申请通知权限（弹窗只允许弹一次，拒绝后只能引导去系统设置）
  Future<bool> requestIOSNotificationPermission() async {
    if (!Platform.isIOS) return true;
    final IOSFlutterLocalNotificationsPlugin? iosImpl =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final bool? granted = await iosImpl?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
      // critical: true 需要苹果特别审核权限，闹钟类 APP 一般不用申请
    );
    return granted ?? false;
  }

  /// ---------------------------------------------------------------
  /// 调度：注册 / 取消 / 贪睡
  /// ---------------------------------------------------------------

  /// 注册一条闹钟的所有通知（重复闹钟会注册多条）
  Future<void> scheduleAlarm(Alarm alarm) async {
    // 先取消旧的，避免改时间后旧通知还在
    await cancelAlarm(alarm, keepSnoozed: true);
    if (!alarm.enabled) return;

    final RingtoneItem ring = ringtoneById(alarm.ringtoneId);
    final NotificationDetails details = _buildDetails(alarm, ring);
    final String payload = _buildPayload(alarm);
    final String body = _buildBody(alarm);

    if (alarm.isRepeat) {
      // 每个选中的星期注册一条通知，系统自动按"星期+时间"重复
      for (final int day in alarm.repeatDays) {
        final tz.TZDateTime when =
            _nextInstanceOfTime(alarm.hour, alarm.minute, weekday: day);
        await _plugin.zonedSchedule(
          alarm.notifBase + day, // 通知 ID：基址 + 星期
          alarm.title,
          body,
          when,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } else {
      // 一次性闹钟
      final tz.TZDateTime when = _nextInstanceOfTime(
        alarm.hour,
        alarm.minute,
        oneShotDate: alarm.oneShotDate,
      );
      await _plugin.zonedSchedule(
        alarm.notifBase,
        alarm.title,
        body,
        when,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// 取消一条闹钟的所有通知
  /// [keepSnoozed] 为 true 时保留"贪睡"那条（用于编辑闹钟但正在贪睡的场景）
  Future<void> cancelAlarm(Alarm alarm, {bool keepSnoozed = false}) async {
    for (int i = 0; i < NotificationConfig.idSpanPerAlarm; i++) {
      if (keepSnoozed && i == NotificationConfig.snoozeIdOffset) continue;
      await _plugin.cancel(alarm.notifBase + i);
    }
  }

  /// 贪睡：在 N 分钟后重新响一次
  /// 返回下次响铃的时间点，由上层写入数据并保存到本地
  Future<DateTime> scheduleSnooze(Alarm alarm) async {
    final DateTime when = DateTime.now()
        .add(const Duration(minutes: NotificationConfig.snoozeMinutes));
    final tz.TZDateTime tzWhen = tz.TZDateTime.from(
      when,
      tz.local,
    );
    final RingtoneItem ring = ringtoneById(alarm.ringtoneId);
    await _plugin.cancel(alarm.notifBase + NotificationConfig.snoozeIdOffset);
    await _plugin.zonedSchedule(
      alarm.notifBase + NotificationConfig.snoozeIdOffset,
      alarm.title,
      '贪睡提醒 · ${_buildBody(alarm)}',
      tzWhen,
      _buildDetails(alarm, ring),
      payload: _buildPayload(alarm, snooze: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return when;
  }

  /// 取消贪睡
  Future<void> cancelSnooze(Alarm alarm) async {
    await _plugin.cancel(alarm.notifBase + NotificationConfig.snoozeIdOffset);
  }

  /// 取消所有通知（设置页"清空全部提醒"用）
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 当前已注册的通知数量（调试用）
  Future<int> pendingCount() async {
    final List<PendingNotificationRequest> pending =
        await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// ---------------------------------------------------------------
  /// 内部工具方法
  /// ---------------------------------------------------------------

  /// 构造通知详情（Android + iOS）
  NotificationDetails _buildDetails(Alarm alarm, RingtoneItem ring) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        // 渠道 id 与铃声绑定，保证每条闹钟可以用不同铃声
        NotificationConfig.channelIdFor(ring.id),
        '${NotificationConfig.channelName}·${ring.name}',
        channelDescription: NotificationConfig.channelDescription,
        channelShowBadge: true,
        importance: Importance.max,
        priority: Priority.max,
        // 声明为"闹钟"类别，系统会给予更高的展示优先级
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(ring.nativeName),
        enableVibration: alarm.vibrate,
        vibrationPattern:
            Int64List.fromList(<int>[0, 800, 400, 800, 400, 800, 400, 800]),
        // 关键：全屏意图，锁屏状态下直接拉起 APP 的响铃页面
        fullScreenIntent: true,
        // 锁屏时显示完整内容
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ticker: alarm.title,
        // 通知上的操作按钮（安卓端）
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            NotificationConfig.actionSnooze,
            '贪睡10分钟',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationConfig.actionStop,
            '关闭',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // iOS 通知声音必须放在 App 主 bundle 根目录（详见部署文档）
        sound: '${ring.nativeName}.wav',
        // 时间敏感级别：可以穿透专注模式/静音，适合闹钟
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: NotificationConfig.darwinCategory,
      ),
    );
  }

  /// 通知正文：显示重复规则或备注
  String _buildBody(Alarm alarm) {
    if (alarm.note != null && alarm.note!.isNotEmpty) return alarm.note!;
    if (alarm.fromMemo) return '来自备忘录的提醒';
    return '工作提醒';
  }

  /// 通知携带的数据：点击后据此找到对应闹钟
  String _buildPayload(Alarm alarm, {bool snooze = false}) {
    return jsonEncode(<String, dynamic>{
      'type': 'alarm',
      'id': alarm.id,
      'snooze': snooze,
    });
  }

  /// 计算下一次触发的（带时区的）时间点
  tz.TZDateTime _nextInstanceOfTime(
    int hour,
    int minute, {
    int? weekday,
    DateTime? oneShotDate,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // 一次性闹钟：以指定日期为准，时间已过则顺延一天
    if (oneShotDate != null && weekday == null) {
      tz.TZDateTime target = tz.TZDateTime(
        tz.local,
        oneShotDate.year,
        oneShotDate.month,
        oneShotDate.day,
        hour,
        minute,
      );
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return target;
    }

    tz.TZDateTime target =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (weekday != null) {
      // 找到最近的匹配星期
      while (target.weekday != weekday) {
        target = target.add(const Duration(days: 1));
      }
      // 今天匹配但时间已过 → 顺延一周
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 7));
      }
      return target;
    }

    // 无重复、无指定日期：今天的时刻，过了就明天
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}
