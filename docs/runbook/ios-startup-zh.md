# iOS App 启动指南（中文最新版）

本文件用于你当前项目的 iPhone 真机启动与联调。

## 一键脚本（推荐）

在项目根目录执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:dev
```

可选模式：

```bash
npm run ios:dev:tunnel
npm run ios:prepare
```

含义：

- `ios:dev`：安装依赖并启动 Metro（默认模式）
- `ios:dev:tunnel`：启动 Metro 的 tunnel 模式（同网不通时使用）
- `ios:prepare`：重新生成 iOS 原生工程并打开 Xcode，不启动 Metro

## 首次安装到 iPhone（接近正式包）

1. 先执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:prepare
```

2. Xcode 中打开 target `ReToDoScheduler`，在 `Signing & Capabilities` 设置：

- `Team` 选择你的开发者账号
- `Bundle Identifier` 保持唯一（当前默认：`com.camlostshi.retodoscheduler`）
- 勾选 `Automatically manage signing`

3. 连接 iPhone 15 Pro，选择真机目标，按 `Cmd + R` 安装。

4. 安装后回到终端执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:dev
```

## 日常启动（已安装过 app）

1. 启动 Metro：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:dev
```

2. 在 Xcode 直接 `Cmd + R`（Debug）重跑到真机。

## 与服务器同步（当前 MVP）

1. 先配置 iOS token：

```bash
cp apps/mobile/.env.example apps/mobile/.env
```

在 `apps/mobile/.env` 中设置：

```text
EXPO_PUBLIC_API_AUTH_TOKEN=<与你服务器一致的token>
```

2. 确保服务器可达：

```bash
curl http://43.159.136.45:8787/health
```

3. 重新 `Cmd + R` 安装 app 后，点击 `立即同步`。

说明：

- iOS 端服务器地址已内置为 `http://43.159.136.45:8787`。
- UI 不再提供地址输入框。

## 常见问题

1. 白屏：通常是 Debug 模式下 Metro 未启动。先 `npm run ios:dev` 再重启 app。
2. 构建很慢、风扇响：首次 Xcode 编译 Pods/Hermes 正常，后续会快很多。
3. 手机同步报 `Network request failed`：
   - 先在 iPhone Safari 打开 `http://43.159.136.45:8787/health` 验证连通性。
   - Safari 不通：检查云服务器安全组/防火墙端口 `8787`。
   - Safari 可通但 App 不通：检查 `EXPO_PUBLIC_API_AUTH_TOKEN` 与服务器 `API_AUTH_TOKEN` 是否一致，并重新安装 app。

## 维护约定

后续每次扩展 iOS 启动流程或同步行为，都以本文件作为“最新步骤”进行同步更新。
