# Headscale Manager v2.4.0

本次是**运维效率**版本：保存 ACL 前先校验、一页看完所有异常、一次操作多个节点，并修掉了网络页"所有节点都显示离线"的问题。

## 新增 1：ACL 策略保存前校验 + 一键修复

- 保存前先调用服务端 `POST /api/v1/policy/check` 做权威校验，**把"保存后才报 500"变成"保存前明确报错"**；
- 同时做**离线本地检查**：组员不是含 `@` 的用户引用、组名缺少 `group:` 前缀、内容不是合法 JSON；
- 发现问题会列出**具体位置与取值**，并提供「**修复并保存**」——例如把 `"lcmyhome"` 自动改成 `"lcmyhome@"`（正是此前让 ACL 保存报 500 的那类问题）；
- 覆盖全部 14 处保存策略的代码路径；服务端不支持该端点时自动跳过，不影响旧版本服务器。

## 新增 2：网络体检（顶部盾牌图标）

一页聚合所有可发现的异常，每条都带对应操作：

| 检查项 | 操作 |
|---|---|
| 密钥**已过期**（严重）/ **30 天内到期** | 查看节点 |
| 长期离线（≥30 天） | 查看节点 |
| **申请但未批准的路由**（列出具体网段） | 查看节点 |
| **节点没有 IP 地址** | **一键补全**（`backfillips`） |
| **同一网段被多台节点批准**（路由冲突） | — |
| 策略不是合法 JSON / 组员缺少 `@` | 打开 ACL |
| **标签未在 `tagOwners` 声明** | — |
| 所有 DERP 中继不可达 | — |

## 新增 3：批量操作（顶部清单图标）

扁平可搜索的节点列表 + 多选，一次执行：

- **批准待批路由**（只会作用于真的有待批路由的节点）
- **过期密钥**（把设备踢下线，比删除安全：保留记录、需重新认证）
- **删除节点**

每个动作**先确认、执行中显示进度、结束给出汇总**，并**逐条列出失败原因**——批量操作最容易"做一半失败"，必须如实回报。

## 修复：网络页把所有节点显示成"离线"

原因：该页 ping 的是节点的 **Tailscale 内网地址（100.64.0.0/10）**，而本 App 是远程管理客户端，**手机不在 tailnet 内**，因此探测必然失败、所有节点都被画成红色离线。

现在：

- **状态以服务端上报的 `online` 为准**；
- **直接探测默认关闭**，改为显式开关，并说明"只有手机接入同一 tailnet 时才可达"；开启后未响应的节点显示「**本机不可达**」，而不是假装离线；
- 新增「**服务器延迟**」：本机到 Headscale 的往返延迟（`GET /version`），这是这台手机真能观测到的指标。

## 安装

> 💡 优先下载**按 CPU 架构拆分**的包：通用包约 69 MB，网络不佳时容易被截断，而**截断的 APK 会丢失文件末尾的签名块**，安装时报的正是「安装包没有签名文件」——与"签名缺失"症状完全相同。

| 文件 | 适用机型 |
|---|---|
| `headscalemanager-v2.4.0-arm64-v8a.apk` | **绝大多数现代手机（推荐）** |
| `headscalemanager-v2.4.0-armeabi-v7a.apk` | 较老 32 位设备 |
| `headscalemanager-v2.4.0-x86_64.apk` | 模拟器 / x86 平板 |
| `headscalemanager-v2.4.0.apk` | 通用包（约 69 MB） |

安装步骤：

1. 下载适合的一个，**安装前核对下载页显示的精确字节数**（明显偏小说明被截断，重新下载）；
2. 本版与 v2.3.0 **同一签名密钥**，可直接覆盖升级（若装的是 v2.2.2 及更早版本，需先卸载）；
3. 允许「安装未知来源应用」后安装。

> 本项目**未在 Google Play 或 App Store 上架**，请只从本仓库 Releases 获取。

## English summary

- **ACL policy is validated before saving** (server-side `policy/check` plus local checks) with one-click repair of user references missing "@", turning a save-time 500 into a pre-save message.
- **Network health page** (shield icon): expired/expiring keys, long-offline nodes, routes awaiting approval, nodes without IP (with one-click backfill), route conflicts, undeclared tags, policy problems, unreachable DERP relays - each with the matching action.
- **Batch operations page** (checklist icon): approve pending routes, expire keys or delete several nodes at once, with confirmation, progress and a per-node failure report.
- **Fixed the network view showing every node as offline**: it pinged tailnet addresses, which a remote admin client cannot reach. Status now comes from the server, direct probing is opt-in, and a server round-trip latency is shown instead.
- Includes the v2.3.0 work (DERP relays, key/network details, expiry flags) and the earlier fixes.
