# 客户端同步

相关文档：

- [ios.md](ios.md)
- [server-deploy.md](server-deploy.md)

## 1. 前置条件

- 服务端 API 可从笔记本和手机访问
- `GET http://<server-ip>:8787/health` 返回正常
- 服务端已配置 `API_AUTH_TOKEN`
- Web 与 iPhone 使用相同的 token

## 2. Token 配置

### Web

```bash
cp apps/web/.env.example apps/web/.env
```

在 `apps/web/.env` 中设置：

```text
VITE_API_AUTH_TOKEN=<与服务端一致的 token>
```

### iPhone

原生 iPhone 客户端不再通过源码文件注入配置。

在 app 内打开 `设置`，填写：

- `API Base URL`
- `API Auth Token`

## 3. 当前同步行为

- Web 使用内置 API URL
- iPhone 使用设置页里的 API URL
- Web 端本地修改后立即 push，并定时 pull
- iPhone 端操作后 push，并定时轮询
- 冲突策略为 LWW，依据 `updatedAt`
- 删除在 MVP 中通过 `archived` 实现软删除，以维持跨端一致性

## 4. 验证方法

### 服务端健康检查

```bash
curl http://43.159.136.45:8787/health
```

### 受保护路由验证

```bash
curl -H "Authorization: Bearer <API_AUTH_TOKEN>" http://43.159.136.45:8787/v1/tasks
```

### 客户端联调

1. 在 Web 创建或编辑任务
2. 观察 iPhone 在下一轮同步后收敛
3. 在 iPhone 完成或归档任务
4. 观察 Web 收到同样状态变更

## 5. 常见问题

### iPhone `Network request failed`

1. 先在 iPhone Safari 打开 `http://43.159.136.45:8787/health`
2. 如果 Safari 不通，优先检查安全组、防火墙和反向代理
3. 如果 Safari 可通但 app 不通，检查 app 设置里的 URL 和 token
4. 检查服务端 `API_AUTH_TOKEN` 与 iPhone `API Auth Token` 是否一致

### Web / iPhone 401

- token 不一致
- 修改后未重新触发同步

### 同步结果与预期不一致

- 当前策略是 LWW，不保留操作历史
- 若两个端几乎同时写入，同一个任务以更新时间更晚者为准

## 6. 当前边界

- 仍使用全量列表同步
- 仍未引入 `sync_ops + cursor` 增量同步
- iPhone 当前为开发联调保留 HTTP 支持，生产环境应切 HTTPS
