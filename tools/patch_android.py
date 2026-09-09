#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
在 flutter create 生成的「官方安卓工程」上，注入本项目需要的定制配置。

为什么要这么做（重要）：
  Flutter 3.4x 起，官方生成的安卓工程用的是 Kotlin DSL（build.gradle.kts），
  如果仓库里再放一份 Groovy 版 android/app/build.gradle，两者会冲突，
  flutter build apk 会直接报：
      Build failed due to use of deleted Android v1 embedding.
  所以正确做法是：原生工程一律由 flutter create 生成，定制内容用本脚本增量注入。

用法（CI 中 flutter create 之后执行）：
    python3 tools/patch_android.py

注入内容：
  1. 闹钟所需全部权限（通知 / 精确闹钟 / 全屏意图 / 震动 / 开机恢复 / 电池白名单）
  2. 主 Activity 支持锁屏显示并点亮屏幕（全屏响铃页的前提）
  3. flutter_local_notifications 的广播接收器（定时通知 + 开机恢复 + 通知按钮）
  4. 把内置铃声拷进 res/raw（通知铃声必须位于原生资源目录）
  5. 若存在 android/key.properties，则注入正式签名配置
"""

import io
import os
import re
import glob
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')

# 闹钟能否后台准时响，一大半取决于这些权限
PERMISSIONS = [
    'android.permission.POST_NOTIFICATIONS',              # Android 13+ 通知权限
    'android.permission.SCHEDULE_EXACT_ALARM',            # Android 12+ 精确闹钟
    'android.permission.USE_EXACT_ALARM',                 # Android 13+ 精确闹钟（系统自动授予）
    'android.permission.USE_FULL_SCREEN_INTENT',          # 锁屏全屏弹窗
    'android.permission.VIBRATE',                         # 震动
    'android.permission.WAKE_LOCK',                       # 响铃时保持 CPU 唤醒
    'android.permission.RECEIVE_BOOT_COMPLETED',          # 开机后恢复闹钟
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',  # 申请电池优化白名单
]

# flutter_local_notifications 需要的接收器
RECEIVERS = '''
        <!-- ===== flutter_local_notifications 需要的广播接收器（由 patch_android.py 注入） ===== -->
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />

        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>

        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
'''

MAIN_ACTIVITY_KT = '''package com.example.work_memo_alarm

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * 主 Activity（由 patch_android.py 写入）
 *
 * 只做一件事：让闹钟触发时，APP 能在「锁屏状态」下被拉起并点亮屏幕。
 * 缺少这些设置时，Android 会拦截全屏意图，响铃页不会显示。
 *
 * 本项目不使用前台服务保活：后台闹钟完全交给系统 AlarmManager，
 * 更省电，也更不容易被国产 ROM 杀掉。
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
'''

# assets 里的铃声文件名 -> 安卓 res/raw 里的资源名（必须与 lib/constants/app_constants.dart 中的 nativeName 一致）
RINGTONE_MAP = {
    'classic_alarm.wav': 'alarm_classic.wav',
    'gentle_morning.wav': 'alarm_gentle_morning.wav',
    'digital_tick.wav': 'alarm_digital_tick.wav',
    'business_bell.wav': 'alarm_business_bell.wav',
}


def patch_manifest():
    """注入权限、Activity 属性与广播接收器"""
    if not os.path.isfile(MANIFEST):
        print('[跳过] 未找到 AndroidManifest.xml，请先执行 flutter create')
        return
    s = io.open(MANIFEST, encoding='utf-8').read()

    # 1) 权限
    missing = [p for p in PERMISSIONS if p not in s]
    if missing:
        block = '\n'.join('    <uses-permission android:name="%s" />' % p for p in missing)
        s = s.replace('<application', block + '\n\n    <application', 1)
        print('[Manifest] 已注入 %d 个权限' % len(missing))
    else:
        print('[Manifest] 权限已存在，跳过')

    # 2) 主 Activity：锁屏显示 + 点亮屏幕
    m = re.search(r'<activity\b[^>]*>', s)
    if m and 'showWhenLocked' not in m.group(0):
        tag = m.group(0)
        new_tag = tag[:-1].rstrip() + '\n            android:showWhenLocked="true"\n            android:turnScreenOn="true">'
        s = s.replace(tag, new_tag, 1)
        print('[Manifest] 已为主 Activity 加入锁屏显示属性')
    else:
        print('[Manifest] Activity 属性已存在，跳过')

    # 3) 广播接收器
    if 'flutterlocalnotifications.ScheduledNotificationBootReceiver' not in s:
        s = s.replace('</application>', RECEIVERS + '    </application>', 1)
        print('[Manifest] 已注入通知广播接收器')
    else:
        print('[Manifest] 接收器已存在，跳过')

    io.open(MANIFEST, 'w', encoding='utf-8').write(s)


def patch_main_activity():
    """写入锁屏拉起用的 MainActivity.kt"""
    hits = glob.glob(os.path.join(ROOT, 'android', 'app', 'src', 'main',
                                  'kotlin', 'com', 'example', 'work_memo_alarm', 'MainActivity.kt'))
    if not hits:
        hits = glob.glob(os.path.join(ROOT, 'android', 'app', 'src', 'main', '**', 'MainActivity.kt'),
                         recursive=True)
    if not hits:
        print('[跳过] 未找到 MainActivity.kt')
        return
    io.open(hits[0], 'w', encoding='utf-8').write(MAIN_ACTIVITY_KT)
    print('[MainActivity] 已写入', os.path.relpath(hits[0], ROOT))


def copy_ringtones():
    """把内置铃声拷进 res/raw（通知铃声只能读原生资源）"""
    src_dir = os.path.join(ROOT, 'assets', 'ringtones')
    dst_dir = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw')
    if not os.path.isdir(src_dir):
        print('[跳过] 未找到 assets/ringtones')
        return
    os.makedirs(dst_dir, exist_ok=True)
    n = 0
    for src_name, dst_name in RINGTONE_MAP.items():
        src = os.path.join(src_dir, src_name)
        if os.path.isfile(src):
            shutil.copyfile(src, os.path.join(dst_dir, dst_name))
            n += 1
    print('[铃声] 已拷贝 %d 个文件到 res/raw' % n)


def patch_signing():
    """存在 android/key.properties 时，注入正式签名配置（Kotlin DSL 写法）"""
    key_props = os.path.join(ROOT, 'android', 'key.properties')
    gradle_files = [os.path.join(ROOT, 'android', 'app', 'build.gradle.kts'),
                    os.path.join(ROOT, 'android', 'app', 'build.gradle')]
    target = next((f for f in gradle_files if os.path.isfile(f)), None)
    if not os.path.isfile(key_props) or not target:
        print('[签名] 无 key.properties 或构建脚本，使用默认调试签名')
        return

    props = {}
    for line in io.open(key_props, encoding='utf-8'):
        if '=' in line:
            k, v = line.strip().split('=', 1)
            props[k.strip()] = v.strip()

    s = io.open(target, encoding='utf-8').read()
    if 'signingConfigs' in s and 'create("release")' in s:
        print('[签名] 签名配置已存在，跳过')
        return

    kotlin = target.endswith('.kts')
    if kotlin:
        block = '''
    signingConfigs {
        create("release") {
            storeFile = file("%s")
            storePassword = "%s"
            keyAlias = "%s"
            keyPassword = "%s"
        }
    }
''' % (props.get('storeFile', ''), props.get('storePassword', ''),
            props.get('keyAlias', ''), props.get('keyPassword', ''))
        s = s.replace('android {', 'android {' + block, 1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("release")')
    else:
        block = '''
    signingConfigs {
        release {
            storeFile file("%s")
            storePassword "%s"
            keyAlias "%s"
            keyPassword "%s"
        }
    }
''' % (props.get('storeFile', ''), props.get('storePassword', ''),
            props.get('keyAlias', ''), props.get('keyPassword', ''))
        s = s.replace('android {', 'android {' + block, 1)
        s = s.replace('signingConfig signingConfigs.debug',
                      'signingConfig signingConfigs.release')

    io.open(target, 'w', encoding='utf-8').write(s)
    print('[签名] 已注入正式签名配置 ->', os.path.relpath(target, ROOT))


def main():
    print('=== patch_android.py 开始 ===')
    patch_manifest()
    patch_main_activity()
    copy_ringtones()
    patch_signing()
    print('=== patch_android.py 完成 ===')


if __name__ == '__main__':
    main()
