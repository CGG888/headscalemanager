# Headscale Manager — 中文使用指南

[![Android CI](https://github.com/CGG888/headscalemanager/actions/workflows/android.yml/badge.svg)](https://github.com/CGG888/headscalemanager/actions/workflows/android.yml)
[![Release](https://img.shields.io/github/v/release/CGG888/headscalemanager)](https://github.com/CGG888/headscalemanager/releases)

[Français](README.md) · [English](README.En.md) · **中文**

Headscale Manager 是一个 **Headscale 服务端管理客户端**（Flutter 编写，支持 Android / iOS / Web / Windows / macOS / Linux）。
它通过直接调用 Headscale 的 REST API 来管理你的私有 Tailscale 控制面：用户、节点、路由、ACL/Grants、DNS、预认证密钥、Taildrive 等，都可以在手机上完成。

> 完整的分步使用指南（安装 Headscale 服务端、生成 API 密钥、配置反向代理、逐屏功能说明）已内置在应用内：**「设置 → 帮助」**，且**已完整中文化**。本文件只做快速上手。

## 界面语言

支持 **法语 / 英语 / 简体中文** 三种界面语言：

- 在 **「设置 → 语言」** 中切换（应用名在桌面上会随系统语言显示为「Headscale 管理器」）。
- **首次启动跟随系统语言**：中文系统的手机第一次打开即为中文；系统语言不在支持范围内时回退法语。
- 未翻译的条目会自动回退英文，不会出现空白或报错。

## 下载与安装

| 方式 | 说明 |
|---|---|
| **GitHub Releases（推荐）** | 到 [Releases](https://github.com/CGG888/headscalemanager/releases) 下载最新版 `headscalemanager-vX.Y.Z.apk`，这是由 GitHub Actions 自动构建的产物 |
| **Play 商店** | https://play.google.com/store/apps/details?id=com.dkstudio.headscalemanager |
| **自行构建** | 见下方「构建」一节 |

安装时需要在手机上允许「安装未知来源应用」。

> ⚠️ 未配置正式签名密钥时，CI 产出的是 **debug 签名**的 release APK：可以正常安装使用，但若手机上已安装过用正式密钥签名（例如 Play 商店版）的同包名版本，需先卸载再安装。

## 快速上手

1. 你首先需要有一台运行中的 **Headscale 服务端**（版本建议 0.26+；Grants V29 相关功能需要 0.29+）。
2. 在服务端生成 API 密钥（详见应用内帮助的 1.4 节）。
3. 打开应用 → 添加服务器 → 填入服务器地址（例如 `https://headscale.example.com`）与 API 密钥。
4. 之后即可在「仪表盘 / 用户 / 节点 / ACL / DNS」等页面管理你的网络。

## 主要功能

- **仪表盘**：节点在线状态、用户与节点统计、OIDC 提醒、版本与兼容性提示。
- **用户与节点**：创建/删除/重命名用户与节点、移动节点归属、设备类型图标、用户备注、标签（tags）编辑。
- **ACL 与 Grants**：ACL 策略编辑与导入导出、JSON 视图、权限差异对比、**Grants V29**（`via` 路由）编排器、可视化 ACL 关系图、**ACL 拼图式（Puzzle）**向导、旧版标签迁移向导与回滚。
- **Taildrive / 共享**：共享目录管理、共享路由与子网访问权限。
- **DNS**：自定义 DNS 名称与 `extra_records` 说明。
- **密钥管理**：预认证密钥（含二维码）、API 密钥的创建与过期。
- **客户端命令库**：常用 `tailscale` 命令，带参数配置、按平台/分类筛选、一键复制与分享。
- **通知与后台监控**：审批请求、孤立路由清理、节点上下线变化的系统通知。
- **安全**：应用锁（PIN / 生物识别）、多服务器管理。

## 构建

需要 Flutter **3.47.6** 与 JDK 17（与 CI 保持一致）：

```bash
flutter pub get
flutter analyze          # 应为 0 问题
flutter test             # 43 个测试
flutter build apk --release
```

构建 Android 应用需要 JDK 17 与 Android SDK；仓库已包含 GitHub Actions 工作流：

- `.github/workflows/android.yml`：每次 push / PR 自动跑静态分析与测试，通过后构建 APK 并上传产物（也可在 Actions 页面手动触发）。
- `.github/workflows/release.yml`：推送 `v*` 形式的 tag 即自动构建 APK、创建 GitHub Release 并把 APK 作为附件上传（版本说明取自仓库根目录的 `RELEASE_NOTES.md`）。

想产出**正式签名**的 APK，在仓库 Secrets 中配置 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 即可；未配置时自动回退 debug 签名。

## 说明

本项目为 Flutter 应用，按需可编译到 iOS、macOS、Web、Windows（当前自动化构建只覆盖 Android）。
代码可自由使用。作者已将应用免费发布在 Play 商店，**不对他人在 App Store 发布的付费版本负责**。
