import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'pages/home_page.dart';
import 'providers/alarm_provider.dart';
import 'providers/memo_provider.dart';
import 'services/storage_service.dart';

/// =============================================================
/// APP 根组件
/// -------------------------------------------------------------
/// 负责：注入状态管理（Provider）、配置主题、挂载首页
/// =============================================================
class App extends StatelessWidget {
  const App({
    super.key,
    required this.storage,
    required this.memoProvider,
    required this.alarmProvider,
  });

  final StorageService storage;
  final MemoProvider memoProvider;
  final AlarmProvider alarmProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 存储服务（非监听型，供各处直接读取）
        Provider<StorageService>.value(value: storage),
        // 备忘录与闹钟状态
        ChangeNotifierProvider<MemoProvider>.value(value: memoProvider),
        ChangeNotifierProvider<AlarmProvider>.value(value: alarmProvider),
      ],
      child: MaterialApp(
        title: '工作备忘录 · 闹钟提醒',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomePage(),
      ),
    );
  }

  /// 商务简约主题（浅色为主，全局 24 小时制风格统一）
  ThemeData _buildTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      // AppBar：白底 + 深色文字，商务清爽
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      // 输入框
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.doneGrey, fontSize: 15),
        border: InputBorder.none,
      ),
      // 浮动按钮
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      // 分隔线
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      // 全局字体：中文用系统字体即可，避免引入大字体包
      fontFamily: null,
    );
  }
}
