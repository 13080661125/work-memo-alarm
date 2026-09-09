import UIKit
import Flutter
import flutter_local_notifications

// =============================================================
// iOS 入口
// -------------------------------------------------------------
// 两个关键点（缺一不可）：
//  1. 设置 UNUserNotificationCenter 的 delegate
//     → 否则 APP 在前台时收到通知不会显示（iOS 默认不弹前台通知）
//  2. 注册 setPluginRegistrantCallback
//     → 否则用户在后台点击通知上的"贪睡/关闭"按钮时，
//       后台 isolate 里拿不到插件，无法处理动作
// =============================================================
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1) 让 iOS 10+ 的通知在 APP 前台时也能显示（FlutterLocalNotificationsPlugin 实现了该协议）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // 2) 后台 isolate 中处理通知响应时，需要注册插件
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
