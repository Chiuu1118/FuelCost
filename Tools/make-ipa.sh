#!/bin/bash
# 打包一個「未簽名」的 .ipa。
#
# 未簽名的 ipa 不能直接裝上 iPhone：它是給你自己用 Sideloadly、AltStore、
# ESign 這類工具簽名用的半成品。要用 Xcode 直接裝機的話，開 FuelCost.xcodeproj
# 選好自己的個人團隊簽名再 Build 就好。
#
#   ./Tools/make-ipa.sh
#
# 產物：build/FuelCost-unsigned.ipa

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="FuelCost.xcodeproj"
SCHEME="FuelCost"
DERIVED="build/dd"
IPA_DIR="build/ipa"
OUT="build/FuelCost-unsigned.ipa"

echo "==> 建置 Release（裝置用，不簽名）"
rm -rf "$DERIVED" "$IPA_DIR" "$OUT"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  build

APP="$DERIVED/Build/Products/Release-iphoneos/$SCHEME.app"
if [ ! -d "$APP" ]; then
  echo "找不到建置產物：$APP" >&2
  exit 1
fi

echo "==> 包成 Payload/ 再壓縮"
mkdir -p "$IPA_DIR/Payload"
cp -R "$APP" "$IPA_DIR/Payload/"
# 未簽名的 ipa 不該留著舊的簽章檔
rm -rf "$IPA_DIR/Payload/$SCHEME.app/_CodeSignature" "$IPA_DIR/Payload/$SCHEME.app/embedded.mobileprovision"

(cd "$IPA_DIR" && zip -qry "../$(basename "$OUT")" Payload)

echo "==> 完成：$OUT"
ls -lh "$OUT"
echo
echo "提醒：這個 ipa 沒有簽章，iPhone 不會直接接受。請用自己的工具簽名後再安裝。"
