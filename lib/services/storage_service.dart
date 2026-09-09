import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/alarm.dart';
import '../models/memo.dart';

/// =============================================================
/// 本地存储服务
/// -------------------------------------------------------------
/// 使用 SharedPreferences 以 JSON 字符串保存数据。为什么不用数据库？
/// 备忘录 + 闹钟的数据量很小（几百条以内），SharedPreferences 读写简单、
/// 双端零配置、重启后数据不丢失，完全可以满足需求。
/// 如果以后数据量变大（上万条 + 复杂查询），再迁移到 sqflite 即可。
/// =============================================================
class StorageService {
  SharedPreferences? _prefs;

  /// 必须在 runApp 之前调用（main 方法中 await）
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService 未初始化，请先调用 init()');
    return _prefs!;
  }

  // ==================== 备忘录 ====================

  /// 读取全部备忘录
  List<Memo> loadMemos() {
    final String raw = _p.getString(StorageKeys.memos) ?? '';
    if (raw.isEmpty) return <Memo>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) => Memo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 数据损坏时返回空列表，避免整个 APP 崩溃
      return <Memo>[];
    }
  }

  /// 保存全部备忘录
  Future<void> saveMemos(List<Memo> memos) async {
    final String raw = jsonEncode(memos.map((Memo m) => m.toJson()).toList());
    await _p.setString(StorageKeys.memos, raw);
  }

  /// 读取排序方式
  MemoSortMode loadSortMode() {
    return MemoSortModeExt.fromKey(_p.getString(StorageKeys.memoSort));
  }

  /// 保存排序方式
  Future<void> saveSortMode(MemoSortMode mode) async {
    await _p.setString(StorageKeys.memoSort, mode.name);
  }

  // ==================== 闹钟 ====================

  /// 读取全部闹钟
  List<Alarm> loadAlarms() {
    final String raw = _p.getString(StorageKeys.alarms) ?? '';
    if (raw.isEmpty) return <Alarm>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) => Alarm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return <Alarm>[];
    }
  }

  /// 保存全部闹钟
  Future<void> saveAlarms(List<Alarm> alarms) async {
    final String raw = jsonEncode(alarms.map((Alarm a) => a.toJson()).toList());
    await _p.setString(StorageKeys.alarms, raw);
  }

  /// 分配通知 ID 基址
  /// 通知 ID 必须是 int，且每条闹钟要占用 10 个（0 一次性 / 1~7 重复 / 8 贪睡）。
  /// 这里用自增计数器保证不同闹钟之间不会互相覆盖。
  int nextNotifBase() {
    final int current = _p.getInt(StorageKeys.notifIdSeed) ?? 0;
    final int next = current + 1;
    _p.setInt(StorageKeys.notifIdSeed, next);
    return next * NotificationConfig.idSpanPerAlarm;
  }

  // ==================== 其他 ====================

  /// 是否已完成首次权限引导（避免每次启动都弹窗打扰用户）
  bool isPermissionGuided() {
    return _p.getBool(StorageKeys.permissionGuided) ?? false;
  }

  Future<void> setPermissionGuided() async {
    await _p.setBool(StorageKeys.permissionGuided, true);
  }

  /// 后台通知响应暂存：
  /// 当 APP 处于后台/未启动时点击通知按钮，系统会在后台 isolate 回调，
  /// 那个 isolate 里拿不到 UI，所以先把动作写到这里，等 APP 回到前台再处理。
  Future<void> savePendingAction(Map<String, dynamic> action) async {
    await _p.setString('pending_notification_action', jsonEncode(action));
  }

  Map<String, dynamic>? takePendingAction() {
    final String raw = _p.getString('pending_notification_action') ?? '';
    if (raw.isEmpty) return null;
    _p.remove('pending_notification_action');
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
