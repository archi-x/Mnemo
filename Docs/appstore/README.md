# App Store 截图

10 张，全部是 iPhone 6.9 英寸规格：**1320 × 2868 PNG**，来自 iPhone 18 Pro Max 模拟器实拍，
状态栏统一为 9:41 + 满电，数据由 `-seedDemo` 注入，不含任何真实用户信息。

## 上传位置

App Store Connect → App → 版本页 → 「App 预览和截屏」→ **iPhone 6.9 英寸显示屏**

一次最多 10 张，按 `01 → 10` 的顺序上传即可。iPad 未开启（`TARGETED_DEVICE_FAMILY = 1`），
所以不需要 13 英寸那一档；6.5 英寸规格现在是可选项，不传也能过审。

## 清单与建议文案

| 文件 | 画面 | 首行文案（若要加文字层） |
| --- | --- | --- |
| `01-login.png` | 首次进入：品牌、Apple 登录、本机档案表单 | Apple 登录 / 本机二选一，数据可存本机或自己的 iCloud |
| `02-today.png` | 今日：目标环、按等级推荐、复习队列、错题强化、30 天计划 | 打开就知道今天该练什么 |
| `03-drill.png` | 训练场：六类关卡 + 最近 7 天 + 进阶玩法 | 六个专项，从编码到提取 |
| `04-practice.png` | 方法练习 L1：概念配对四选一 | 九种题型，方法真的记住 |
| `05-quest-map.png` | 闯关地图：四个学龄段、关卡格、星数 | 45 关 135 星，按学龄分层 |
| `06-quest-game.png` | 小学高年级 · 排排队：步骤排序 + 计时 | 排排队：把步骤顺序练成直觉 |
| `07-report.png` | 学习报告：本周数据、14 天柱状、正确率趋势、类别强弱 | 每周看清自己在变强 |
| `08-curve.png` | 遗忘曲线：保持率、9 节点阶梯、到期分布 | 按遗忘曲线排期，不浪费一次复习 |
| `09-wrong.png` | 错题本：待强化 / 反复错 / 涉及方法 + 题目卡 | 错题自动入库，答对两次才出库 |
| `10-profile.png` | 我的：等级称号、记忆精度 Lv.1–5、数据、闯关进度 | 等级、精度、连续天数，一眼看清 |

`extra/unlock.png` 是设了 4 位进入密码后的解锁页，只作设计存档，不参与上传。

白天配色同款的一套在 `6.9-day/`（01–10 同序，`extra-day/unlock.png` 为解锁页），上传时任选一套，
或者深色放前 5 张、白天放后 5 张做对比投放。

PNG 体积较大（单张 0.6–3.9 MB，合计约 29 MB），所以没有入库，用下面的脚本随时重放出来。

## 重新生成

```bash
# 1. 编译 Debug 模拟器包
xcodebuild -project Mnemo.xcodeproj -scheme Mnemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build build

# 2. 生成截图（会自动建/复用模拟器、覆盖状态栏、清空数据后重放演示数据）
./Scripts/screenshots.sh                          # 深夜配色 → Docs/appstore/6.9
THEME=day ./Scripts/screenshots.sh "Mnemo 6.9" "$PWD/Docs/appstore/6.9-day"   # 白天配色
```

默认设备名 `Mnemo 6.9`（iPhone 18 Pro Max + iOS 27.0）。首次需要先建：

```bash
xcrun simctl create "Mnemo 6.9" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max \
  com.apple.CoreSimulator.SimRuntime.iOS-27-0
```

脚本里每张图用的启动参数（也是这套界面能被逐屏复现的原因）：

| 参数 | 作用 |
| --- | --- |
| `-seedDemo` | 注入 9 天训练记录、6 张复习卡、4 道错题、7 条闯关成绩 |
| `-skipLogin` | 跳过登录直接进主界面（仅 DEBUG） |
| `-loginName 林小满` | 登录页预填昵称 |
| `-cloudReady` | 假装 iCloud 可用（截图/联调用） |
| `-seedApple` | 造一个已绑定 Apple 的档案 |
| `-demoLocked` | 强制显示解锁页（密码 2468） |
| `-tab today\|drill\|library\|profile` | 指定 Tab |
| `-screen quest\|report\|curve\|wrong\|calendar\|goals\|rank` | 训练页内直达二级页 |
| `-game primaryHigh 0 1` | 直达某学龄段某关某档玩法 |
| `-night` / `-day` / `-autoTheme` | 指定启动配色（脚本里由 `THEME=night\|day` 注入） |
