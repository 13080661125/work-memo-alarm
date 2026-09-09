@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title 工作备忘录 - 推送到 GitHub

cd /d "%~dp0"
set "REPO=work-memo-alarm"

echo ============================================================
echo    工作备忘录 + 闹钟提醒  —— 一键推送到 GitHub
echo ============================================================
echo.

REM ---------- 1. 找到 git.exe ----------
set "GITEXE="
where git >nul 2>&1 && set "GITEXE=git"
if not defined GITEXE if exist "C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\mingw64\bin\git.exe" (
  set "GITEXE=C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\mingw64\bin\git.exe"
)
if not defined GITEXE if exist "C:\Program Files\Git\bin\git.exe" set "GITEXE=C:\Program Files\Git\bin\git.exe"
if not defined GITEXE (
  echo [错误] 没有找到 git，请先安装：https://git-scm.com/download/win
  echo        安装时一路点 Next 即可，装完重新双击本文件。
  echo.
  pause
  exit /b 1
)
echo [OK] 已找到 git：!GITEXE!
echo.

REM ---------- 2. 输入用户名 ----------
set "GHUSER="
set /p GHUSER=请输入你的 GitHub 用户名（例如 zhangsan）: 
if "!GHUSER!"=="" (
  echo [错误] 用户名不能为空。
  pause
  exit /b 1
)

REM ---------- 3. 打开 GitHub 建仓库页面 ----------
echo.
echo 接下来会在浏览器打开 GitHub 新建仓库页面，请按下面操作：
echo    Repository name 已经自动填好：!REPO!
echo    1. 选 Public（公开，Actions 时长不限）或 Private（私有，每月 2000 分钟）
echo    2. 一定不要勾选 "Add a README file"
echo    3. 点绿色按钮 Create repository
echo.
pause
start "" "https://github.com/new?name=!REPO!"
echo.
echo 仓库建好后，回到这个黑窗口，按任意键继续...
pause >nul

REM ---------- 4. 推送 ----------
echo.
echo 正在推送，首次推送会要求登录 GitHub：
echo    用户名 = 你的 GitHub 用户名
echo    密码   = Personal Access Token（不是登录密码！）
echo          没有 Token 的话，打开 https://github.com/settings/tokens
echo          点 Generate new token (classic)，勾选 repo，生成后复制过来
echo.
"%GITEXE%" branch -M master
"%GITEXE%" remote remove origin >nul 2>&1
"%GITEXE%" remote add origin https://github.com/!GHUSER!/!REPO!.git
"%GITEXE%" push -u origin master

if errorlevel 1 (
  echo.
  echo [推送失败] 常见原因：
  echo   1. 仓库还没建 / 地址写错  -> 确认 https://github.com/!GHUSER!/!REPO! 能打开
  echo   2. 密码填成了登录密码      -> 必须填 Personal Access Token
  echo   3. 网络问题                -> 换个网络或稍后重试
  echo.
  echo 也可以改用 GitHub Desktop 图形界面：https://desktop.github.com
  pause
  exit /b 1
)

echo.
echo ============================================================
echo    推送成功！接下来：
echo.
echo  1. 打开仓库页面看编译进度（约 10 分钟）：
echo     https://github.com/!GHUSER!/!REPO!/actions
echo.
echo  2. 下载安卓安装包：Actions 页面点进最新任务，
echo     最下面 Artifacts 里下载 android-apk，
echo     解压后选 app-arm64-v8a-release.apk 传到手机安装。
echo.
echo  3. 想要手机浏览器直接打开的网页版（一次性设置）：
echo     https://github.com/!GHUSER!/!REPO!/settings/pages
echo     把 Source 改成 GitHub Actions，然后 Save。
echo     网址就是：https://!GHUSER!.github.io/!REPO!/
echo.
echo ============================================================
pause
