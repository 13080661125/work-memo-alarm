import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'providers/alarm_provider.dart';
import 'providers/memo_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

/// =============================================================
/// 程序入口
/// -------------------------------------------------------------
/// 启动顺序（顺序很重要，不能颠倒）：
///   1. 绑定 Flutter 引擎
///   2. 初始化本地存储（SharedPreferences 是异步的，必须 await）
///   3. 初始化通知服务（时区 + 通知渠道 + 冷启动参数）
///   4. 读取本地数据到内存
///   5. 启动界面
/// =============================================================
Future<void> main() async {
  // 必须第一行：保证可以调用原生能力
  WidgetsFlutterBinding.ensureInitialized();

  // 限制竖屏（备忘录类应用竖屏体验更好）
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 1) 本地存储
  final StorageService storage = StorageService();
  await storage.init();

  // 2) 通知 / 闹钟服务
  await NotificationService.instance.init();

  // 3) 状态管理：从本地恢复数据
  final MemoProvider memoProvider = MemoProvider(storage)..load();
  final AlarmProvider alarmProvider = AlarmProvider(storage)..load();

  // 4) 建立关联：删除备忘录时，自动删除它绑定的闹钟
  memoProvider.deleteLinkedAlarm = (String memoId) async {
    await alarmProvider.removeByMemoId(memoId);
  };

  runApp(
    App(
      storage: storage,
      memoProvider: memoProvider,
      alarmProvider: alarmProvider,
    ),
  );
}
