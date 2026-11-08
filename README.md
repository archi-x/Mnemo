# 忆境 Mnemo

把 Obsidian 里的《记忆法全景手册》变成一个每天真的练一次的原生 iOS App。

- 40 个记忆法知识库（自动从手册 + 儿童版抽取）
- 四大专项训练：词表闪记 / 数字桩 / 记忆宫殿 / 方法练习
- **每法三阶多题型练习**：概念配对、步骤定位、材料适配、流程排除、应用编码（L1→L3）
- **错题本 + 强化训练**：答错自动入库，重做答对两次出库，反复错的题优先
- **学习日历**：按月展示每日训练强度，点开看当日明细
- **艾宾浩斯遗忘曲线**：保持率估算 + 9 节点复习阶梯 + SM-2 间隔重复排期
- 30 天训练计划、连续打卡、记忆精度 Lv.1–5、徽章

## 打开与运行

```bash
open Mnemo.xcodeproj        # Xcode 27，选 iPhone 模拟器直接 Cmd+R
```

命令行构建（本机环境需要，见下）：

```bash
xcodebuild -project Mnemo.xcodeproj -scheme Mnemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build build
```

安装到模拟器：

```bash
xcrun simctl boot "iPhone 18 Pro"
xcrun simctl install "iPhone 18 Pro" build/Build/Products/Debug-iphonesimulator/Mnemo.app
xcrun simctl launch "iPhone 18 Pro" com.tal.mnemo
```

## 目录

```
Mnemo/
├── Mnemo.xcodeproj
├── Mnemo/
│   ├── MnemoApp.swift          入口
│   ├── Design/Theme.swift      视觉语言（颜色/卡片/触感）
│   ├── Models/
│   │   ├── Models.swift        方法/复习卡/统计/精度等级
│   │   └── Practice.swift      题型/错题/每日统计/复习阶梯
│   ├── Data/
│   │   ├── AppStore.swift      状态与持久化、SM-2、出词
│   │   └── AppStore+Practice.swift  出题引擎、错题结算、保持率
│   ├── Views/                  四 Tab + 关卡 + 练习/错题/日历/曲线
│   ├── Components/             进度环/按钮/胶囊等通用件
│   ├── Resources/
│   │   ├── methods.json        40 法知识库（Scripts/extract.py 生成）
│   │   └── words.json          训练词库 110 词
│   └── Assets.xcassets         App 图标
├── Scripts/extract.py          文档 → JSON 抽取脚本（可重复运行）
└── Docs/
    ├── 记忆训练文档整理报告.md   文档整理结果
    ├── DESIGN.md               UI 与交互设计（含 v2 新功能）
    └── screenshots/            各页面截图
```

## 演示模式

模拟器里想直接看到有数据的界面：

```bash
xcrun simctl launch "iPhone 18 Pro" com.tal.mnemo -seedDemo
```

会注入 9 天训练记录、6 张复习卡和 4 道错题（仅首次生效，重装可再来）。

## 更新内容

改完 Obsidian 文档后重新抽取即可：

```bash
python3 Scripts/extract.py
```
