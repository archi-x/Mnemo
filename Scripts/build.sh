#!/usr/bin/env bash
# 构建 iOS 模拟器 Debug 包（默认 iPhone 18 Pro）
#
# 用法：
#   ./Scripts/build.sh                       # 构建
#   ./Scripts/build.sh "iPhone 18"           # 指定模拟器
#   ./Scripts/build.sh --install             # 构建后装到模拟器并启动
#   ./Scripts/build.sh --install "iPhone 18"
#
# 为什么带 SWIFT_USE_INTEGRATED_DRIVER=NO 和 -disable-sandbox：
#   Xcode 27 编译时会为宏插件（SwiftUIMacros / ObservationMacros 等）单独起
#   swift-plugin-server，并用 /usr/bin/sandbox-exec 给这个进程套一层沙箱。
#   当构建本身跑在受限 shell 里（Agent 终端、CI、各类父级沙箱）时，这层嵌套
#   沙箱申请被拒绝，日志里能看到 sandbox-exec: sandbox_apply: Operation not permitted，
#   插件进程随即返回 malformed response，所有 @State / @Observable 展开失败，
#   再级联出上千条 "cannot assign to property: 'self' is immutable" 之类的假错误。
#   -disable-sandbox 只关掉"给子进程套沙箱"这一步，不改编译产物，也不影响 App 运行。
#   Xcode GUI 里 Cmd+R 不走沙箱，不需要这些参数。
#
# 日志：build/build.log（失败时自动打印关键行）

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Build/Products/Debug-iphonesimulator/Mnemo.app"
BUNDLE="com.tal.mnemo"
LOG="$BUILD_DIR/build.log"

DEVICE="iPhone 18 Pro"
INSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) INSTALL=1; shift ;;
    -d|--device) DEVICE="${2:?--device 需要一个模拟器名}"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    -*) echo "未知参数：$1"; exit 1 ;;
    *) DEVICE="$1"; shift ;;
  esac
done

mkdir -p "$BUILD_DIR"

echo "==> 构建 Debug · $DEVICE"
if ! xcodebuild build \
  -project Mnemo.xcodeproj \
  -scheme Mnemo \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$BUILD_DIR" \
  SWIFT_USE_INTEGRATED_DRIVER=NO \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' \
  > "$LOG" 2>&1; then
  echo "构建失败，完整日志：$LOG"
  if grep -q "Unable to find a device matching the provided destination specifier" "$LOG"; then
    echo "找不到名为「${DEVICE}」的模拟器。可用设备："
    xcrun simctl list devices available \
      | grep -oE "(iPhone|iPad)[^(]*" \
      | sed -E 's/ +$//' | sort -u | sed 's/^/  - /'
  elif grep -q "error:" "$LOG"; then
    grep -E "error:" "$LOG" | sed -E 's/^.*error: //' | sort -u | head -15
  else
    tail -30 "$LOG"
  fi
  exit 1
fi

[[ -d "$APP" ]] || { echo "构建没有报错，但没找到 $APP"; exit 1; }
echo "构建成功：$APP"

if [[ "$INSTALL" == "1" ]]; then
  echo "==> 安装到 $DEVICE"
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
  xcrun simctl install "$DEVICE" "$APP"
  xcrun simctl launch "$DEVICE" "$BUNDLE"
fi
