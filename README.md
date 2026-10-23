# 油錢計算

自己用的加油記帳 app。站在加油島旁邊，拍一張油機、補上里程，就記完了。

- 原生 SwiftUI + SwiftData，iPhone 直向，iOS 18 以上
- 拍照辨識油機上的**金額**與**公升數**（Apple Vision，全部在手機上跑，不上傳）
- 平常會看的數字：**平均油耗 km/L**、**每公里成本 $/km**、趨勢圖、每次加油明細
- 固定 95 加滿，所以每筆的公升數＝上次到這次的油耗區間；第一筆當基準不列入平均
- 淺色是「白天在加油站」、深色是「夜裡的店」，跟著系統切換

## 怎麼裝

| 檔案 | 用途 |
|---|---|
| `build/FuelCost-unsigned.ipa` | 未簽名，給 Sideloadly／AltStore／ESign 這類工具簽名後安裝 |
| `build/FuelCost-signed.ipa` | 已用你的憑證簽好，**只裝得進描述檔授權的那一台裝置** |

未簽名的 ipa 丟給 iPhone 是裝不上去的，它一定要先被簽名。想用 Xcode 直接裝機的話：

```
open FuelCost.xcodeproj
```

選 target `FuelCost` → Signing & Capabilities → 掛上自己的 Apple ID 個人團隊 → 選自己的手機 → Run。
個人免費帳號的簽名 7 天到期，重跑一次就好。

### 已簽名那份的注意事項

那份是用你提供的憑證包簽的，簽名前它會把 bundle identifier 改成描述檔裡的 App ID
（描述檔指定的 App ID），因為描述檔不是萬用字元，bundle id 不跟著改就開不起來。
要知道的幾件事：

- 只裝得進描述檔 `ProvisionedDevices` 列出的那一台裝置
- 描述檔到期日 **2027-07-09**，到期後 app 會打不開，要用新的描述檔重簽
- 這是簽名服務的共享憑證，對方隨時可能撤銷；被撤銷的話 app 就開不起來，要重簽
- 重簽：`./Tools/make-signed-ipa.sh <憑證包目錄>`（目錄裡要有 `cert.p12`、
  `profile.mobileprovision`、`password.txt`）

## 專案結構

```
FuelCost/
  FuelCostApp.swift        app 進入點、SwiftData 容器
  Models/
    RefuelRecord.swift     一筆加油紀錄
    FuelStats.swift        平均油耗、每公里成本、里程倒退的處理
    RecordDraft.swift      輸入中的草稿與即時試算
  Services/
    PumpTextRecognizer.swift  Vision 辨識核心（純影像，不碰 UI）
    FuelPumpParser.swift      從一堆字裡挑出金額／公升／單價
    ReceiptScanner.swift      拍照到辨識的接線
    PhotoStore.swift          照片存到 Application Support
    SampleData.swift          範例資料（只有 DEBUG）
  World/                   紙、麥克筆數字、手寫線條
  Views/                   三個分頁、紀錄、趨勢、輸入頁
Tools/                     驗證腳本與打包腳本
```

## 自己改的時候

```bash
# 算術與解析器的單元檢查（59 項，會比較預期值）
swiftc -enable-bare-slash-regex FuelCost/Models/FuelStats.swift \
      FuelCost/Services/FuelPumpParser.swift Tools/core-check.swift -o /tmp/corecheck && /tmp/corecheck

# 把辨識核心拿去讀 Tools/fixtures 的照片，印出讀到什麼（要給圖片路徑）
swiftc -enable-bare-slash-regex FuelCost/Services/PumpTextRecognizer.swift \
      FuelCost/Services/FuelPumpParser.swift Tools/ocr-check.swift -o /tmp/ocrcheck \
  && /tmp/ocrcheck Tools/fixtures/receipt.png Tools/fixtures/pump-led.png

# 手寫數字畫出來再讀回去，確認還認得
swiftc -enable-bare-slash-regex FuelCost/Services/FuelPumpParser.swift \
      FuelCost/Services/PumpTextRecognizer.swift FuelCost/World/MarkerGlyphs.swift \
      Tools/glyph-check.swift -o /tmp/glyphcheck && /tmp/glyphcheck

# 截圖（會 build、裝進模擬器、淺色深色各拍一輪）
./Tools/capture.sh
```

數字是自己畫的（`MarkerGlyphs`），不依賴任何手寫字型，所以不用擔心字型沒裝到。

## 已知限制

- 辨識是「讀到什麼就填什麼」，讀不到會說讀不到，不會自己編一個數字給你
- 油機的數字如果被反光或被油槍擋住，可能要重拍，或直接手打
- 只支援一台車
- 沒有雲端、沒有帳號，資料只在這一台手機的 App 裡
