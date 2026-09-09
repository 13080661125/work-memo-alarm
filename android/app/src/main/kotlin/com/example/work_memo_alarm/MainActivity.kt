package com.example.work_memo_alarm

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * 主 Activity
 *
 * 这里只做一件事：让闹钟触发时，APP 能在「锁屏状态」下被拉起并点亮屏幕。
 * 如果缺少这些设置，Android 会在锁屏时拦截全屏意图，闹钟响铃页不会显示。
 *
 * 注意：本项目没有使用前台服务保活。
 * 后台闹钟完全依赖系统 AlarmManager（flutter_local_notifications 内部实现），
 * 这样比常驻服务更省电，也更不容易被国产 ROM 杀掉。
 */
@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1+ 推荐写法
            setShowWhenLocked(true)   // 锁屏时显示本 Activity
            setTurnScreenOn(true)     // 自动点亮屏幕
        } else {
            // 旧版本兼容写法
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // 响铃页面停留期间保持屏幕不自动熄灭
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
