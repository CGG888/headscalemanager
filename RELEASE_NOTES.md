# Headscale Manager v2.2.0

本次发布的核心是**完整的中文本地化**，以及配套的自动化构建与发布链路。

## 新增：中文支持（简体）

- **界面三语**：法语 / 英语 / **中文**，在「设置 → 语言」中切换（原先是 fr↔en 的二元开关）。
- **未设置时跟随系统语言**：中文系统的手机第一次打开就是中文界面；系统语言不在支持范围内时回退法语。
- **应用内文案全量中文化**：约 1,050 处界面文案 + 帮助页整页（8 章使用指南），并覆盖 API 报错信息、通知渠道名称与后台任务提示。
- **桌面应用名**：中文系统下显示为「Headscale 管理器」。
- 术语统一：节点 / 用户 / 路由 / 出口节点 / 子网 / 预认证密钥 / ACL / 标签；`Headscale`、`Tailscale`、`Taildrive`、`DERP`、`ACL` 等专有名词保留原名。

## 改进

- **中文本地化不再是"半截"**：切到中文后不会再出现法语残留（例如原先 API 报错会是「加载节点失败：Échec de charger les nœuds…」这种中法混排）。
- **帮助页由两份硬编码页面合并为一份**（法语/英语两份各约 800 行，已出现内容漂移），现在由同一份内容渲染三语。
- 顺手修掉若干历史缺陷：
  - 英文界面下命令分类的配色与图标全部退化为默认值（判断逻辑误用本地化后的分类名）；
  - 帮助页重复的小节编号（两个 `3.6.`）与法语笔误 `Vue d'overview`；
  - 一处 `flutter analyze` 警告（后台任务回调里多余的 `Future.value`）。

## 工程

- **新增 GitHub Actions**：每次提交自动跑 `flutter analyze` + 43 个单元测试；通过后构建 Android APK 并上传产物。
- **新增发行版自动发布**：打 `v*` tag 即自动构建 APK 并创建 Release（本页附件中的 APK 即由 CI 产出）。
- **release 构建不再强制要求密钥库**：没有 `key.jks` 时回退 debug 签名，新克隆的仓库也能直接构建、安装。

## 安装（Android）

1. 下载本页附件中的 `headscalemanager-v2.2.0.apk`。
2. 在手机上允许「安装未知来源应用」后安装。
3. 首次启动填写你的 Headscale 服务器地址与 API 密钥即可。

> 说明：未配置正式签名密钥时，CI 产出的是 **debug 签名**的 release APK——可以正常安装使用，但若手机上已安装过用正式密钥签名（例如 Play 商店版）的同包名版本，需先卸载再安装。
>
> Play 商店版本：https://play.google.com/store/apps/details?id=com.dkstudio.headscalemanager

## English summary

- Full Simplified Chinese localization: three-language UI (fr / en / zh), follows the system language on first launch, ~1,050 UI strings plus the whole in-app help page, API error messages and notification texts.
- Android app name in Chinese: "Headscale 管理器".
- New GitHub Actions pipeline: analyze + 43 tests on every push, then builds and uploads the Android APK; pushing a `v*` tag publishes a release with the APK attached.
- Release builds no longer require a keystore (falls back to debug signing).
