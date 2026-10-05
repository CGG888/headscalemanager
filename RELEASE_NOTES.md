# Headscale Manager v2.3.0

本次新增**DERP 中继可视化**与**机器网络/密钥详情**，并修复三个此前报告的问题。

## 新增：DERP 中继面板（网络概览）

网络概览新增「DERP 中继」卡片：

- 列出服务器 DERP map 中的中继节点，显示**从本机测得的延迟**，并**高亮最快的一个**——这正是客户端挑选 home 中继所依据的信息；
- 单独标出**服务器内嵌 DERP**（Headscale 启用 `derp.server.enabled` 后才可用）；
- 测量方式与 Tailscale 的 netcheck 相同：先热身一次建立连接，再取 3 次往返的最小值。

**数据来源与边界**（重要）：

| 信息 | 能否获得 |
|---|---|
| 服务器使用的中继列表 + 本机到各中继的延迟 | ✅ 来自 Headscale 的 `/bootstrap-dns` 与 `/derp/probe`、`/derp/latency-check`（在鉴权之外，不需要 API 密钥） |
| **某台机器当前使用哪个中继** | ❌ **任何服务端都拿不到**：中继由客户端自己测速挑选，Headscale 既不接收也不存储（其 API 连 `host_info`、`endpoints` 都是 `reserved`） |

> 因此节点详情里给出了"在该设备上执行 `tailscale status`"的一键复制，而不是伪造数据。
> 若 `/bootstrap-dns` 不可达（未启用内嵌 DERP，或反向代理未放行 `/bootstrap-dns` 与 `/derp/*`），卡片会显示明确提示，不会报错。

## 新增：节点「密钥与网络」详情

节点详情新增一张卡片，展示 Headscale v1 API **一直提供、此前却被忽略**的字段：

- **密钥到期时间**：剩余天数提示，**临期（30 天内）橙色、已过期红色**；已过期时说明该节点将无法再连接；
- **注册时间**与**注册方式**（CLI / OIDC / 预认证密钥）；
- **子网路由**（`subnetRoutes`）；
- 标识符卡片补充 **节点密钥（nodeKey）** 与 **DISCO 密钥**。

> 细节：Headscale 用 Go 的零值时间 `0001-01-01T00:00:00Z` 表示"永不过期"，本版按此处理（与 Headplane 的判定一致）。

## 新增：机器列表的密钥临期标记

仪表盘的机器列表会为**密钥已过期**或**即将过期（30 天内）**的节点显示钥匙图标（过期红色、临期橙色），并在副标题给出"N 天后到期 / 已过期"的文字说明。密钥过期后节点会掉线，这是列表里少数值得主动提醒的信息。

## 修复（继承 v2.2.3）

1. **保存 ACL 策略报 500**（`username must contain @`）：服务器上存在本地（CLI 创建、无邮箱）用户时，策略中的用户引用现在会写成 Headscale 要求的「用户名@」形式。
2. **网络页「获取公网 IP 出错」**：改为多源 + 超时 + 静默降级，并且不再连带阻止路由追踪。
3. **安装报「解析失败，安装包没有签名文件」**：改用 v1(JAR)+v2+v3 三种签名，并加入构建期签名校验闸门。

## 安装

> 💡 **本版提供按 CPU 架构拆分的安装包**（内容相同）。通用包接近 70 MB，网络不佳时容易被下载截断——而**被截断的 APK 会丢失文件末尾的签名块**，安装时报的正是「解析失败，安装包没有签名文件」，和"签名漏做"的症状一模一样。所以请优先下载拆分包：

| 文件 | 适用机型 | 体积 |
|---|---|---|
| `headscalemanager-v2.3.0-arm64-v8a.apk` | **绝大多数现代手机（推荐）** | **30.4 MB**（31,916,865 字节） |
| `headscalemanager-v2.3.0-armeabi-v7a.apk` | 较老的 32 位设备 | **28.3 MB**（29,651,785 字节） |
| `headscalemanager-v2.3.0-x86_64.apk` | 模拟器 / x86 平板 | **31.9 MB**（33,399,605 字节） |
| `headscalemanager-v2.3.0.apk` | 通用包（不确定架构时用） | **69.3 MB**（72,672,671 字节） |

安装步骤：

1. 下载上表中最适合的一个；
2. **安装前核对文件大小**（下载页会显示精确字节数，明显偏小说明被截断，重新下载即可）；
3. **若装过 v2.2.2 及更早版本，请先卸载**（签名密钥已变更）；
4. 允许「安装未知来源应用」后安装。

> 本项目**未在 Google Play 或 App Store 上架**，请只从本仓库的 Releases 获取安装包。
> 发布的 APK 使用固定签名密钥（`CN=Headscale Manager`），可覆盖升级；每个包都经过
> v1(JAR) + v2 + v3 三重签名校验，签名不完整会直接让流水线失败。

## English summary

- **DERP relays panel** on the network overview: lists the relays from the server's DERP map with the latency measured from this device, highlights the fastest one, and flags the server's embedded relay. Measured the way Tailscale's netcheck does it (warm-up request, then best of three).
- **Node key/network details**: key expiry with an approaching/expired highlight, registration date and method, subnet routes, node key and DISCO key - all fields the v1 API already returned but the app ignored. Go's zero time is treated as "never expires".
- **Machine list**: expired or soon-to-expire node keys are flagged with a key icon and a "N days left / expired" line.
- Fixes carried over from v2.2.3: ACL policy save returning 500 (`username must contain @`), the public IP lookup error, and the missing v1 signature that some installers rejected.
- Note: the relay a *specific machine* uses cannot be obtained from any control server - it is chosen client-side, and Headscale neither receives nor stores it. The app measures latency from the phone instead and points to `tailscale status` for the per-machine answer.
