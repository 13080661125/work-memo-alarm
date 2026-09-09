# 工作备忘录 + 闹钟提醒（Flutter 跨平台）

一款**简约商务风格**的工作备忘录 App，内置闹钟提醒能力，一套代码同时运行在 **Android 与 iOS**。
所有代码均带有**详细中文注释**，可直接运行与二次开发。

---

## 🚀 想马上用起来？（先看这个）

### 路线 A：不装 App，手机浏览器直接打开（1 分钟）

项目里附带了**浏览器版**：`web_preview/index.html`，纯静态单文件，功能与原生版一致。

```bash
# 在 web_preview 目录执行，手机连同一 WiFi 后访问 http://<本机IP>:8080
python -m http.server 8080 --bind 0.0.0.0
```

也可以双击 `index.html` 直接在电脑上用。
长期使用的固定网址（GitHub Pages 自动部署）见 **[docs/06-浏览器版](docs/06-浏览器版（无需安装，手机直接打开）.md)**。
⚠️ 浏览器版闹钟需要页面保持打开，锁屏必响请用下面的原生 App。

### 路线 B：编译成安装包，装到手机桌面

源码不能直接安装，需要**编译成安装包**。不想在本机装环境的话，用云端自动打包：

> **👉 完整步骤见 [docs/05-云端自动打包（推代码就出安装包）.md](docs/05-云端自动打包（推代码就出安装包）.md)**

本地 git 仓库已初始化完毕，你只需要 3 步：

```bash
# ① 在 https://github.com 新建空仓库 work-memo-alarm（不要勾选 README）

# ② 关联你的仓库（把用户名换成你自己的）
git remote add origin https://github.com/你的用户名/work-memo-alarm.git

# ③ 推送，云端自动开始编译
git branch -M main
git push -u origin main
```

推送后打开仓库的 **Actions** 页面，等约 10 分钟，在 **Artifacts** 里下载
`app-arm64-v8a-release.apk`（安卓），传到手机即可安装。
iPhone 需要额外签名，方案见 docs/05 第五节（苹果的安全机制，无法绕过）。

---

## 一、功能清单

### 备忘录模块
| 功能 | 说明 |
| --- | --- |
| 新建 / 编辑 / 删除 | 标题 + 正文，编辑页支持优先级、完成状态、绑定提醒 |
| 优先级 | 高 / 中 / 低，卡片左侧色条 + 角标（红 / 橙 / 绿） |
| 待办勾选 | 勾选后标题划线置灰，顶部统计"待办 N 条" |
| 搜索 | 实时匹配**标题 + 正文**，忽略大小写 |
| 绑定提醒闹钟 | 每条备忘录可绑定一个提醒时间，删除备忘录时闹钟同步删除 |
| 本地持久化 | SharedPreferences 保存 JSON，重启 / 杀进程后数据不丢 |
| 排序 | 创建时间（新→旧 / 旧→新）、优先级（高→低 / 低→高） |

### 闹钟模块
| 功能 | 说明 |
| --- | --- |
| 多条闹钟 | 数量不限，支持开关、编辑、滑动删除 |
| 时间设置 | **24 小时制**，Android 用 Material 时间选择器、iOS 用滚轮选择器 |
| 重复周期 | 周一~周日多选，并提供"每天 / 工作日 / 周末 / 仅一次"快捷选项 |
| 两种来源 | ① 闹钟页单独新建 ② 在备忘录中直接绑定提醒时间（统一数据模型） |
| 后台响铃 | 基于系统 AlarmManager / 本地通知，APP 退到后台、锁屏、重启手机后依然会响 |
| 全屏提醒弹窗 | Android 全屏意图直接拉起；iOS 点击通知进入；持续铃声 + 震动 |
| 弹窗操作 | **关闭提醒** / **贪睡 10 分钟**（通知栏也有这两个按钮） |
| 内置铃声 | 4 首代码合成的内置铃声，可试听、可切换（双端原生资源均已备好） |

### 权限与后台
- Android：自动申请**通知权限**、引导开启**精确闹钟权限**、引导加入**电池优化白名单**
- iOS：申请**通知权限**，AppDelegate 已配置通知代理与后台插件注册
- 设置页提供权限自检面板，一键确认"闹钟能不能准时响"

---

## 二、技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | Flutter ≥ 3.44.0（Dart ≥ 3.11） |
| 状态管理 | provider（ChangeNotifier） |
| 本地存储 | shared_preferences（JSON 序列化） |
| 闹钟 / 通知 | flutter_local_notifications + timezone + flutter_timezone |
| 权限 | permission_handler |
| 响铃 | audioplayers（循环播放）+ vibration（震动） |
| 时间格式 | intl（统一 24 小时制） |

