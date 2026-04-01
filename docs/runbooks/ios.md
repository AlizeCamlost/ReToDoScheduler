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
7. 同步成功后，第二页默认会显示 `目录` 视图；顶部 segmented control 可以切到 `脑图`
8. 右上角 `设置` 页会显示当前同步状态，并提供 `隐藏已完成任务` 开关；打开后，目录和脑图都会统一隐藏已完成但未归档的任务
9. 在 `目录` 视图里，上半屏是可折叠的目录导航树，下半屏是可折叠子目录的当前目录目的地；内容会与屏幕边缘保留必要留白，点击整个目录行即可选中目录，导航树中的父子目录会通过更明显的缩进表达层级，展开箭头会紧挨文件夹图标，右侧数字保持右对齐，而目的地下的子目录保持更紧凑、不缩进的平铺列表，并在列表顶部额外提供 `..` 返回上级目录
10. 长按目录行可以新建子目录、重命名、移动或删除目录，新建目录默认会挂到当前选中目录下
11. 回到第一页 `Sequence` 后，浏览态只支持滚动、翻页和点按；长按当前序列卡片约半秒才会进入编辑态。进入后，卡片外区域仍保持原来的页面滚动与翻页，只有卡片本身才支持长按拖拽重排和左滑完成/编辑/归档/删除；切走 tab 或离开页面都会自动视为完成编辑
12. `脑图` 视图支持双指缩放，也可以用右上角的缩放控件放大、缩小或重置到 `100%`

留空也可以先离线使用，本地任务会保存在设备上。

## 5. 常见问题

### 无法运行

- 确认打开的是 `apps/mobile/ios_ng/Norn/Norn.xcodeproj`
- 检查签名团队和 `Bundle Identifier`

### 真机开发镜像报错

- 这通常是 Xcode 与 iOS 版本不匹配，优先升级 Xcode
