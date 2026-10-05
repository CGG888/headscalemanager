# Headscale Manager v2.5.0

本版把 App 从"能管理"推向"能运维"：**每台设备的真实网络状态（含 DERP 中继）**、一页体检、批量操作、ACL 风险审计、接入向导、多服务器总览。

## 新增：设备网络详情（含 DERP 中继）

节点页面新增「设备网络详情」，数据来自 **device API**（`GET /api/v1/device/{id}`）——v1 的 `Node` 里没有这些字段：

| 字段 | 说明 |
|---|---|
| `os` / `clientVersion` | 操作系统与 Tailscale 客户端版本（有更新会标注） |
| **`client_connectivity.derp`** | **该设备当前实际使用的 DERP 中继** |
| `latency` | **客户端自己测得的各区域延迟**（按快慢排序，首选区域标 `*`） |
| `endpoints` | 公网端点 |
| `mappingVariesByDestIp` | NAT 形态（映射随目标变化 → 可能为对称型 NAT） |
| `authorized` / `keyExpiryDisabled` / `blocksIncomingConnections` / `isExternal` | 授权与防护状态标签 |

> 老服务端没有该接口（404）或请求失败时，**整块隐藏**，不影响页面其它内容。

## 新增：网络体检（顶部盾牌图标）

一页聚合所有可发现的异常，每条带对应操作：密钥已过期 / 30 天内到期、**长期离线节点（聚合成一条，可一键带去批量清理）**、待批路由、无 IP 节点（**一键补全**）、路由冲突、策略问题、标签未在 `tagOwners` 声明、DERP 全不可达。

## 新增：批量操作（顶部清单图标）

可搜索的多选列表，批量**批准路由 / 过期密钥 / 删除节点**；每个动作先确认、显示进度、结束给出**成功/失败清单**。删除或过期仍在共享路由/出口节点的机器时**红字警告**。

## 新增：ACL 可达性 + 风险审计（体检页「眼睛」图标）

把策略折算成"谁能访问谁（含端口）"，并标出风险：全通规则（critical）、互联网出口/SSH 对所有人开放、放行 `0.0.0.0/0`、通配目标、策略无规则。同时支持经典 `acls` 与 v0.29 `grants`。

## 新增：接入向导 / 多服务器总览 / 规则化告警

- **接入向导**（预认证密钥页二维码图标）：选用户与属性 → 生成密钥 → **大二维码（内容即命令）** + `tailscale up --login-server=… --authkey=…`，可复制。
- **多服务器总览**（顶部服务器图标）：并行拉取所有服务器，按问题数排序，显示节点/在线数与四类问题标记，点一下切换。
- **规则化告警**：密钥到期按 **30/7/3/1 天各提醒一次**（跨档才再提醒，不重复骚扰），与既有的待审批、孤立路由、监护节点状态通知并列。

## 修复与改进

- **ACL 保存前预检**：服务端 `policy/check` + 离线检查，**缺 `@` 可一键修复**（此前表现为保存后 500）。
- **网络页不再把所有节点显示成离线**：状态以服务端 `online` 为准；节点直连探测改为**可选开关**（手机不在 tailnet 时无意义）；新增**服务器往返延迟**。
- 节点详情补充**密钥到期**（临期橙/过期红）、注册时间与方式、子网路由、节点密钥与 DISCO 密钥；机器列表标记密钥临期/过期。

## 安装

> 💡 优先下载**按 CPU 架构拆分**的包。通用包约 70 MB，网络不佳易被截断，而**截断的 APK 会丢失文件末尾的签名块**，安装时报的正是「安装包没有签名文件」。

| 文件 | 适用机型 |
|---|---|
| `headscalemanager-v2.5.0-arm64-v8a.apk` | **绝大多数现代手机（推荐）** |
| `headscalemanager-v2.5.0-armeabi-v7a.apk` | 较老 32 位设备 |
| `headscalemanager-v2.5.0-x86_64.apk` | 模拟器 / x86 平板 |
| `headscalemanager-v2.5.0.apk` | 通用包 |

安装前**核对自己下载的字节数与下载页一致**；本版与 v2.4.0 **同一签名密钥**，可直接覆盖升级（v2.2.2 及更早需先卸载）。

> 本项目**未在 Google Play 或 App Store 上架**，请只从本仓库 Releases 获取。

## English summary

- **Per-device network details** from the device API: OS, client version, the DERP relay actually in use, the client's own latency measurements per region, public endpoints, NAT shape, authorization and protection flags (hidden automatically on servers without the endpoint).
- **Network health page** aggregating every detectable anomaly with the matching action, including grouped cleanup of long-offline nodes.
- **Batch operations** (approve routes / expire keys / delete nodes) with per-node results and a safety warning for nodes still serving routes.
- **ACL visibility and risk audit**, **add-a-device wizard** (QR + command), **multi-server overview**, and **tiered key-expiry reminders** (30/7/3/1 days, no repeats).
- Fixes: ACL policy is validated before saving with one-click repair; the network view no longer reports every node as offline; server round-trip latency added.
