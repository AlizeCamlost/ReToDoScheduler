# 客户端同步

相关文档：

- [ios.md](ios.md)
- [server-deploy.md](server-deploy.md)

## 1. 前置条件

- 服务端 API 能同时从笔记本和手机访问
- `GET <server-base-url>/health` 返回正常
- 服务端已配置 `API_AUTH_TOKEN`
- 服务端已配置 `WEB_LOGIN_USERNAME` 与 `WEB_LOGIN_PASSWORD`

## 2. 配置

### 2.1 Web

1. 可选：只有当 Web 需要指向非默认 API 地址时，才需要写 `.env`

```bash
cp apps/web/.env.example apps/web/.env
```

在 `apps/web/.env` 中可选设置：

```text
VITE_API_BASE_URL=<server-base-url>
```

本地开发默认通过 Vite 把同源 `/v1/*` 和 `/health` 代理到 `127.0.0.1:8787`，因此只跑本机 API 时可以不写这个值；这样浏览器登录 cookie 会和 Web 保持同源，不会被 `localhost` / `127.0.0.1` 混用打断。

2. 打开 Web 并登录：
   - username = `WEB_LOGIN_USERNAME`
   - password = `WEB_LOGIN_PASSWORD`
3. 登录成功后，浏览器会保存 HttpOnly session cookie；后续同一设备通常无需重复登录
4. 如需管理设备，在 Web `任务池 -> 设置` 中查看当前设备和其它已登录设备，并可主动让其它设备退出

### 2.2 iPhone

在 app 内打开 `设置`，填写：

- `API Base URL`
- `API Auth Token`

## 3. 当前同步行为

- 两端都先写本地，再与服务端收敛
- 当前同步粒度是全量任务列表
- 冲突策略是 LWW，依据 `updatedAt`
- 删除在 MVP 中通过 `archived` 实现软删除
- 当前对外同步 payload 使用最小 `Task` 模型：标题、raw input、状态、估时、最小块、DDL、标签、价值、依赖、步骤、并行模式、时间戳和 `extJson`
- 任务池目录树 / 画布组织通过并行的 `taskPoolOrganization` 文档同步，文档自身也按 `updatedAt` 做 LWW
- 若客户端请求中省略 `taskPoolOrganization`，服务端会保留现有组织文档，不会清空
- 服务端仍可把旧数据库列当内部兼容细节处理，但不再把旧字段暴露回客户端

## 4. 验证方法

### 4.1 健康检查

```bash
curl <server-base-url>/health
```

### 4.2 受保护路由验证

```bash
curl -H "Authorization: Bearer <API_AUTH_TOKEN>" <server-base-url>/v1/tasks
```

返回体除 `items` 外，还应包含当前 `taskPoolOrganization`；若服务端尚未收到过该文档，则该字段可为 `null`。

Web 登录验证：

1. 在浏览器打开 Web
2. 登录后刷新页面，确认仍保持登录
3. 在 `任务池 -> 设置` 中点“退出其他设备”，再到其它设备确认会话失效

### 4.3 双端联调

1. 在 Web 创建或编辑任务
2. 等待或触发 iPhone 同步，确认任务收敛
3. 在 iPhone 调整任务池目录树或画布局部位置并触发同步
4. 返回 Web 或再次请求 `GET /v1/tasks`，确认 `taskPoolOrganization` 未丢失
5. 在 iPhone 完成或归档任务
6. 返回 Web，确认状态同步回来

## 5. 常见问题

### iPhone `Network request failed`

1. 先在 iPhone Safari 打开 `<server-base-url>/health`
2. 如果 Safari 不通，先查网络、反向代理、防火墙和安全组
3. 如果 Safari 可通但 app 不通，检查 app 设置里的 URL 和 token
4. 检查服务端 `API_AUTH_TOKEN` 与 iPhone `API Auth Token` 是否一致

### Web 返回 401 或被要求重新登录

- Web 会话已过期或被主动退出
- 浏览器访问的域名和 API 实际域名不一致，导致 cookie 没有随请求发送
- 生产环境未保持 HTTPS / 同域部署，cookie 策略不匹配

### iPhone 返回 401

- token 不一致
- 修改 token 后未重新触发同步
- 服务端 `API_AUTH_TOKEN` 与 app 内保存的 `API Auth Token` 不一致

### 同步结果与预期不一致

- 当前策略是 LWW，不保留操作级历史
- 两端几乎同时写入同一任务时，以更新时间更晚者为准
- 任务池组织文档同样按文档级 `updatedAt` 收敛；省略字段不会覆盖已有文档

## 6. 当前边界

- 尚未引入 `sync_ops + cursor` 增量同步
- 生产环境应优先走 HTTPS，不应长期依赖 HTTP
