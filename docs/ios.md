# iOS 启动与安装

相关文档：

- [client-sync.md](client-sync.md)

## 1. 一键脚本

在项目根目录执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:dev
```

可选命令：

```bash
npm run ios:dev:tunnel
npm run ios:prepare
```

含义：

- `ios:dev`: 安装依赖并启动 Metro
- `ios:dev:tunnel`: 启动 Metro 的 tunnel 模式
- `ios:prepare`: 重新生成 iOS 原生工程并打开 Xcode

## 2. 首次安装到真机

1. 先执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:prepare
```

2. 在 Xcode 中打开 `ReToDoScheduler` target，并设置：

- `Team`: 你的开发者账号
- `Bundle Identifier`: 保持唯一，默认是 `com.camlostshi.retodoscheduler`
- `Automatically manage signing`: 开启

3. 连接 iPhone，选择真机目标，执行 `Cmd + R`

4. 如系统拦截启动，检查：

- `Settings -> Privacy & Security -> Developer Mode`
- `Settings -> General -> VPN & Device Management` 中的开发者证书信任

## 3. 日常启动

1. 启动 Metro：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:dev
```

2. 在 Xcode 直接 `Cmd + R` 重跑到真机

## 4. 与同步相关的最小步骤

1. 配置 `apps/mobile/.env`
2. 确保 iPhone 能访问服务器
3. 重新安装 app
4. 点击客户端内的同步入口

具体 token 和同步排障见 [client-sync.md](client-sync.md)。

## 5. 常见问题

### 白屏

通常是 Debug 模式下 Metro 未启动。先执行 `npm run ios:dev` 再重启 app。

### 首次编译很慢

首次 Xcode 编译 Pods / Hermes 较慢是正常现象，后续会明显变快。

### 需要接近正式包的安装流程

如果要走更接近分发的流程：

1. 执行 `npm run ios:prepare`
2. 在 Xcode 中完成签名配置
3. 用 `Cmd + R` 安装到真机
4. 准备正式分发时使用 `Product -> Archive`
