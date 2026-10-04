# Headscale Manager

[![Android CI](https://github.com/CGG888/headscalemanager/actions/workflows/android.yml/badge.svg)](https://github.com/CGG888/headscalemanager/actions/workflows/android.yml)
[![Release](https://img.shields.io/github/v/release/CGG888/headscalemanager)](https://github.com/CGG888/headscalemanager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B?logo=flutter)](https://flutter.dev)

**中文** · [English](README.En.md) · [Français](README.fr.md)

**Headscale Manager** 是一个 **Headscale 服务端管理客户端**（Flutter 编写，可编译到 Android / iOS / Web / Windows / macOS / Linux）。
它直接调用 Headscale 的 REST API 来管理你的私有 Tailscale 控制面——用户、节点、路由、ACL/Grants、DNS、预认证密钥、Taildrive 等，全部可以在手机上完成。

![Headscale Manager](https://github.com/user-attachments/assets/c4026256-2474-4ded-bc26-67302d825d54)

> **完整的分步使用指南内置在应用里**（安装 Headscale 服务端、生成 API 密钥、配置反向代理，以及逐屏功能说明，共 8 章），入口是 **「设置 → 帮助」**，且**已完整中文化**。本文件只做快速上手与项目说明。

## 目录

- [界面语言](#界面语言)
- [下载与安装](#下载与安装)
- [快速上手](#快速上手)
- [功能一览](#功能一览)
- [常见问题](#常见问题)
- [从源码构建](#从源码构建)
- [签名与发布](#签名与发布)
- [说明与免责声明](#说明与免责声明)

## 界面语言

支持 **简体中文 / 英语 / 法语** 三种界面语言：

| 行为 | 说明 |
|---|---|
| 切换 | **「设置 → 语言」**，三选一 |
| 首次启动 | **跟随系统语言**：中文系统首次打开即为中文；系统语言不在支持范围内时回退法语 |
| 回退策略 | 未翻译的条目自动回退英文，不会出现空白或报错 |
| 桌面应用名 | 中文系统下显示为「Headscale 管理器」 |

## 下载与安装

| 方式 | 说明 |
|---|---|
| **GitHub Releases（推荐）** | 到 [Releases](https://github.com/CGG888/headscalemanager/releases) 下载最新版 `headscalemanager-vX.Y.Z.apk`，由 GitHub Actions 自动构建 |
| **自行构建** | 见 [从源码构建](#从源码构建) |

安装时需在手机上允许「安装未知来源应用」。

> 💡 官方发布的 APK 使用**固定签名密钥**，因此后续版本可以**直接覆盖升级**。
> 若你自己从源码构建且没有配置正式密钥，产出的 APK 是 debug 签名：能正常安装使用，但**无法覆盖**官方版（签名不同），需先卸载。

## 快速上手

1. 准备一台运行中的 **Headscale 服务端**（建议 0.26+；Grants V29 相关功能需要 0.29+）。
2. 在服务端生成一个 **API 密钥**（应用内帮助第 1.4 节有详细步骤）。
3. 打开应用 → **添加服务器** → 填入服务器地址（例如 `https://headscale.example.com`）与 API 密钥。
4. 之后即可在「仪表盘 / 用户 / 节点 / ACL / DNS」等页面管理你的网络。

## 功能一览

| 模块 | 能力 |
|---|---|
| **仪表盘** | 节点在线状态、用户与节点统计、OIDC 提醒、服务端版本与兼容性提示 |
| **用户** | 创建 / 删除 / 重命名、邮箱与备注、OIDC 用户识别、标签初始化 |
| **节点** | 详情与在线状态、重命名、移动归属用户、设备类型图标、标签编辑、路由与出口节点状态 |
| **ACL / Grants** | 策略编辑与导入导出、JSON 视图、权限差异对比、**Grants V29**（`via` 路由）编排器、可视化 ACL 关系图、**拼图式（Puzzle）**向导、旧版标签迁移与回滚 |
| **Taildrive / 共享** | 共享目录管理、共享路由与子网访问权限 |
| **DNS** | 自定义 DNS 名称、`extra_records` 说明 |
| **密钥** | 预认证密钥（含二维码）、API 密钥创建与过期时间 |
| **客户端命令库** | 常用 `tailscale` 命令，带参数配置、按平台/分类筛选、一键复制与分享 |
| **通知与后台监控** | 待审批请求、孤立路由清理、节点上下线变化的系统通知 |
| **安全** | 应用锁（PIN / 生物识别）、多服务器管理 |
| **更新日志** | 升级后展示本版本的新增与修复 |

## 常见问题

<details>
<summary><b>保存 ACL 策略报 500：<code>username must contain @,got:"xxx"</code></b></summary>

**原因**：Headscale 的策略解析器要求每个**用户引用必须含 `@`**（`alice@` = alice 名下的所有设备）。旧版本会把原始用户名直接写进 `groups` 成员，于是对**本地/CLI 创建的用户**（如 `lcmyhome`，没有邮箱）生成 `"groups": {"group:lcmyhome": ["lcmyhome"]}`，服务端解析即失败。

**解决**：**v2.2.3 已修复**（三处策略生成器统一输出 `用户名@`）。
若暂时无法升级，可在 **ACL → JSON 页签** 里把成员手动改成 `"lcmyhome@"` 再保存到服务器。
</details>

<details>
<summary><b>网络页提示「获取公网 IP 出错」</b></summary>

**原因**：旧版本只向单一第三方服务 `api.ipify.org` 查询公网 IP，该域名在部分网络（尤其中国大陆）常被 DNS 污染或拒绝连接；且失败还会**连带阻止路由追踪**运行。

**解决**：**v2.2.3 已修复**——改为多源依次尝试（每个 4 秒超时）、失败静默降级（标签显示 `—`），并且路由追踪不再依赖公网 IP。

> 该提示不影响节点列表、延迟、图表等主要功能。
</details>

<details>
<summary><b>安装报「解析失败，安装包没有签名文件」</b></summary>

**原因**：旧版本构建出的 APK 只带 v2/v3 签名、缺少 **v1（JAR）签名**，部分安装器（旧系统、定制 ROM、MDM 管控设备）只校验 v1。

**解决**：**v2.2.3 已修复**——CI 用 `apksigner` 显式重签并开启 v1 + v2 + v3，且以签名校验作为流水线闸门。

**另外**：如果手机上装过**其他签名密钥**的旧版本（其他渠道安装的版本或早期测试版），请**先卸载**再安装。
</details>

<details>
<summary><b>中文界面没生效 / 想改回其他语言</b></summary>

到 **「设置 → 语言」** 切换即可。首次启动跟随系统语言；系统语言不在支持范围内时回退法语（再回退英文）。
</details>

<details>
<summary><b>连不上服务器</b></summary>

按顺序检查：① 服务器地址是否可从当前网络访问（含端口/反向代理）；② 证书是否有效（自签名证书需要被信任）；③ API 密钥是否已过期。应用内帮助第 1 章有服务端配置的完整说明。
</details>

## 从源码构建

需要 **Flutter 3.47.6** 与 **JDK 17**（与 CI 保持一致）：

```bash
flutter pub get
flutter analyze          # 期望输出：No issues found!
flutter test             # 47 个测试
flutter build apk --release
```

仓库已内置 GitHub Actions 工作流：

| 工作流 | 触发 | 行为 |
|---|---|---|
| `.github/workflows/android.yml` | 每次 push / PR（也可手动触发） | 静态分析 + 单元测试 → 构建 APK → 校验签名 → 上传产物 |
| `.github/workflows/release.yml` | 推送 `v*` 形式的 tag（也可手动指定 tag） | 分析 + 测试 → 构建 APK → **重签为 v1+v2+v3 并校验** → 创建 GitHub Release 并附带 APK，版本说明取自仓库根目录的 `RELEASE_NOTES.md` |

## 签名与发布

正式签名通过在仓库 **Secrets** 中配置以下四项实现：

| Secret | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 密钥库文件（`.jks` / `.p12`）的 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库口令 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥口令 |

> ⚠️ **密钥库务必离线备份**。GitHub Secrets 是只写的、读不回来；密钥丢失后将**无法再为同一包名发布可覆盖升级的版本**。

未配置 Secrets 时，CI 会临时生成一把密钥并缓存（可构建，但缓存被清理时密钥会变化，届时用户需卸载重装）。

## 说明与免责声明

- 本项目是 Flutter 应用，按需可编译到 iOS、macOS、Web、Windows（当前自动化构建只覆盖 Android）。
- 代码可自由使用。
- **本项目目前未在 Google Play 或 App Store 上架**。请只从本仓库的 [Releases](https://github.com/CGG888/headscalemanager/releases) 获取安装包；其他渠道（包括应用商店中同名的付费版本）与本仓库无关，本仓库不对此负责。

### 原仓库说明（原文保留）

摘自原仓库 [hkdone/headscalemanager](https://github.com/hkdone/headscalemanager)：

> 作者已将应用免费发布在 Play 商店，不对他人在 App Store 发布的付费版本负责。

### 致谢

- 感谢 [hkdone/headscalemanager](https://github.com/hkdone/headscalemanager)——本项目的基础应用与使用文档来自该仓库。
- 感谢 [juanfont/headscale](https://github.com/juanfont/headscale)——本应用所管理的服务端。
