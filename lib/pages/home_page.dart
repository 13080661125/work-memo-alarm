import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../providers/alarm_provider.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../utils/time_util.dart';
import '../widgets/platform_adaptive.dart';
import 'alarm_list_page.dart';
import 'alarm_ringing_page.dart';
import 'memo_list_page.dart';

/// =============================================================
/// 首页：底部两个标签页（备忘录 / 闹钟）
/// -------------------------------------------------------------
/// 除了页面切换，首页还承担三件"全局"的事：
///   1. 首次启动时引导用户开启必要权限
///   2. 接收通知点击/按钮事件（贪睡、关闭、进入响铃页）
///   3. 处理"点击通知冷启动 APP"和"后台回调产生的待办动作"
/// =============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  /// 通知事件订阅
  StreamSubscription<NotificationResponse>? _responseSub;

  /// 响铃页是否正在显示（避免重复弹出）
  bool _ringingPageOpen = false;

  final List<Widget> _pages = const <Widget>[
    MemoListPage(),
    AlarmListPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 监听 APP 前后台切换（后台回调的动作在回到前台时处理）
    WidgetsBinding.instance.addObserver(this);

    // 订阅通知响应（点击通知、点击通知按钮）
    _responseSub = NotificationService.instance.onResponse.listen(
      (NotificationResponse response) {
        _handleResponse(response);
      },
    );

    // 首帧渲染完成后再做弹窗等交互操作（此时 context 才可用）
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _responseSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回到前台：处理后台 isolate 暂存的动作
    if (state == AppLifecycleState.resumed) {
      _handlePendingAction();
    }
  }

  /// 启动引导：权限 → 冷启动通知 → 后台暂存动作
  Future<void> _bootstrap() async {
    if (!mounted) return;
    await _guidePermissions();
    if (!mounted) return;
    await _handleLaunchPayload();
    if (!mounted) return;
    await _handlePendingAction();
  }

  // ==================== 权限引导 ====================

  /// 根据平台引导开启必要权限
  Future<void> _guidePermissions() async {
    // ---------- iOS ----------
    if (Platform.isIOS) {
      final bool granted = await PermissionService.hasNotificationPermission();
      if (!granted && mounted) {
        final bool go = await showAdaptiveConfirmDialog(
              context: context,
              title: '开启通知权限',
              content: 'iPhone 的闹钟提醒依赖系统本地通知，请允许发送通知，否则提醒不会弹出。',
              confirmText: '允许',
            ) ??
            false;
        if (go) {
          await NotificationService.instance.requestIOSNotificationPermission();
        }
      }
      return;
    }

    // ---------- Android ----------
    // 1) 通知权限（Android 13+ 必须）
    final bool notifGranted =
        await PermissionService.hasNotificationPermission();
    if (!notifGranted && mounted) {
      final bool go = await showAdaptiveConfirmDialog(
            context: context,
            title: '开启通知权限',
            content: '闹钟提醒需要通过通知弹出，请允许本应用发送通知。',
            confirmText: '去开启',
          ) ??
          false;
      if (go) {
        await PermissionService.requestNotificationPermission();
      }
    }
    if (!mounted) return;

    // 2) 精确闹钟权限（Android 12+ 默认关闭，不开会被延迟几分钟）
    final bool exactGranted = await PermissionService.hasExactAlarmPermission();
    if (!exactGranted && mounted) {
      final bool go = await showAdaptiveConfirmDialog(
            context: context,
            title: '开启精确闹钟权限',
            content: 'Android 12 起，系统默认只允许"不精确"的闹钟，可能延迟数分钟。\n'
                '点击"去开启"会跳转到系统「闹钟和提醒」页面，请打开本应用的开关。',
            confirmText: '去开启',
          ) ??
          false;
      if (go) {
        await PermissionService.requestExactAlarmPermission();
      }
    }
    if (!mounted) return;

    // 3) 电池优化白名单（不加入会在息屏后被系统限制）
    final bool batteryOk =
        await PermissionService.isBatteryOptimizationDisabled();
    if (!batteryOk && mounted) {
      final bool go = await showAdaptiveConfirmDialog(
            context: context,
            title: '加入电池优化白名单',
            content: '若不加入白名单，息屏一段时间后系统可能延迟甚至拦截闹钟。\n'
                '点击"去开启"后请在弹窗中选择「允许」。',
            confirmText: '去开启',
          ) ??
          false;
      if (go) {
        await PermissionService.requestIgnoreBatteryOptimizations();
      }
    }
  }

  // ==================== 通知事件处理 ====================

  /// 处理通知点击 / 通知按钮
  Future<void> _handleResponse(NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload == null) return;
    await _handlePayload(payload, response.actionId);
  }

  /// 冷启动：用户是点击通知进入 APP 的
  Future<void> _handleLaunchPayload() async {
    final String? payload = NotificationService.instance.launchPayload;
    if (payload == null) return;
    // 取完即清空，避免下次启动重复处理
    NotificationService.instance.launchPayload = null;
    await _handlePayload(payload, null);
  }

  /// 处理后台 isolate 暂存的动作（用户点击了通知按钮但 APP 当时没启动）
  Future<void> _handlePendingAction() async {
    final Map<String, dynamic>? action =
        context.read<StorageService>().takePendingAction();
    if (action == null) return;
    final String? payload = action['payload'] as String?;
    final String? actionId = action['actionId'] as String?;
    if (payload == null) return;
    await _handlePayload(payload, actionId);
  }

  /// 统一的 payload 分发
  Future<void> _handlePayload(String payload, String? actionId) async {
    try {
      final Map<String, dynamic> data =
          jsonDecode(payload) as Map<String, dynamic>;
      final String? alarmId = data['id'] as String?;
      if (alarmId == null) return;

      final AlarmProvider provider = context.read<AlarmProvider>();

      // 通知上的"关闭"按钮
      if (actionId == NotificationConfig.actionStop) {
        await provider.stopRinging(alarmId);
        if (mounted) showAdaptiveToast(context, '已关闭提醒');
        return;
      }

      // 通知上的"贪睡"按钮
      if (actionId == NotificationConfig.actionSnooze) {
        final DateTime? when = await provider.snooze(alarmId);
        if (mounted) {
          showAdaptiveToast(
            context,
            when == null
                ? '贪睡失败，请检查权限'
                : '已贪睡至 ${TimeUtil.hhmm(when)}',
          );
        }
        return;
      }

      // 点击通知主体 → 打开全屏响铃页
      await _openRingingPage(alarmId);
    } catch (e) {
      debugPrint('处理通知数据失败: $e');
    }
  }

  /// 打开全屏响铃页
  Future<void> _openRingingPage(String alarmId) async {
    if (_ringingPageOpen) return;
    final AlarmProvider provider = context.read<AlarmProvider>();
    final alarm = provider.byId(alarmId);
    if (alarm == null) {
      debugPrint('未找到闹钟: $alarmId（可能已被删除）');
      return;
    }

    // 如果是贪睡闹钟响了，清掉贪睡标记
    if (alarm.snoozedUntil != null) {
      await provider.clearSnooze(alarmId);
    }

    if (!mounted) return;
    _ringingPageOpen = true;
    final String? result = await Navigator.of(context).push<String>(
          MaterialPageRoute<String>(
            builder: (_) => AlarmRingingPage(alarm: alarm),
          ),
        );
    _ringingPageOpen = false;

    if (!mounted || result == null) return;
    if (result == 'snooze') {
      showAdaptiveToast(context, '已贪睡 10 分钟');
    }
  }

  // ==================== 界面 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt_outlined),
            activeIcon: Icon(Icons.note_alt),
            label: '备忘录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm_outlined),
            activeIcon: Icon(Icons.alarm),
            label: '闹钟',
          ),
        ],
      ),
    );
  }
}
