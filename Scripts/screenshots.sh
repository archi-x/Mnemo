#!/usr/bin/env bash
# 生成 App Store 截图（6.9 英寸，1320×2868）
#
# 用法：
#   ./Scripts/screenshots.sh [设备名] [输出目录]
#   THEME=night|day ./Scripts/screenshots.sh
# 默认：设备 "Mnemo 6.9"，输出 Docs/appstore/6.9，配色 深夜
#
# 前置：已用 iPhone 18 Pro Max + iOS 27.0 运行时创建过模拟器，并 boot；
#      build 目录里有 Debug-iphonesimulator/Mnemo.app。

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEVICE="${1:-Mnemo 6.9}"
OUT="${2:-$ROOT/Docs/appstore/6.9}"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/Mnemo.app"
BUNDLE="com.tal.mnemo"
THEME="${THEME:-night}"
if [[ "$THEME" == "day" ]]; then THEME_FLAG="-day"; else THEME_FLAG="-night"; fi

[[ -d "$APP" ]] || { echo "找不到 $APP，先跑一次 xcodebuild build"; exit 1; }
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
# 状态栏统一成 Apple 常用的 9:41 + 满格
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" \
  --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"

# 截一张，若是启动白屏就重试（体积小说明还没渲染）
shot() {
  local path="$1"
  local i=0
  while (( i < 20 )); do
    xcrun simctl io "$DEVICE" screenshot "$path" >/dev/null 2>&1 || true
    if [[ -f "$path" ]] && (( $(stat -f%z "$path") > 250000 )); then
      return 0
    fi
    sleep 2
    ((i++))
  done
  echo "  ! $path 可能是白屏"
  return 0
}

capture() {
  local name="$1"; shift
  echo "==> $name"
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  sleep 0.4
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" "$THEME_FLAG" >/dev/null
  sleep 8
  shot "$OUT/$name.png"
  sleep 1.5
  shot "$OUT/$name.png"
  sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | tail -2
}

# 1. 首次进入：建立档案（需要干净数据）
capture "01-login" -loginName 林小满

# 2. 今日（注入演示数据）
capture "02-today" -seedDemo -skipLogin -tab today

# 3. 训练场
capture "03-drill" -skipLogin -tab drill

# 4. 方法练习（九种题型，第 6 号方法 + L2）
capture "04-practice" -skipLogin -tab library -method 6 -practice -autostart

# 5. 闯关地图
capture "05-quest-map" -skipLogin -tab drill -screen quest

# 6. 闯关玩法：小学高年级 · 排排队
capture "06-quest-game" -skipLogin -tab drill -game primaryHigh 0 1

# 7. 学习报告
capture "07-report" -skipLogin -tab drill -screen report

# 8. 遗忘曲线
capture "08-curve" -skipLogin -tab drill -screen curve

# 9. 错题本
capture "09-wrong" -skipLogin -tab drill -screen wrong

# 10. 我的
capture "10-profile" -skipLogin -tab profile

# 附加：已设密码时的解锁页（放 extra，不参与 App Store 上传）
SUFFIX=""; [[ "$THEME" == "day" ]] && SUFFIX="-day"
EXTRA="$(dirname "$OUT")/extra${SUFFIX}"
mkdir -p "$EXTRA"
capture "11-unlock" -demoLocked
mv "$OUT/11-unlock.png" "$EXTRA/unlock.png" 2>/dev/null || true

echo "完成：${OUT}（App Store 用 01–10）"; echo "附加解锁页：${EXTRA}/unlock.png"
ls -la "$OUT"
