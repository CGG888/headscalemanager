# Headscale Manager v2.7.0

本版把**告警交给用户配置**，并补上**变更对比**与**查看设备网络详情**的便捷入口。

## 新增：告警可配置（体检页「滑块」图标）

| 设置项 | 作用 |
|---|---|
| **密钥到期提醒** 开关 + **提前多少天**（1–90） | 档位**由提前量推导**：设成 7 天时只保留 7/3/1 档，三周后到期的密钥**不再提醒**（不是只改标签） |
| **节点上下线变化** 开关 | 针对你监护的节点 |
| **待批准路由** 开关 | 节点申请新路由时提醒 |
| **离线多少天算可清理**（3–365） | 网络体检页据此聚合"长期离线"并可一键带去批量清理 |

数值在写入与读取时都会**收敛到合法范围**，读取失败回落默认值（不会因为设置损坏而丢掉功能）。

## 新增：策略变更对比（体检页「旗子」图标）

Headscale 只保留**当前**策略、没有历史，所以基线保存在本机：页面比较**当前策略 vs 基线**，列出**新增 / 删除 / 修改**的规则与组（`acls[]`、`groups.devops`、`tagOwners.server`…）。

- **键顺序不同不算变更**（键排序后再比较）；
- 超长规则自动截断，保证列表可读；
- 页面明确标注基线时间，并说明它是"你上次点『设为基线』的时刻"——**不是**服务端历史，避免误解。

## 新增：长按节点查看设备网络详情

仪表盘上**长按任意节点**，直接显示该设备的：**系统、客户端版本（含更新标记）、授权状态、实际使用的 DERP 中继、首选与最快区域（含最快延迟）、公网端点、NAT 形态**。

> 为什么不做成列表常显：几十个节点的网络会在列表渲染时打出几十个请求，而这些信息多数时候没人看。所以做成**按需一次请求**；老服务端不支持时明确提示，而不是弹空框。

## 新增：操作记录可导出

操作记录页新增「**复制全部**」：导出为纯文本（时间 / 结果 / 动作 / 对象 / 详情），方便贴进工单或聊天留档。

## 安装

> 💡 优先下载**按 CPU 架构拆分**的包。通用包约 70 MB，网络不佳易被截断，而**截断的 APK 会丢失文件末尾的签名块**，安装时报的正是「安装包没有签名文件」。

| 文件 | 适用机型 |
|---|---|
| `headscalemanager-v2.7.0-arm64-v8a.apk` | **绝大多数现代手机（推荐）** |
| `headscalemanager-v2.7.0-armeabi-v7a.apk` | 较老 32 位设备 |
| `headscalemanager-v2.7.0-x86_64.apk` | 模拟器 / x86 平板 |
| `headscalemanager-v2.7.0.apk` | 通用包 |

安装前**核对自己下载的字节数与下载页一致**；本版与 v2.4.0/v2.5.0/v2.6.0 **同一签名密钥**，可直接覆盖升级（v2.2.2 及更早需先卸载）。

> 本项目**未在 Google Play 或 App Store 上架**，请只从本仓库 Releases 获取。

## English summary

- **Configurable alerts**: choose which notifications fire (key expiry, monitored node status, pending routes), the lead time before key expiry (warning steps are derived from it, so shortening it genuinely silences distant keys) and how many days offline make a node a cleanup candidate. Values are clamped on read and write.
- **Policy change comparison**: the current ACL policy against a baseline kept on the device, listing added/removed/changed rules and groups. Key order is normalized so reordering is not reported as a change, and the page states that the baseline is a local snapshot, not server history.
- **Long-press a node** for its OS, client version, DERP relay, preferred/fastest region with latency, public endpoints and NAT shape - on demand, so a large tailnet is not queried on every list render.
- **Operation history export**: copy the whole local log as plain text.
