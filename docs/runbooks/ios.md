# iOS 启动与安装

相关文档：

- [client-sync.md](client-sync.md)

## 1. 打开工程

在项目根目录执行：

```bash
npm run ios:prepare
```

或：

```bash
npm run ios:dev
```

这两个命令都会打开原生工程：

- `apps/mobile/ios_ng/Norn/Norn.xcodeproj`

当前 iPhone 客户端已经是原生 SwiftUI 应用，不再依赖 React Native、Metro、Pods 或 Expo。

## 2. 首次安装到真机

1. 执行 `npm run ios:prepare`
2. 在 Xcode 中打开 `Norn` target
3. 设置签名：
   - `Team`: 你的开发者账号
   - `Bundle Identifier`: 保持唯一，默认 `camloshi.Norn`
   - `Automatically manage signing`: 开启
4. 连接 iPhone，选择真机目标，执行 `Cmd + R`
5. 如系统拦截启动，检查：
   - `Settings -> Privacy & Security -> Developer Mode`
   - `Settings -> General -> VPN & Device Management` 中的证书信任

## 3. 日常运行

1. 执行 `npm run ios:dev`
2. 在 Xcode 中选择模拟器或真机
3. 按 `Cmd + R`

## 4. 最小同步配置

1. 启动 app
2. 向左滑到第二页 `任务池`
3. 点右上角 `设置` 图标
4. 填写：
   - `API Base URL`
   - `API Auth Token`
   - `Device ID` 可留空，保存时会自动生成
5. 保存设置
6. 保持在第二页 `任务池`，点击右上角刷新图标触发手动同步

留空也可以先离线使用，本地任务会保存在设备上。

## 5. 常见问题

### 无法运行

- 确认打开的是 `apps/mobile/ios_ng/Norn/Norn.xcodeproj`
- 检查签名团队和 `Bundle Identifier`

### 真机开发镜像报错

- 这通常是 Xcode 与 iOS 版本不匹配，优先升级 Xcode
