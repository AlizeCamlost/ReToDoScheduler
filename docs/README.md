# 文档导航

`docs/` 只保留当前仍作为规范或操作真相来源的文档。历史设计稿、教程和过程记录统一降级到 `docs/archive/`。

## 当前规范

- [architecture.md](architecture.md): 当前系统架构、仓库分层、同步数据流和部署边界
- [product-model.md](product-model.md): 产品概念模型，包括任务原型、价值体系与用户场景
- [scheduling-model.md](scheduling-model.md): 当前任务池与动态调度模型，是调度实现的真相来源

## 运维文档

- [client-sync.md](client-sync.md): Web / iOS / API 的同步配置、前置条件与排障
- [ios.md](ios.md): iOS 真机安装、日常启动与联调最小步骤
- [server-deploy.md](server-deploy.md): 服务端部署、自动部署概览与运维注意事项
- [recovery.md](recovery.md): 本地与远端恢复流程

## ADR

- [adr/0001-monorepo-and-stack.md](adr/0001-monorepo-and-stack.md)
- [adr/0002-local-first-sync.md](adr/0002-local-first-sync.md)

## 历史归档

- [archive/product-spec-v1.md](archive/product-spec-v1.md)
- [archive/todo-handbook.md](archive/todo-handbook.md)
- [archive/tutorial-architecture-and-build-zh.md](archive/tutorial-architecture-and-build-zh.md)
- [archive/tutorial-github-auto-deploy-zh.md](archive/tutorial-github-auto-deploy-zh.md)
- [archive/domain-model-v1.1.md](archive/domain-model-v1.1.md)
- [archive/module-map.md](archive/module-map.md)
- [archive/ios-startup-zh.md](archive/ios-startup-zh.md)
- [archive/ios-device-install.md](archive/ios-device-install.md)

## 维护约定

- 如果某份文档仍是当前规范，应放在 `docs/` 根目录。
- 如果某份文档被新的活动文档吸收，应移入 `docs/archive/`，并在顶部明确标注被什么文档取代。
- `docs/resource/` 不属于正式文档树；它已被 `.gitignore` 排除，不纳入当前文档导航。
