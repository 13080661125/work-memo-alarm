import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../providers/alarm_provider.dart';
import '../services/permission_service.dart';
import '../services/ringing_service.dart';
import '../widgets/platform_adaptive.dart';

/// =============================================================
/// 设置页
/// -------------------------------------------------------------
/// 1. 权限自检（通知 / 精确闹钟 / 电池优化）——闹钟能否准时响，全靠这里
/// 2. 铃声试听
/// 3. 手动重新注册所有闹钟（排查"闹钟不响"问题时很有用）
/// =============================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PermissionReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 刷新权限状态
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final PermissionReport report = await PermissionService.checkAll();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PermissionReport? report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _sectionTitle('权限与后台（影响闹钟能否准时响）'),
          _card(
            child: _loading || report == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: <Widget>[
                      _permissionTile(
                        icon: Icons.notifications_active_outlined,
                        title: '通知权限',
                        subtitle: report.notification
                            ? '已开启，闹钟通知可以正常弹出'
                            : '未开启，闹钟将不会弹出通知',
                        ok: report.notification,
                        onTap: () async {
                          await PermissionService.requestNotificationPermission();
                          await _refresh();
                        },
                      ),
                      // 精确闹钟与电池优化仅 Android 需要处理
                      if (Platform.isAndroid) ...<Widget>[
                        const Divider(color: AppColors.divider),
                        _permissionTile(
                          icon: Icons.alarm,
                          title: '精确闹钟权限',
                          subtitle: report.exactAlarm
                              ? '已开启，可以精确到秒触发'
                              : '未开启，可能被系统延迟几分钟（Android 12+ 必开）',
                          ok: report.exactAlarm,
                          onTap: () async {
                            await PermissionService.requestExactAlarmPermission();
                            await _refresh();
                          },
                        ),
                        const Divider(color: AppColors.divider),
                        _permissionTile(
                          icon: Icons.battery_std_outlined,
                          title: '电池优化白名单',
                          subtitle: report.batteryOptimized
                              ? '未加入白名单，息屏后可能被系统限制'
                              : '已加入白名单，后台更稳定',
                          ok: !report.batteryOptimized,
                          onTap: () async {
                            await PermissionService
                                .requestIgnoreBatteryOptimizations();
                            await _refresh();
                          },
                        ),
                      ],
                      const Divider(color: AppColors.divider),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.settings_applications_outlined),
                        title: const Text('打开系统设置'),
                        subtitle: const Text(
                          '可手动开启自启动、后台运行、悬浮窗等（国产 ROM 需要）',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await PermissionService.openSystemSettings();
                        },
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 8),
          // 全部 OK 的提示
          if (report != null && report.allGranted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.priorityLow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.check_circle, size: 18, color: AppColors.priorityLow),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '权限配置完整，闹钟可以正常在后台触发',
                      style: TextStyle(fontSize: 13, color: AppColors.priorityLow),
                    ),
                  ),
                ],
              ),
            ),

          // ---------- 铃声试听 ----------
          _sectionTitle('铃声试听'),
          _card(
            child: Column(
              children: kRingtones.map((RingtoneItem item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(item.name),
                  trailing: TextButton(
                    onPressed: () => RingingService.instance.preview(item.id),
                    child: const Text('试听'),
                  ),
                );
              }).toList(),
            ),
          ),

          // ---------- 维护操作 ----------
          _sectionTitle('维护'),
          _card(
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh),
                  title: const Text('重新注册全部闹钟'),
                  subtitle: const Text(
                    '换手机、清缓存或闹钟不响时点一下，会按当前数据重新向系统注册',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () async {
                    await context.read<AlarmProvider>().rescheduleAll();
                    if (!mounted) return;
                    showAdaptiveToast(context, '已重新注册全部闹钟');
                  },
                ),
                const Divider(color: AppColors.divider),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  subtitle: const Text('工作备忘录 + 闹钟提醒 v1.0.0（Flutter 跨平台）'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 权限条目
  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool ok,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: ok ? AppColors.priorityLow : Colors.red),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: ok
          ? const Icon(Icons.check_circle, color: AppColors.priorityLow)
          : TextButton(onPressed: onTap, child: const Text('去开启')),
      onTap: ok ? null : onTap,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
