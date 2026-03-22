# 客户端同步

相关文档：

- [ios.md](ios.md)
- [server-deploy.md](server-deploy.md)

## 1. 前置条件

- 服务端 API 能同时从笔记本和手机访问
- `GET <server-base-url>/health` 返回正常
- 服务端已配置 `API_AUTH_TOKEN`
- Web 与 iPhone 使用同一组 token

## 2. 配置

### 2.1 Web

```bash
cp apps/web/.env.example apps/web/.env
```

在 `apps/web/.env` 中设置：

```text
VITE_API_AUTH_TOKEN=<与服务端一致的 token>
```

如果切换服务端地址，还要同步检查 Web 端当前使用的 API Base URL 配置。

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

### 4.3 双端联调

1. 在 Web 创建或编辑任务
2. 等待或触发 iPhone 同步，确认任务收敛
3. 在 iPhone 完成或归档任务
4. 返回 Web，确认状态同步回来

## 5. 常见问题

### iPhone `Network request failed`

1. 先在 iPhone Safari 打开 `<server-base-url>/health`
2. 如果 Safari 不通，先查网络、反向代理、防火墙和安全组
3. 如果 Safari 可通但 app 不通，检查 app 设置里的 URL 和 token
4. 检查服务端 `API_AUTH_TOKEN` 与 iPhone `API Auth Token` 是否一致

### Web 或 iPhone 返回 401

- token 不一致
- 修改 token 后未重新触发同步

### 同步结果与预期不一致

- 当前策略是 LWW，不保留操作级历史
- 两端几乎同时写入同一任务时，以更新时间更晚者为准

## 6. 当前边界

- 尚未引入 `sync_ops + cursor` 增量同步
- 生产环境应优先走 HTTPS，不应长期依赖 HTTP
