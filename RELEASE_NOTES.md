# Headscale Manager v2.2.2

补丁版本，修复 **APK 安装失败**的问题。

## 修复：安装报「解析失败，安装包没有签名文件」

**现象**：安装 v2.2.1 的 APK 时，手机提示

```
解析失败，安装包没有签名文件
```

**原因**：此前构建出的 APK **只带 v2/v3 签名，没有 v1（JAR）签名**。

Android Gradle Plugin 在 `minSdk >= 24` 时默认只做 v2/v3 签名（这是新系统的标准做法），但**部分安装器只校验 v1**：

- 较旧的 Android 系统（API < 24）；
- 一些定制 ROM / 厂商安装器；
- 部分企业 MDM 管控设备。

在这些设备上，缺少 v1 会直接报「没有签名文件」。此前的 v2.2.0 / v2.2.1 都受此影响。

**修复**：

- 构建完成后，CI 用 `apksigner` **显式重签**并开启 v1 + v2 + v3 三种方案——不再依赖 Android Gradle Plugin 的签名默认行为（实测 AGP 在 `minSdk ≥ 24` 时，即便设置 `enableV1Signing = true` 仍不产出 v1）；
- CI 增加**签名闸门**：必须检测到 `META-INF/*.RSA`，且按 API 21 校验 v1 与 v2/v3 均通过，否则流水线失败——这类问题不会再悄悄发出去；
- CI 自己准备签名密钥：未配置 Secrets 时用 `keytool` 生成一把并缓存，使多次构建使用**同一把密钥**，可覆盖升级（此前每次构建密钥都不同，必然无法覆盖安装）。

**本版本的签名证书**：`CN=Headscale Manager CI, O=CGG888, C=CN`（证书 SHA-256 `4e4fc743…`）。

## 升级说明

- 直接安装本页附件即可。
- **如果之前装过本 App 的旧版本**（尤其是 Play 商店版或此前 CI 产出的版本），因为签名密钥不同，需要**先卸载旧版再安装**；之后同一密钥的版本之间可以直接覆盖升级。
- 若想使用固定且安全的正式签名，在仓库 Secrets 中配置 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 即可（README 有说明）。

## 本版本同时包含 v2.2.1 的两个修复

1. **保存 ACL 策略报 500**（`username must contain @`）：策略中的用户引用改为 Headscale 要求的 `用户名@` 形式。
2. **网络页「获取公网 IP 出错」**：改为多源 + 超时 + 静默降级，并且不再连带阻止路由追踪。

## English summary

- Fixes "package has no signature file" on install: the APK now carries a v1 (JAR) signature (`META-INF/CI.RSA`) plus v2/v3. CI re-signs with apksigner instead of relying on AGP, which does not emit v1 for minSdk >= 24 even when enableV1Signing is set.
- CI now verifies the signature after building (META-INF entry plus apksigner at API 21) and fails the run otherwise, and uses one keystore cached across runs so consecutive builds share a stable key.
- Also includes the two v2.2.1 fixes (ACL policy 500, public IP lookup).
- If an older build of this app is installed (Play Store or a previous CI build), uninstall it once before installing this one - the signing keys differ.
