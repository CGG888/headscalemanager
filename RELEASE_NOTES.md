# Headscale Manager v2.6.0

本版补上**设备授权可见性**与**本地操作留痕**，并沉淀了 CI 抓到的测试约定。

## 新增：未授权设备（体检页「盾牌带感叹号」图标）

列出 **`authorized == false`** 的设备——那些**尚未被授权**的机器。

> **为什么不叫"待审批列表"**：Headscale 的审批接口（`AuthApprove/Reject`）用的是注册流程里的 `auth_id`，**没有任何接口能枚举待审批请求**，所以字面意义上的"待审批列表"做不出来。device API 的 `authorized` 字段能回答同一个问题：**哪些设备还没被授权**。

每行显示 **系统 / 客户端版本 / DERP 中继 / 归属用户**，可直接**过期密钥**、**删除**或进入节点详情。

- 逐节点查询 `GET /api/v1/device/{id}`，**按 6 个一组分批并发**，不会一次打出几十个请求；
- 若**全部查询失败**（服务端早于 0.29）→ 明确提示"该服务端不提供 device API"，而不是给一个空列表误导；
- 全部已授权时显示「**所有设备均已授权（已检查 N 台）**」——空页面绝不模棱两可。

## 新增：操作记录（体检页「时钟」图标）

Headscale **没有审计 API**，服务端不记录"谁在何时改了什么"，因此由 App 在**破坏性操作**时本地留痕：

| 记录内容 | 说明 |
|---|---|
| 批量**删除节点 / 过期密钥 / 批准路由** | 含节点清单与**成功/失败数**，"做了一半"也看得见 |
| **创建预认证密钥** | 用户、可复用/临时、有效期 |

- 最新在前，上限 **200 条**（超出丢弃最旧的）；本地存储不该无限增长；
- **记录失败被静默吞掉**，绝不阻断你正在做的操作；单条损坏不会带崩整份历史；
- 页面可**清空**（带确认），并如实说明：**记录仅在本机、随 App 卸载消失**，用于回溯而非合规审计。

## 工程改进

- `AGENTS.md` 新增约定：**时间相关的测试必须避开整天/整点边界**。v2.5.0 的首次发布就是被这类脆弱测试拦下的（`DateTime.now().add(Duration(days: 2))` 在毫秒差下会算成 1 天，档位从 `d3` 变 `d1`：本地绿、CI 红），不得不重打 tag。现在写明应加 12 小时偏移或注入时钟。
- `AGENTS.md` 同时修正了此前关于「每台机器的 OS / 客户端版本 / 端点 / DERP 中继拿不到」的**错误结论**：它们可从 **device API**（`GET /api/v1/device/{id}`，0.29 起）获得；不要仅凭 `node.proto`（其 `host_info`/`endpoints` 确为 reserved）就下"拿不到"的判断——消息定义在 `device.proto`、服务定义在 `headscale.proto`。

## 安装

> 💡 优先下载**按 CPU 架构拆分**的包。通用包约 70 MB，网络不佳易被截断，而**截断的 APK 会丢失文件末尾的签名块**，安装时报的正是「安装包没有签名文件」。

| 文件 | 适用机型 |
|---|---|
| `headscalemanager-v2.6.0-arm64-v8a.apk` | **绝大多数现代手机（推荐）** |
| `headscalemanager-v2.6.0-armeabi-v7a.apk` | 较老 32 位设备 |
| `headscalemanager-v2.6.0-x86_64.apk` | 模拟器 / x86 平板 |
| `headscalemanager-v2.6.0.apk` | 通用包 |

安装前**核对自己下载的字节数与下载页一致**；本版与 v2.5.0/v2.4.0 **同一签名密钥**，可直接覆盖升级（v2.2.2 及更早需先卸载）。

> 本项目**未在 Google Play 或 App Store 上架**，请只从本仓库 Releases 获取。

## English summary

- **Unauthorized devices page**: lists devices with `authorized = false` (with OS, client version, DERP relay), letting you expire their key or delete them. Headscale cannot enumerate pending approvals - its approve/reject calls take the registration `auth_id` - so this reports the same thing from the device API's `authorized` field. Lookups run six at a time, and an older server says so explicitly instead of showing an empty list.
- **Operation history**: destructive actions (batch delete / expire keys / approve routes, pre-auth key creation) are recorded locally with target, time and outcome, newest first, capped at 200 entries. Recording failures never block the operation, and the screen states that the log is device-local.
- **Engineering**: AGENTS.md now requires time-dependent tests to avoid whole-day boundaries (a flake that this very release cycle hit), and corrects the earlier wrong claim that per-node OS/client version/endpoints/DERP relay were unobtainable - they come from the device API.
