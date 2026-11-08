# 忆境 Mnemo

[![Build](https://github.com/archi-x/Mnemo/actions/workflows/build.yml/badge.svg)](https://github.com/archi-x/Mnemo/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/iOS-18.0%2B-blue)

把 Obsidian 里的《记忆法全景手册》变成一个每天真的练一次的原生 iOS App。

- 40 个记忆法知识库（自动从手册 + 儿童版抽取）
- 四大专项训练：词表闪记 / 数字桩 / 记忆宫殿 / 方法练习
- **九种题型 · 三阶练习**：概念配对、方法归类、步骤定位、原理溯源、材料适配、流程排除、步骤衔接、案例归属、应用编码（L1→L3）
- **学员等级 XP 体系**：答题得经验、升级换称号，题型推荐随等级自适应
- **智能推荐**：错题优先 → 到期复习 → 薄弱补练 → 冲星 → 开新法，按优先级排好
- **错题本 + 强化训练**：答错自动入库，重做答对两次出库，反复错的题优先
- **分学龄段闯关**：小学低年级翻翻配对 / 小学高年级排排队 / 初中限时抢答 / 高中编码工坊，45 关 × 三档，拿星解锁
- **目标计划**：每日/每周训练量、连续打卡、收星、正确率六类目标，可增删
- **学习报告**：本周 vs 上周、14 天训练量、正确率趋势、类别强弱、该补的方法
- **同级别排名**：离线模拟的同级参照榜（不上传任何数据）
- **学习日历**：按月展示每日训练强度，点开看当日明细
- **艾宾浩斯遗忘曲线**：保持率估算 + 9 节点复习阶梯 + SM-2 间隔重复排期
- 30 天训练计划、连续打卡、记忆精度 Lv.1–5、徽章

## 界面

| 今日 | 训练场 | 方法库 | 我的 |
| --- | --- | --- | --- |
| ![](Docs/screenshots/today.png) | ![](Docs/screenshots/drill.png) | ![](Docs/screenshots/library.png) | ![](Docs/screenshots/profile.png) |

| 方法练习 | 错题强化 | 学习日历 | 遗忘曲线 |
| --- | --- | --- | --- |
| ![](Docs/screenshots/quiz.png) | ![](Docs/screenshots/wrongbook.png) | ![](Docs/screenshots/calendar.png) | ![](Docs/screenshots/curve.png) |

| 目标计划 | 学习报告 | 同级别排名 | 闯关结算 |
| --- | --- | --- | --- |
| ![](Docs/screenshots/goals.png) | ![](Docs/screenshots/report.png) | ![](Docs/screenshots/rank.png) | ![](Docs/screenshots/quest_result.png) |

### 闯关：四个学龄段四套玩法

| 闯关地图 | 小学低年级 · 翻翻配对 | 小学高年级 · 排排队 | 初中 · 限时抢答 | 高中 · 编码工坊 |
| --- | --- | --- | --- | --- |
| ![](Docs/screenshots/quest_hub.png) | ![](Docs/screenshots/quest_flip.png) | ![](Docs/screenshots/quest_order.png) | ![](Docs/screenshots/quest_rush.png) | ![](Docs/screenshots/quest_lab.png) |

## 打开与运行

```bash
open Mnemo.xcodeproj        # Xcode 27，选 iPhone 模拟器直接 Cmd+R
```

命令行构建：

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

## 许可

MIT，见 [LICENSE](LICENSE)。
