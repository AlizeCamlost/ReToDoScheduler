# iOS 启动与安装

相关文档：

- [client-sync.md](client-sync.md)

## 1. 一键打开工程

在项目根目录执行：

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler
npm run ios:prepare
```

或：

```bash
npm run ios:dev
```

这两个命令现在都会直接打开原生工程：

- `apps/mobile/ios/ReToDoScheduler.xcodeproj`

## 2. 首次安装到真机

1. 执行 `npm run ios:prepare`
2. 在 Xcode 中打开 `ReToDoScheduler` target，并设置：
   - `Team`: 你的开发者账号
   - `Bundle Identifier`: 保持唯一，默认是 `com.camlostshi.retodoscheduler`
   - `Automatically manage signing`: 开启
3. 连接 iPhone，选择真机目标，执行 `Cmd + R`
4. 如系统拦截启动，检查：
   - `Settings -> Privacy & Security -> Developer Mode`
   - `Settings -> General -> VPN & Device Management` 中的开发者证书信任

## 3. 日常启动

1. 执行 `npm run ios:dev`
2. 在 Xcode 中选择模拟器或真机
3. 按 `Cmd + R`

当前 iPhone 客户端已经是原生 SwiftUI 应用，不再依赖 React Native、Metro、Pods 或 Expo。

## 4. 与同步相关的最小步骤

1. 启动 app
2. 打开右上角 `设置`
3. 填写：
   - `API Base URL`
   - `API Auth Token`
4. 返回主界面，点击 `立即同步`

留空也可以先离线使用，本地任务会保存在设备上。

## 5. 常见问题

### 无法运行

确认打开的是：

- `apps/mobile/ios/ReToDoScheduler.xcodeproj`

再检查签名团队和 Bundle Identifier。

### 真机开发镜像报错

这是 Xcode / iOS 版本匹配问题，先升级 Xcode。
