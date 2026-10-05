# Headscale Manager v2.7.1

修复「长按节点查看设备网络详情」在**没有 device API 的服务端**上显示原始 404 的问题。

## 你遇到的现象

```
加载设备的网络详情失败。状态码:404,响应:{"code":5,"message":"Not Found","details":[]}
```

**根因**：该服务端（通过其 `/swagger/v1/openapiv2.json` 逐条核对）**没有 `/api/v1/device/` 路由**。Headscale 对"路由不存在"与"对象不存在"返回的是**同一个** `{"code":5}`，所以只看状态码无法区分——旧版把两种可能当成"服务端不支持"来提示，措辞并不准确。

## 本版修复

App 现在会**先读服务端自己生成的 OpenAPI 文档**，判断 `/api/v1/device/` 是否在其接口面上（结果按服务器地址缓存，同一台服务器一次运行只探一次）：

| 情况 | 现在的行为 |
|---|---|
| 服务端**没有**该路由 | 长按弹窗**明确说明**"该服务端没有提供 device API"，并给出可行替代：**在该设备本机执行 `tailscale status`** 查看它使用的中继。「未授权设备」页直接提示不支持，**不再逐节点发注定 404 的请求**；节点详情中的设备卡片整块隐藏 |
| 文档读不到（如反代未放行 `/swagger/`） | 视为"未知"，仍然尝试请求，行为与之前一致，不阻断 |
| 路由**存在**但查不到该设备 | 提示"接口存在但未能返回该设备详情"，并说明服务端可能不认该标识，不再归咎于版本 |

## 受影响的三个功能（在无 device API 的服务端上不可用）

- 设备网络详情（系统 / 客户端版本 / **实际使用的 DERP 中继** / 各区域延迟 / 公网端点 / NAT 形态）
- 长按节点的设备详情弹窗
- 未授权设备页

> 这些信息依赖 `GET /api/v1/device/{id}`，旧版 Headscale 的 `Node` 接口里没有对应字段（`host_info`/`endpoints` 为 `reserved`）。**其余功能不受影响**：ACL 预检、网络体检、批量操作、僵尸清理、可达性审计、策略变更对比、告警设置、操作记录在旧服务端上照常工作（它们只用 `node`/`policy`/`user`/`preauthkey` 接口）。
>
> 另外，**DERP 中继卡片**（v2.3.0 起）不依赖 device API——它从**手机侧**探测服务端的公开 DERP 端点，只要服务端启用了内嵌 DERP 就可用。

## 安装

| 文件 | 适用机型 |
|---|---|
| `headscalemanager-v2.7.1-arm64-v8a.apk` | **绝大多数现代手机（推荐）** |
| `headscalemanager-v2.7.1-armeabi-v7a.apk` | 较老 32 位设备 |
| `headscalemanager-v2.7.1-x86_64.apk` | 模拟器 / x86 平板 |
| `headscalemanager-v2.7.1.apk` | 通用包（约 70 MB） |

> 💡 优先下**按架构拆分**的包；通用包较大，网络不佳时被截断会**丢失文件末尾的签名块**，安装时报「安装包没有签名文件」。安装前核对字节数与下载页一致。

本版与 v2.7.0/v2.6.0/v2.5.0/v2.4.0 **同一签名密钥**，可直接覆盖升级。

## English summary

- The device network details (OS, client version, DERP relay, per-region latency, endpoints, NAT) required `GET /api/v1/device/{id}`, which older Headscale servers do not expose; the failure surfaced as a raw `404 {"code":5}`, indistinguishable from a missing object.
- The app now reads the server's own OpenAPI document to decide whether that route exists (cached per server). Absent: it explains the situation and points to `tailscale status` on the device, the unauthorised-devices page stops issuing one doomed request per node, and the device card is hidden. Unreadable document: treated as unknown and the request is attempted as before.
- Everything else (ACL pre-check, network health, batch operations, zombie cleanup, reachability audit, policy comparison, alert settings, operation history) only uses node/policy/user/pre-auth endpoints and keeps working on older servers.