---

## 三、目录结构

```
work_memo_alarm/
├─ lib/
│  ├─ main.dart                  # 入口：初始化存储 → 通知 → 状态 → 启动界面
│  ├─ app.dart                   # 根组件：Provider 注入 + 主题
│  ├─ constants/app_constants.dart  # 配色 / 铃声清单 / 存储键 / 通知常量
│  ├─ models/
│  │  ├─ memo.dart               # 备忘录模型（优先级、排序枚举）
│  │  └─ alarm.dart              # 闹钟模型（重复周期、来源、通知 ID 基址）
│  ├─ services/
│  │  ├─ storage_service.dart    # 本地持久化
│  │  ├─ notification_service.dart # 定时通知调度（核心）
│  │  ├─ ringing_service.dart    # 铃声 + 震动
│  │  └─ permission_service.dart # 双端权限
│  ├─ providers/
│  │  ├─ memo_provider.dart      # 备忘录状态
│  │  └─ alarm_provider.dart     # 闹钟状态 + 同步系统通知
│  ├─ pages/                     # 首页 / 列表 / 编辑 / 响铃 / 设置
│  ├─ widgets/                   # 卡片、空状态、平台适配组件
│  └─ utils/time_util.dart       # 24 小时制格式化、重复规则中文描述
├─ assets/ringtones/             # 内置铃声（Flutter 资源，用于 App 内播放）
├─ android/app/src/main/res/raw/ # 同一批铃声（安卓通知铃声）
├─ ios/Runner/Ringtones/         # 同一批铃声（需在 Xcode 加入 Bundle）
├─ tools/generate_ringtones.py   # 铃声生成脚本（纯代码合成，无版权风险）
└─ docs/                         # 环境搭建 / 打包 / 后台保活说明
```

---

## 四、三步跑起来

```bash
# 1. 安装依赖
flutter pub get

# 2. 检查环境（按提示修复红叉）
flutter doctor -v

# 3. 运行（连接手机或启动模拟器后）
flutter run
```

> ⚠️ 首次使用请先按 [`docs/01-环境搭建与运行.md`](docs/01-环境搭建与运行.md) 完成原生脚手架生成与铃声资源放置，
> 否则 iOS 端通知铃声不会响、安卓端可能缺少原生工程文件。

---

## 五、文档索引

| 文档 | 内容 |
| --- | --- |
| [01-环境搭建与运行](docs/01-环境搭建与运行.md) | SDK 安装、国内镜像、Android / iOS 运行步骤、常见问题 |
| [02-打包APK与IPA教程](docs/02-打包APK与IPA教程.md) | 安卓签名与 APK / AAB 打包、iOS 证书与 IPA 导出上架 |
| [03-安卓后台保活与iOS通知限制](docs/03-安卓后台保活与iOS通知限制.md) | 安卓各 ROM 白名单设置、Doze 适配；iOS 本地通知的系统硬限制 |
| [04-项目结构与二次开发](docs/04-项目结构与二次开发.md) | 数据流图、闹钟触发链路、常见改造点 |

---

## 六、需求对应实现速查

| 需求 | 实现位置 |
| --- | --- |
| 备忘录增删改 | `lib/pages/memo_edit_page.dart` + `lib/providers/memo_provider.dart` |
| 优先级 / 完成状态 | `lib/models/memo.dart` |
| 搜索筛选 | `MemoProvider.visibleMemos` |
| 排序 | `MemoSortMode` + 列表页排序菜单 |
| 绑定提醒 | `MemoEditPage._openAlarmEdit` → `AlarmEditPage(memoId:)` |
| 本地持久化 | `StorageService`（SharedPreferences） |
| 闹钟重复周期 | `AlarmEditPage._weekdayItem` + `NotificationService.scheduleAlarm` |
| 后台响铃 | `AndroidScheduleMode.exactAllowWhileIdle` + `fullScreenIntent` |
| 全屏弹窗 / 贪睡 | `lib/pages/alarm_ringing_page.dart` + `NotificationService.scheduleSnooze` |
| 铃声 / 震动 | `RingingService`（audioplayers + vibration） |
| 24 小时制 | `TimeUtil` + `showAdaptiveTimePicker` |
| 双端权限 | `PermissionService` + `HomePage._guidePermissions` |
