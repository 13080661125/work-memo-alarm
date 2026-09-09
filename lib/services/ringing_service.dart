import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../constants/app_constants.dart';

/// =============================================================
/// 响铃服务：负责"持续播放铃声 + 持续震动"
/// -------------------------------------------------------------
/// 使用场景：
///   1. 闹钟触发后进入全屏响铃页 → start()，用户点"关闭/贪睡" → stop()
///   2. 设置页/编辑页试听铃声 → preview()
///
/// 说明：通知本身也会响一声系统铃声，这里的作用是"持续响"，
///      直到用户处理为止，避免响一声就停导致漏看。
/// =============================================================
class RingingService {
  RingingService._();

  static final RingingService instance = RingingService._();

  /// 持续响铃用的播放器
  final AudioPlayer _player = AudioPlayer();

  /// 试听用的播放器（与响铃播放器分开，互不干扰）
  final AudioPlayer _previewPlayer = AudioPlayer();

  /// 震动循环定时器
  Timer? _vibrateTimer;

  bool _ringing = false;

  bool get isRinging => _ringing;

  /// 开始响铃（循环播放 + 循环震动）
  Future<void> start({
    required String ringtoneId,
    bool vibrate = true,
  }) async {
    // 先停掉上一次，避免叠加
    await stop();
    _ringing = true;
    final RingtoneItem item = ringtoneById(ringtoneId);

    try {
      // respectSilence: false → iOS 上即使打开了静音键也会播放（闹钟必需）
      // stayAwake: true → Android 播放期间保持 CPU 唤醒
      await _player.setAudioContext(
        AudioContextConfig(
          respectSilence: false,
          duckAudio: false,
          stayAwake: true,
        ).build(),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource(item.assetPath));
    } catch (e) {
      debugPrint('铃声播放失败: $e');
    }

    if (vibrate) {
      await _startVibrateLoop();
    }
  }

  /// 循环震动
  /// 说明：不同平台对"震动 pattern 循环"的支持不一致，
  /// 这里用定时器反复触发单次震动，双端行为一致、可控。
  Future<void> _startVibrateLoop() async {
    try {
      final bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;
    } catch (e) {
      // 模拟器或部分设备可能不支持，忽略即可
      return;
    }

    _vibrateTimer?.cancel();
    // 周期：1.2 秒震动 + 0.6 秒停顿
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      Vibration.vibrate(duration: 1200, amplitude: 200);
    });
    // 立即震动一次，不用等第一个周期
    Vibration.vibrate(duration: 1200, amplitude: 200);
  }

  /// 停止响铃与震动
  Future<void> stop() async {
    _ringing = false;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('停止铃声失败: $e');
    }
    try {
      Vibration.cancel();
    } catch (_) {
      // iOS 不支持 cancel 时会抛错，忽略
    }
  }

  /// 试听铃声（播放一次，最多 5 秒）
  Future<void> preview(String ringtoneId) async {
    await _previewPlayer.stop();
    final RingtoneItem item = ringtoneById(ringtoneId);
    try {
      await _previewPlayer.setAudioContext(
        AudioContextConfig(respectSilence: false).build(),
      );
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.setVolume(1.0);
      await _previewPlayer.play(AssetSource(item.assetPath));
      // 最多试听 5 秒
      Future<void>.delayed(const Duration(seconds: 5), () async {
        await _previewPlayer.stop();
      });
    } catch (e) {
      debugPrint('试听失败: $e');
    }
  }

  /// 停止试听
  Future<void> stopPreview() async {
    await _previewPlayer.stop();
  }
}
