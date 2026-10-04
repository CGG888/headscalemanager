# Headscale Manager v2.2.1

补丁版本，修复两个问题（均为历史缺陷）。

## 修复 1：保存 ACL 策略报 500（`username must contain @`）

**现象**：在已连接的 Headscale 上保存 ACL 策略时失败：

```
保存ACL策略失败。状态码:500,响应:{"code":2,"message":"setting policy: parsing policy:
parsing policy from bytes: json: cannot unmarshal JSON object into Go v2.Group
within \"/groups\": username must contain @,got:\"lcmyhome\""}
```

**原因**：Headscale 的策略解析器要求**用户引用必须含 `@`**（`alice@` 表示「alice 名下的所有设备」）。
而策略生成器把**原始用户名**直接写进了 `groups` 成员，于是对**本地/CLI 创建的用户**（例如 `lcmyhome`，没有邮箱）会生成
`"groups": {"group:lcmyhome": ["lcmyhome"]}` —— 服务端解析即失败。

只有当服务器上**存在这类不含 `@` 的用户**时才会触发，因此仅用 OIDC（用户名本身就是邮箱）的服务器不会遇到。

**修复**：三处策略生成器（Grants V29 / Standard / Legacy 引擎）统一改为输出合法引用——名字已含 `@` 时原样保留，否则补 `@`。
同时补上了此前缺失的测试覆盖：仓库里原有测试用例的用户名清一色是邮箱形态，恰好都含 `@`，把这个 bug 挡住了。

## 修复 2：网络页面「获取公网 IP 出错」并连带拖住路由追踪

**现象**：网络概览页弹出红色提示

```
获取公网 IP 出错: ClientException with SocketException: Connection refused …,
address=api.ipify.org, port=43318, uri=https://api.ipify.org?format=json
```

**原因**：应用只向单一第三方服务 `api.ipify.org` 查询公网 IP。该域名在部分网络（尤其中国大陆）常被 DNS 污染或直接拒绝连接，于是必然失败。
报错里的 `port=43318` 不是 443，而是 Dart 在连接被拒时打印的本地临时端口，容易误读。

更要紧的是**这段代码本身有三处缺陷**：

1. **没有超时**：`http.get` 未设超时，在网络不通时会挂起很久；
2. **把可选信息当作致命错误**：公网 IP 只是拓扑图上一个标签，失败却弹红色报错；
3. **连累另一个功能**：`_startTraceRoute()` 被写在"公网 IP 成功"的分支里 —— **公网 IP 取不到时，路由追踪（traceroute）永远不会运行**，尽管两者毫无依赖。

**修复**：

- 改为**依次尝试多个源**（`api.ipify.org` → `api64.ipify.org` → `icanhazip.com` → `ifconfig.me/ip`），每个 4 秒超时，任一成功即用，兼容 JSON 与纯文本两种返回；
- **解开耦合**：路由追踪立即开始，不再等待公网 IP；
- 取不到时**不再弹错误**，标签显示 `—`（加载中仍是 `…`）。

## 升级说明

- 直接从本页附件安装即可覆盖升级（与 v2.2.0 同一签名）。
- 若暂时不想升级，可在 **ACL → JSON 页签** 里把成员手动改成 `"lcmyhome@"` 后再保存到服务器。
- 保存失败发生在解析阶段，服务器上的策略**没有被修改**，无需回滚。

## English summary

- Fixes HTTP 500 when saving the ACL policy on servers that have local (CLI-created, non-OIDC) users: group members are now emitted as `name@`, which is what the Headscale policy parser requires.
- Fixes the network screen's "Error fetching public IP" popup: the public IP is now looked up from several sources with a timeout instead of a single one, a failure no longer raises an error, and it no longer prevents the traceroute from running.
- Install this APK over v2.2.0 as usual; no server-side rollback is needed because a failed save never modified the policy.

---

> 上一个版本 **v2.2.0** 的主要内容是完整中文本地化与自动化构建/发布链路，详见该版本的说明。
> Play 商店版本：https://play.google.com/store/apps/details?id=com.dkstudio.headscalemanager
