/// =============================================================
/// 闹钟 / 提醒数据模型
/// -------------------------------------------------------------
/// 两种来源统一用一个模型：
///   1. 用户在闹钟页单独新建的闹钟（memoId = null）
///   2. 用户在备忘录里绑定的提醒（memoId = 对应备忘录 id）
/// 这样列表、响铃、贪睡逻辑只有一套，维护成本低。
/// =============================================================

/// 闹钟来源
enum AlarmSource {
  manual, // 单独新建
  memo, // 由备忘录绑定
}

class Alarm {
  Alarm({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.note,
    List<int>? repeatDays,
    this.enabled = true,
    this.ringtoneId = 'classic',
    this.vibrate = true,
    this.source = AlarmSource.manual,
    this.memoId,
    this.oneShotDate,
    DateTime? snoozedUntil,
    DateTime? createdAt,
    required this.notifBase,
  })  : repeatDays = repeatDays ?? <int>[],
        snoozedUntil = snoozedUntil,
        createdAt = createdAt ?? DateTime.now();

  /// 唯一 ID
  final String id;

  /// 闹钟标题（通知上显示）
  String title;

  /// 补充说明（通知副标题）
  String? note;

  /// 小时 0~23（24 小时制）
  int hour;

  /// 分钟 0~59
  int minute;

  /// 重复周期：1=周一 ... 7=周日（遵循 DateTime.weekday 规则）；空数组=一次性
  List<int> repeatDays;

  /// 开关：关闭后取消系统通知，但保留数据
  bool enabled;

  /// 铃声 id（对应 kRingtones 中的 id）
  String ringtoneId;

  /// 是否震动
  bool vibrate;

  /// 来源
  AlarmSource source;

  /// 关联的备忘录 id（手动新建的闹钟为 null）
  String? memoId;

  /// 一次性闹钟的日期（只取年月日，时分用 hour/minute）；重复闹钟时为 null
  DateTime? oneShotDate;

  /// 贪睡到什么时间（仅用于 UI 提示，为空表示没有正在贪睡）
  DateTime? snoozedUntil;

  /// 创建时间
  DateTime createdAt;

  /// 通知 ID 基址：
  /// base+0 一次性，base+1~7 周一~周日重复，base+8 贪睡
  /// 该值在闹钟创建时由 StorageService 分配并持久化，保证重启后 ID 稳定、可精确取消。
  final int notifBase;

  /// 是否重复闹钟
  bool get isRepeat => repeatDays.isNotEmpty;

  /// 是否由备忘录绑定而来
  bool get fromMemo => source == AlarmSource.memo && memoId != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'note': note,
        'hour': hour,
        'minute': minute,
        'repeatDays': repeatDays,
        'enabled': enabled,
        'ringtoneId': ringtoneId,
        'vibrate': vibrate,
        'source': source.name,
        'memoId': memoId,
        'oneShotDate': oneShotDate?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'notifBase': notifBase,
      };

  factory Alarm.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDays = json['repeatDays'] as List<dynamic>? ?? <dynamic>[];
    return Alarm(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '工作提醒',
      note: json['note'] as String?,
      hour: (json['hour'] as num?)?.toInt() ?? 9,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      repeatDays: rawDays.map((dynamic e) => (e as num).toInt()).toList(),
      enabled: json['enabled'] as bool? ?? true,
      ringtoneId: json['ringtoneId'] as String? ?? 'classic',
      vibrate: json['vibrate'] as bool? ?? true,
      source: AlarmSource.values.firstWhere(
        (AlarmSource s) => s.name == json['source'],
        orElse: () => AlarmSource.manual,
      ),
      memoId: json['memoId'] as String?,
      oneShotDate: json['oneShotDate'] == null
          ? null
          : DateTime.tryParse(json['oneShotDate'] as String),
      snoozedUntil: json['snoozedUntil'] == null
          ? null
          : DateTime.tryParse(json['snoozedUntil'] as String),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      notifBase: (json['notifBase'] as num?)?.toInt() ?? 0,
    );
  }

  /// 复制并覆盖字段（编辑保存时使用）
  Alarm copyWith({
    String? title,
    String? note,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    bool? enabled,
    String? ringtoneId,
    bool? vibrate,
    String? memoId,
    DateTime? oneShotDate,
    DateTime? snoozedUntil,
  }) {
    return Alarm(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? List<int>.from(this.repeatDays),
      enabled: enabled ?? this.enabled,
      ringtoneId: ringtoneId ?? this.ringtoneId,
      vibrate: vibrate ?? this.vibrate,
      source: source,
      memoId: memoId ?? this.memoId,
      oneShotDate: oneShotDate ?? this.oneShotDate,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      createdAt: createdAt,
      notifBase: notifBase,
    );
  }
}
