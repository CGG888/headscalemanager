# Headscale Manager v2.2.3

**本版本是第一个使用固定正式签名密钥发布的版本**，从此可以正常覆盖升级。功能内容与 v2.2.2 相同（含下述修复）。

> ⚠️ 若你安装过 **v2.2.2 或更早**的测试版，请**先卸载再安装**本版——签名密钥已经变化。装上本版之后，后续版本即可直接覆盖升级。

## 签名与发布方式

- CI 使用仓库 Secrets 中配置的**固定密钥**签名（证书 `CN=Headscale Manager, O=CGG888, C=CN`，有效期至 2054 年）；
- 构建后由 `apksigner` 显式重签，开启 **v1(JAR) + v2 + v3** 三种签名方案，并以「APK 内存在 `META-INF/*.RSA`」+「按 API 21 校验通过」作为流水线闸门；
- 这样同时解决了两个问题：**「安装包没有签名文件」**，以及**每次构建密钥都不同导致无法覆盖升级**。

## 修复 1：保存 ACL 策略报 500（`username must contain @`）

**现象**：

```
保存ACL策略失败。状态码:500,响应:{"code":2,"message":"setting policy: parsing policy:
... json: cannot unmarshal JSON object into Go v2.Group within \"/groups\":
username must contain @,got:\"lcmyhome\""}
```

**原因**：Headscale 的策略解析器要求**用户引用必须含 `@`**（`alice@` 表示「alice 名下的所有设备」）。而策略生成器把**原始用户名**直接写进了 `groups` 成员，于是对**本地/CLI 创建的用户**（如 `lcmyhome`，没有邮箱）会生成 `"groups": {"group:lcmyhome": ["lcmyhome"]}`——服务端解析即失败。只有当服务器上存在这类不含 `@` 的用户时才会触发。

**修复**：三处策略生成器（Grants V29 / Standard / Legacy 引擎）统一输出合法引用——名字已含 `@` 时原样保留，否则补 `@`；并补上了此前缺失的测试覆盖（仓库原有测试用例的用户名清一色是邮箱形态，恰好都含 `@`，把这个 bug 挡住了）。

## 修复 2：网络页「获取公网 IP 出错」

**现象**：

```
获取公网 IP 出错: ClientException with SocketException: Connection refused ...,
address=api.ipify.org, port=43318
```

**原因**：只向单一第三方服务 `api.ipify.org` 查询（该域名在部分网络常被 DNS 污染或拒绝连接）。更实质的是代码本身的三处缺陷：**没有超时**、把**可选信息**当致命错误弹红框、以及 **`_startTraceRoute()` 被写在"公网 IP 成功"分支里**——公网 IP 取不到时，路由追踪**永远不会运行**。

**修复**：多源（`api.ipify.org` → `api64.ipify.org` → `icanhazip.com` → `ifconfig.me/ip`）+ 每源 4 秒超时 + 失败静默降级（标签显示 `—`）；路由追踪**立即执行**，不再等待公网 IP。

## 修复 3：安装报「解析失败，安装包没有签名文件」

**原因**：此前构建出的 APK **只带 v2/v3 签名，没有 v1（JAR）签名**。AGP 在 `minSdk ≥ 24` 时默认只做 v2/v3，而部分安装器（旧系统、定制 ROM、MDM）只校验 v1。

**修复**：不再依赖 AGP 的签名行为——CI 用 `apksigner` 显式重签并开启 v1+v2+v3；CI 增加签名闸门（缺 v1 直接失败）；CI 使用固定密钥（本版本起改用仓库 Secrets 中的正式密钥）。

## 安装

1. 下载本页附件 `headscalemanager-v2.2.3.apk`；
2. **若装过 v2.2.2 及更早版本，请先卸载**；
3. 允许「安装未知来源应用」后安装；
4. 首次启动填写 Headscale 服务器地址与 API 密钥。

Play 商店版本：https://play.google.com/store/apps/details?id=com.dkstudio.headscalemanager

## English summary

- v2.2.3 is the first release signed with a permanent key (`CN=Headscale Manager, O=CGG888, C=CN`), so future versions install over it. **Uninstall v2.2.2 or earlier first**, since the signing key changed.
- CI signs with that key from the repository secrets and re-signs with apksigner enabling v1(JAR) + v2 + v3; the pipeline fails unless a `META-INF/*.RSA` entry exists and verification at API 21 passes. This fixes both "package has no signature file" on install and the previously per-run key that made upgrades impossible.
- Fixes saving an ACL policy on servers with local (non-OIDC) users (HTTP 500, `username must contain @`) by emitting `name@` user references.
- Fixes the network screen's public IP error: several sources with a timeout, graceful degradation, and the traceroute no longer blocked by it.
