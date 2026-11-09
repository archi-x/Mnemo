#!/usr/bin/env bash
# 归档 → 导出 → 上传 TestFlight
#
# 需要的环境变量：
#   TEAM_ID        开发者团队 ID（10 位，App Store Connect → Membership 里能看到）
#   ASC_KEY_ID     App Store Connect API Key 的 Key ID
#   ASC_ISSUER_ID  对应的 Issuer ID
#   ASC_KEY_PATH   私钥路径，默认 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#
# 用法：
#   TEAM_ID=ABCDE12345 ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxx-xxxx ./Scripts/release.sh
#   ./Scripts/release.sh --bump     # 先把 build 号 +1 再打包
#   ./Scripts/release.sh --archive-only   # 只归档不导出/上传

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/Mnemo.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

BUMP=0
ARCHIVE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --bump) BUMP=1 ;;
    --archive-only) ARCHIVE_ONLY=1 ;;
    *) echo "未知参数：$arg"; exit 1 ;;
  esac
done

if [[ -z "${TEAM_ID:-}" ]]; then
  echo "缺少 TEAM_ID（开发者团队 ID）"; exit 1
fi

if [[ "$BUMP" == "1" ]]; then
  current=$(grep -m1 "CURRENT_PROJECT_VERSION = " Mnemo.xcodeproj/project.pbxproj | grep -o '[0-9]\+')
  next=$((current + 1))
  sed -i '' "s/CURRENT_PROJECT_VERSION = $current;/CURRENT_PROJECT_VERSION = $next;/g" Mnemo.xcodeproj/project.pbxproj
  echo "build 号 $current → $next"
fi

echo "==> 归档 Release"
xcodebuild archive \
  -project Mnemo.xcodeproj \
  -scheme Mnemo \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  | tail -5

if ! grep -q "archive" "$ARCHIVE/Info.plist" 2>/dev/null; then
  echo "归档失败：$ARCHIVE 不存在"; exit 1
fi

if [[ "$ARCHIVE_ONLY" == "1" ]]; then
  echo "已归档：$ARCHIVE"
  exit 0
fi

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "缺少 ASC_KEY_ID / ASC_ISSUER_ID，跳过导出与上传"; exit 1
fi
KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
if [[ ! -f "$KEY_PATH" ]]; then
  echo "找不到私钥：$KEY_PATH"; exit 1
fi

echo "==> 导出 ipa"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/Scripts/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  | tail -5

IPA=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 1 | head -1)
if [[ -z "$IPA" ]]; then
  echo "导出失败：没有找到 ipa"; exit 1
fi
echo "ipa：$IPA"

echo "==> 上传 TestFlight"
xcrun altool --upload-app \
  -f "$IPA" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --output-format normal

echo "==> 完成。构建需要几分钟处理，之后在 App Store Connect → TestFlight 里会看到新版本。"
