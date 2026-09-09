import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../services/ringing_service.dart';
import '../utils/time_util.dart';

/// =============================================================
/// 全屏响铃页
/// -------------------------------------------------------------
/// 触发链路：
///   系统定时通知到达
///     → Android：fullScreenIntent 直接把 APP 拉到前台（锁屏也能显示）
///     → iOS：用户点击通知/通知上的按钮后进入 APP
///   然后由首页把用户引导到本页面，开始持续响铃 + 震动。
///
/// 用户操作：
///   关闭 → 停止响铃；一次性闹钟自动关闭
///   贪睡 → 10 分钟后重新响
/// =============================================================
class AlarmRingingPage extends StatefulWidget {
  const AlarmRingingPage({super.key, required this.alarm});

  final Alarm alarm;

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage> {
  /// 自动停止响铃的兜底定时器（防止无人处理时一直响）
  Timer? _autoStopTimer;

  /// 当前时间，用于页面上的时钟显示
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    // 开始响铃 + 震动
    RingingService.instance.start(
      ringtoneId: widget.alarm.ringtoneId,
      vibrate: widget.alarm.vibrate,
    );

    // 每秒刷新页面上的时间
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // 2 分钟后自动停止声音（页面仍停留，避免吵到他人）
    _autoStopTimer = Timer(const Duration(minutes: 2), () {
      RingingService.instance.stop();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // 无论通过什么方式离开页面，都要停止响铃
    _clockTimer?.cancel();
    _autoStopTimer?.cancel();
    RingingService.instance.stop();
    super.dispose();
  }

  /// 关闭提醒
  Future<void> _stop() async {
    await RingingService.instance.stop();
    await context.read<AlarmProvider>().stopRinging(widget.alarm.id);
    if (!mounted) return;
    Navigator.of(context).pop('stop');
  }

  /// 贪睡 10 分钟
  Future<void> _snooze() async {
    await RingingService.instance.stop();
    final DateTime? when =
        await context.read<AlarmProvider>().snooze(widget.alarm.id);
    if (!mounted) return;
    if (when == null) {
      Navigator.of(context).pop('stop');
      return;
    }
    Navigator.of(context).pop('snooze');
  }

  @override
  Widget build(BuildContext context) {
    final Alarm alarm = widget.alarm;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // 深蓝渐变背景：锁屏亮起时更醒目
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2C5F8D), Color(0xFF1B3B57)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.alarm, size: 64, color: Colors.white70),
                const SizedBox(height: 20),
                // 当前时间
                Text(
                  TimeUtil.hhmm(_now),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                // 闹钟标题
                Text(
                  alarm.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (alarm.note != null && alarm.note!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    alarm.note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${TimeUtil.alarmTime(alarm)} · ${TimeUtil.repeatText(alarm.repeatDays)}',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),

                const SizedBox(height: 70),

                // 贪睡按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _snooze,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      '贪睡 10 分钟',
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 关闭按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _stop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      '关闭提醒',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '响铃将在 2 分钟后自动停止',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
