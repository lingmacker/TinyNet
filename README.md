# TinyNet

TinyNet 是一个使用 SwiftUI 实现的 macOS 菜单栏网速工具：

- 菜单栏实时显示上传/下载速度
- 菜单项支持「开机启动」与「退出」
- 可选显示系统内存和 CPU 使用率

## 项目结构

```text
TinyNet/
├── TinyNet/
│   ├── TinyNet.swift         # 应用入口
│   ├── View/                 # 菜单栏 UI
│   ├── Model/                # ViewModel 与状态管理
│   ├── Core/                 # 纯网速计算核心
│   ├── Assets.xcassets       # App 图标资源
│   └── Resources/            # 字体与本地化资源
├── Tests/
│   └── TinyNetCoreTests/     # Swift Testing 测试
├── TinyNet.xcodeproj         # Xcode 工程
├── Package.swift             # SwiftPM 配置
└── Makefile                  # 一键构建/运行
```

## 环境要求

- macOS 13.0 或更高版本
- Xcode（已安装并可使用 `xcodebuild`）

## 编译与运行

在项目根目录执行：

### 1) 一键编译并运行

```bash
make run
```

### 2) 编译 macOS App

```bash
make build-app
```

默认构建配置为 `Debug`。如需 `Release`：

```bash
make build-app CONFIGURATION=Release
```

## App 输出位置

通过 Makefile 构建后，App 位于：

```text
.build/DerivedData/Build/Products/<CONFIGURATION>/TinyNet.app
```

例如 Debug：

```text
.build/DerivedData/Build/Products/Debug/TinyNet.app
```

## 使用 Xcode 运行

1. 打开 `TinyNet.xcodeproj`
2. 选择 `TinyNet` scheme
3. 直接 Run

工程不依赖外部构建脚本，直接通过 Xcode 构建 Swift 应用。

## 清理构建产物

```bash
make clean
```
