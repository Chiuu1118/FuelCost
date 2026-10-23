#!/bin/bash
# 用你提供的憑證包，打包一個「已簽名」的 .ipa。
#
# 這個腳本要的憑證包（解壓縮後）：
#   cert.p12              憑證與私鑰
#   profile.mobileprovision  描述檔
#   password.txt          「密碼：xxxx」這種格式，冒號後面就是密碼
#
#   ./Tools/make-signed-ipa.sh <憑證包目錄>
#
# 產物：build/FuelCost-signed.ipa

set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_DIR="${1:-/tmp/fuelcert}"
PROJECT="FuelCost.xcodeproj"
SCHEME="FuelCost"
DERIVED="build/dd-signed"
STAGE="build/signed"
OUT="build/FuelCost-signed.ipa"
KEYCHAIN="build/signing.keychain"
KEYCHAIN_PASS="fuelcost-signing"

if [ ! -f "$BUNDLE_DIR/cert.p12" ] || [ ! -f "$BUNDLE_DIR/profile.mobileprovision" ]; then
  echo "找不到憑證包內容：$BUNDLE_DIR" >&2
  exit 1
fi

# 描述檔裡的 App ID 就是這個 app 必須用的 bundle identifier。
# 描述檔不是萬用字元的話，bundle id 一定要跟著改，不然裝上去開不起來。
APP_ID=$(security cms -D -i "$BUNDLE_DIR/profile.mobileprovision" \
  | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null)
TEAM_ID="${APP_ID%%.*}"
BUNDLE_ID="${APP_ID#*.}"
PROFILE_NAME=$(security cms -D -i "$BUNDLE_DIR/profile.mobileprovision" | plutil -extract Name raw -o - - 2>/dev/null)
DEVICES=$(security cms -D -i "$BUNDLE_DIR/profile.mobileprovision" | plutil -extract ProvisionedDevices xml1 -o - - 2>/dev/null | grep -c "<string>" || true)

echo "==> 描述檔：$PROFILE_NAME"
echo "    簽發團隊：$TEAM_ID"
echo "    bundle id 要改成：$BUNDLE_ID"
echo "    這份描述檔授權的裝置數：$DEVICES"

# 1. 準備一個臨時鑰匙圈，不碰你平常用的登入鑰匙圈。
echo "==> 準備臨時鑰匙圈"
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
rm -f "$KEYCHAIN"
security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"

PW="$(sed 's/.*[：:]//' "$BUNDLE_DIR/password.txt" 2>/dev/null | tr -d '\r\n' || true)"
if [ -z "$PW" ]; then
  echo "讀不到 p12 密碼（password.txt 應該是「密碼：xxxx」）" >&2
  exit 1
fi

# macOS 不吃的 PKCS#12 格式（OpenSSL 3/4 的預設）要先轉成 3DES。
IMPORT_P12="$BUNDLE_DIR/cert.p12"
if ! security import "$IMPORT_P12" -k "$KEYCHAIN" -P "$PW" -T /usr/bin/codesign >/dev/null 2>&1; then
  echo "==> 原始 p12 格式 macOS 不支援，轉成相容格式"
  TMPDIR_SIGN="build/signing-tmp"
  rm -rf "$TMPDIR_SIGN"; mkdir -p "$TMPDIR_SIGN"
  openssl pkcs12 -in "$BUNDLE_DIR/cert.p12" -nocerts -nodes -passin pass:"$PW" -out "$TMPDIR_SIGN/key.pem" 2>/dev/null
  openssl pkcs12 -in "$BUNDLE_DIR/cert.p12" -clcerts -nokeys -passin pass:"$PW" -out "$TMPDIR_SIGN/cert.pem" 2>/dev/null
  openssl pkcs12 -export -in "$TMPDIR_SIGN/cert.pem" -inkey "$TMPDIR_SIGN/key.pem" -out "$TMPDIR_SIGN/fixed.p12" \
    -passout pass:"$PW" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 2>/dev/null
  IMPORT_P12="$TMPDIR_SIGN/fixed.p12"
