#!/bin/bash
# 在模擬器上把每一頁截下來。
#
#   ./Tools/capture.sh
#
# 需要先安裝 Debug 版（xcodebuild … build 之後就會自動裝進模擬器）。
# 產物在 .impeccable/review/。

set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE="com.chiuu.fuelcost"
OUT=".impeccable/review"
DEST="platform=iOS Simulator,name=iPhone 17"
mkdir -p "$OUT"

build_and_install() {
  xcodebuild -project FuelCost.xcodeproj -scheme FuelCost -sdk iphonesimulator \
    -destination "$DEST" -configuration Debug build > /tmp/fuelcost-build.log 2>&1 || {
      echo "建置失敗，看 /tmp/fuelcost-build.log" >&2
      exit 1
    }
  local app
  app=$(find ~/Library/Developer/Xcode/DerivedData/FuelCost-*/Build/Products/Debug-iphonesimulator \
        -maxdepth 1 -name "FuelCost.app" | head -1)
  xcrun simctl install booted "$app"
}

shoot() {
  local name="$1"; shift
  xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch booted "$BUNDLE" "$@" >/dev/null
  # 冷啟動要播種示範資料再算第一次，慢的時候四秒多才畫出記帳板；
  # 只等 5 秒會截到「數字正在被寫上去」的那一瞬間（大數字只剩兩三成不透明度）。
  # 寧可多等，也不要一張看起來像壞掉的證據。
  sleep 9
  xcrun simctl io booted screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $OUT/$name.png"
}

appearance() {
  xcrun simctl ui booted appearance "$1" >/dev/null
  sleep 2
}

echo "==> 建置並安裝"
build_and_install

echo "==> 淺色模式"
appearance light
shoot dashboard-light -seedSampleData
shoot history-light   -seedSampleData -startTab history
shoot trends-light    -seedSampleData -startTab trends
shoot entry-empty-light -seedSampleData -openEntry
shoot entry-scanned-light -seedSampleData -openEntryScanned

echo "==> 深色模式"
appearance dark
shoot dashboard-dark -seedSampleData
shoot history-dark   -seedSampleData -startTab history
shoot trends-dark    -seedSampleData -startTab trends
shoot entry-scanned-dark -seedSampleData -openEntryScanned

echo "==> 空資料（第一次打開的樣子）"
appearance light
xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall booted "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData/FuelCost-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name 'FuelCost.app' | head -1)"
shoot dashboard-empty

echo "==> 完成"
ls -la "$OUT"
