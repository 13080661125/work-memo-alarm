import 'package:intl/intl.dart';

import '../models/alarm.dart';

/// =============================================================
/// 时间工具类
/// -------------------------------------------------------------
/// 全项目统一使用 24 小时制，避免上午/下午歧义。
/// =============================================================
class TimeUtil {
  /// 24 小时制时间：09:05
  static String hhmm(DateTime time) => DateFormat('HH:mm').format(time);

  /// 完整时间：2026-09-09 09:05
  static String full(DateTime time) => DateFormat('yyyy-MM-dd HH:mm').format(time);

  /// 月日：09-09
  static String mmdd(DateTime time) => DateFormat('MM-dd').format(time);

  /// 友好时间：今天 09:05 / 昨天 09:05 / 09-09 09:05
  static String friendly(DateTime time) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(time.year, time.month, time.day);
    if (target == today) return '今天 ${hhmm(time)}';
    if (target == today.subtract(const Duration(days: 1))) return '昨天 ${hhmm(time)}';
    if (target == today.add(const Duration(days: 1))) return '明天 ${hhmm(time)}';
    return full(time);
  }

  /// 闹钟时间字符串：09:05
  static String alarmTime(Alarm alarm) {
    final String h = alarm.hour.toString().padLeft(2, '0');
    final String m = alarm.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 星期的中文简称（索引 1~7 对应周一~周日，与 DateTime.weekday 一致）
  static const List<String> weekdayShort = <String>['', '一', '二', '三', '四', '五', '六', '日'];

  /// 把重复周期数组转成中文描述
  /// 例：[1,2,3,4,5] → 工作日；[6,7] → 周末；[] → 一次性；[1..7] → 每天
  static String repeatText(List<int> days) {
    if (days.isEmpty) return '一次性';
    final List<int> sorted = List<int>.from(days)..sort();
    const List<int> workdays = <int>[1, 2, 3, 4, 5];
    const List<int> weekend = <int>[6, 7];
    const List<int> everyday = <int>[1, 2, 3, 4, 5, 6, 7];

    bool sameList(List<int> a, List<int> b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    if (sameList(sorted, everyday)) return '每天';
    if (sameList(sorted, workdays)) return '工作日';
    if (sameList(sorted, weekend)) return '周末';
    return sorted.map((int d) => '周${weekdayShort[d]}').join(' ');
  }

  /// 计算下一次响铃时间（用于列表展示"还有多久响铃"）
  /// [hour] [minute] 闹钟时间
  /// [weekday] 指定星期（1~7）；为 null 表示一次性或只看今天的时刻
  /// [oneShotDate] 一次性闹钟的日期
  static DateTime nextOccurrence({
    required int hour,
    required int minute,
    int? weekday,
    DateTime? oneShotDate,
    DateTime? from,
  }) {
    final DateTime base = from ?? DateTime.now();

    // 一次性闹钟：以指定日期为准
    if (oneShotDate != null && weekday == null) {
      DateTime target = DateTime(oneShotDate.year, oneShotDate.month, oneShotDate.day, hour, minute);
      // 时间已过则顺延一天（避免创建过去时间的闹钟后永不触发）
      if (target.isBefore(base)) target = target.add(const Duration(days: 1));
      return target;
    }

    DateTime target = DateTime(base.year, base.month, base.day, hour, minute);
    if (weekday != null) {
      // 往后找到最近的匹配星期
      while (target.weekday != weekday) {
        target = target.add(const Duration(days: 1));
      }
      // 今天就是这个星期但时间已过 → 顺延一周
      if (target.isBefore(base)) {
        target = target.add(const Duration(days: 7));
      }
      return target;
    }

    // 无重复也未指定日期：今天的时刻，过了就明天
    if (target.isBefore(base)) target = target.add(const Duration(days: 1));
    return target;
  }

  /// 距离下一次响铃还有多久的中文描述
  static String countdownText(DateTime next) {
    final Duration diff = next.difference(DateTime.now());
    if (diff.isNegative) return '即将响铃';
    final int totalMinutes = diff.inMinutes;
    if (totalMinutes < 1) return '不到 1 分钟后';
    if (totalMinutes < 60) return '$totalMinutes 分钟后';
    final int hours = totalMinutes ~/ 60;
    if (hours < 24) return '$hours 小时后';
    return '${hours ~/ 24} 天后';
  }
}
