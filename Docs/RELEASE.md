# 发布到 TestFlight

工程侧已经准备好：图标去掉了 alpha 通道（App Store 会拒收带透明通道的图标）、
`ITSAppUsesNonExemptEncryption = NO` 已写入（免去每次上传填出口合规）、
`Scripts/ExportOptions.plist` 与 `Scripts/release.sh` 已就位。

剩下的是账号侧四步，只能由账号持有人完成（涉及 Apple ID 双重认证，命令行无法代劳）：

## 1. 加入 Apple Developer Program

https://developer.apple.com/programs/ —— 个人账号 99 美元/年，审核通常几小时到两天。

## 2. 注册 Bundle ID

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → 新建：

- Bundle ID：`com.tal.mnemo`（必须与工程一致，想换就同时改 `project.pbxproj` 里的 `PRODUCT_BUNDLE_IDENTIFIER`）
- Capabilities（**v9 起必开这两项**，否则 Apple 登录按钮会报错、iCloud 状态一直不可用）：
  - **Sign in with Apple**（勾上后 App ID 变成 Primary App ID）
  - **iCloud → 勾选 Key-value storage**（本 App 只用一个 KV 容器，不需要 CloudKit）
- 改完 capability 要**重新生成 Provisioning Profile**，或让 `release.sh` 的 `-allowProvisioningUpdates` 自动拉一次

## 3. 创建 App 记录

App Store Connect → App → 新建 App：

| 字段 | 值 |
| --- | --- |
| 平台 | iOS |
| 名称 | 忆境（或 Mnemo，名称全局唯一，冲突就换） |
| 主要语言 | 简体中文 |
| Bundle ID | com.tal.mnemo |
| SKU | 随意，如 `mnemo-001` |

TestFlight 阶段不要求截图和隐私政策，但"App 隐私"问卷必须填一次：

- 身份：可以勾「通过 Apple 登录」——我们只在本机保存 Apple 返回的用户标识与转发邮箱，**不上传服务器**，不构成"收集"。
- 其余全部「不收集」：训练数据只写入本机的 `Documents/mnemo_state.json`，或用户自己 Apple 账号下的 iCloud KV 空间。
- 提交时若被问到用途说明，可直接写：Apple 登录仅用于建立本地训练档案；iCloud 仅用于用户自己跨设备同步。

## 4. 生成 App Store Connect API Key

App Store Connect → 用户和访问 → 集成 → App Store Connect API → 团队密钥 → 生成：

- 角色：**App 经理**（App Manager）
- 记下 **Issuer ID** 和 **Key ID**，下载 `AuthKey_XXXXXXXXXX.p8`（只能下一次）
- 放到 `~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8`

## 5. 一条命令上传

```bash
TEAM_ID=你的团队ID \
ASC_KEY_ID=你的KeyID \
ASC_ISSUER_ID=你的IssuerID \
./Scripts/release.sh --bump
```

团队 ID 在 App Store Connect → Membership 页面（10 位，形如 `A1B2C3D4E5`）。

脚本做三件事：`xcodebuild archive` 归档 Release → `-exportArchive` 导出 ipa（自动签名，
`-allowProvisioningUpdates` 会自己拉证书）→ `altool --upload-app` 上传。

上传后 5–15 分钟处理完成，App Store Connect → TestFlight 里出现新构建，
填「测试信息」并把内部测试员加进来即可开始装。

## 常见报错

| 报错 | 原因 |
| --- | --- |
| `No profiles for 'com.tal.mnemo' were found` | Bundle ID 没在开发者后台注册，或 TEAM_ID 填错 |
| `Invalid Image - alpha channel` | 图标带透明通道，本仓库已处理 |
| `Missing required icon` | `Assets.xcassets/AppIcon.appiconset` 缺 1024 图 |
| `The provided entity includes an attribute with a value that has already been used` | 同一个 build 号传过两次，用 `--bump` |
| `Redundant Binary Upload` | 同上 |

## 只归档不发布

```bash
TEAM_ID=xxx ./Scripts/release.sh --archive-only
# 产物：build/Mnemo.xcarchive
```