fi
security import "$IMPORT_P12" -k "$KEYCHAIN" -P "$PW" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASS" "$KEYCHAIN" >/dev/null 2>&1

# 2. 憑證鏈。沒有 Apple 的中繼憑證，codesign 會說鏈接不到根。
if ! security verify-cert -c <(security find-certificate -c "iPhone Distribution" -p "$KEYCHAIN" 2>/dev/null) >/dev/null 2>&1; then
  echo "==> 補上 Apple WWDR G3 中繼憑證"
  if [ ! -f "build/AppleWWDRCAG3.pem" ]; then
    mkdir -p build
    curl -sS --max-time 30 -o build/AppleWWDRCAG3.cer \
      https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
    openssl x509 -inform DER -in build/AppleWWDRCAG3.cer -out build/AppleWWDRCAG3.pem
  fi
  security import build/AppleWWDRCAG3.pem -k "$KEYCHAIN" -T /usr/bin/codesign >/dev/null
fi

IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -o '"[^"]*"' | head -1 | tr -d '"')
if [ -z "$IDENTITY" ]; then
  echo "鑰匙圈裡沒有可用的簽名身分" >&2
  security find-identity -v -p codesigning "$KEYCHAIN" >&2
  exit 1
fi
echo "==> 簽名身分：$IDENTITY"

# 3. 建置（先不簽名，簽名自己來，這樣才能精準控制 entitlements）。
echo "==> 建置 Release（裝置用，稍後手動簽名）"
rm -rf "$DERIVED" "$STAGE" "$OUT"
xcodebuild \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build > /tmp/fuelcost-signed-build.log 2>&1 || {
    echo "建置失敗，看 /tmp/fuelcost-signed-build.log" >&2; tail -20 /tmp/fuelcost-signed-build.log >&2; exit 1
  }

APP_SRC="$DERIVED/Build/Products/Release-iphoneos/$SCHEME.app"
mkdir -p "$STAGE/Payload"
cp -R "$APP_SRC" "$STAGE/Payload/"
APP="$STAGE/Payload/$SCHEME.app"

# 4. 描述檔要放進 app 裡，並依它產生 entitlements。
cp "$BUNDLE_DIR/profile.mobileprovision" "$APP/embedded.mobileprovision"
mkdir -p build
python3 - "$BUNDLE_DIR/profile.mobileprovision" build/entitlements.plist <<'PY'
import plistlib, subprocess, sys
raw = subprocess.run(['security','cms','-D','-i',sys.argv[1]], capture_output=True).stdout
profile = plistlib.loads(raw)
ents = dict(profile['Entitlements'])
# get-task-allow 是描述檔的說法，不該寫進簽章。
ents.pop('get-task-allow', None)
ents['application-identifier'] = profile['Entitlements']['application-identifier']
with open(sys.argv[2],'wb') as f:
    plistlib.dump(ents, f)
print(f"    entitlements 共 {len(ents)} 項")
PY

# 5. 簽。
echo "==> 簽名"
codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" \
  --entitlements build/entitlements.plist --timestamp=none "$APP" 2>&1 | sed 's/^/    /'

echo "==> 驗證"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'
codesign -dv --entitlements - "$APP" 2>&1 | grep -E "Identifier|TeamIdentifier|Authority|application-identifier" | sed 's/^/    /'

# 6. 打包。
OUT_NAME="$(basename "$OUT")"
(cd "$STAGE" && zip -qry "../$OUT_NAME" Payload)

security delete-keychain "$KEYCHAIN" 2>/dev/null || true
rm -rf build/signing-tmp

echo
echo "==> 完成：$OUT ($(du -h "$OUT" | cut -f1))"
echo "    這份 ipa 只會裝在描述檔授權的裝置上，而且到描述檔到期為止。"
