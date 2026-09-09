import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// =============================================================
/// 平台适配小工具
/// -------------------------------------------------------------
/// 目标：同一套业务代码，在 Android 上呈现 Material 风格交互，
///      在 iOS 上呈现 Cupertino 风格交互（时间滚轮、弹窗样式等）。
/// =============================================================

/// 是否 iOS 平台
bool get isIOS => !kIsWeb && Platform.isIOS;

/// 平台自适应的开关组件
Widget adaptiveSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
  Color? activeColor,
}) {
  if (isIOS) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: activeColor,
    );
  }
  return Switch(value: value, onChanged: onChanged);
}

/// 平台自适应的时间选择器（统一 24 小时制）
/// Android：Material 时间选择器；iOS：底部滚轮
Future<TimeOfDay?> showAdaptiveTimePicker(
  BuildContext context,
  TimeOfDay initial,
) async {
  if (isIOS) {
    TimeOfDay picked = initial;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: <Widget>[
              // 顶部确定栏
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  CupertinoButton(
                    child: const Text('完成'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true, // 需求：24 小时制
                  initialDateTime:
                      DateTime(2020, 1, 1, initial.hour, initial.minute),
                  onDateTimeChanged: (DateTime d) {
                    picked = TimeOfDay.fromDateTime(d);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    return picked;
  }

  // Android：强制 24 小时制
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (BuildContext ctx, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
}

/// 平台自适应的日期选择器（用于一次性闹钟）
Future<DateTime?> showAdaptiveDatePicker(
  BuildContext context,
  DateTime initial,
) async {
  final DateTime now = DateTime.now();
  if (isIOS) {
    DateTime picked = initial;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  CupertinoButton(
                    child: const Text('完成'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  minimumDate: DateTime(now.year, now.month, now.day),
                  maximumDate: now.add(const Duration(days: 365)),
                  initialDateTime: initial,
                  onDateTimeChanged: (DateTime d) => picked = d,
                ),
              ),
            ],
          ),
        );
      },
    );
    return picked;
  }

  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(now) ? now : initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    locale: const Locale('zh', 'CN'),
  );
}

/// 平台自适应的确认弹窗（删除确认等）
Future<bool?> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool destructive = false,
}) {
  if (isIOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmText,
              style: destructive ? const TextStyle(color: Colors.red) : null,
            ),
          ),
        ],
      );
    },
  );
}

/// 轻提示（Android 用 SnackBar，iOS 用同样组件但更符合 iOS 习惯的圆角文字）
void showAdaptiveToast(BuildContext context, String message) {
  final bool ios = isIOS;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ios ? 14 : 8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}
