# TinyNet

TinyNet 是一个使用 SwiftUI 实现的 macOS 菜单栏网速工具：

- 菜单栏实时显示上传/下载速度
- 菜单内按应用/进程显示实时上下行速率和本次监测累计流量，合并应用辅助进程
- 菜单项支持「开机启动」与「退出」
- 可选显示系统内存和 CPU 使用率
- macOS 26 原生 Liquid Glass 菜单背景，自动适配深浅色外观

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
├── tests/
│   └── TinyNetCoreTests/     # Swift Testing 测试
├── TinyNet.xcodeproj         # Xcode 工程
└── Makefile                  # 一键构建/运行
```

## 环境要求

- macOS 26.0 或更高版本
- Xcode 26 或更高版本（已安装并可使用 `xcodebuild`）

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

## 按应用网络统计

使用 macOS 自带 `nettop` 在后台采样 TCP/UDP 外部流量，无需 sudo 或第三方依赖；按进程启动时间区分 PID，再通过应用路径、负责进程和父进程归并。首次采样只建立基线，累计值从 TinyNet 本次启动后开始，不保存跨启动历史。

此功能不统计 loopback；代理/VPN 流量可能记在代理进程名下，采样间结束的短连接可能遗漏。它与菜单栏的网卡总速率口径不同，不能作为精确账单。分析依据、逆向范围及未移植部分见 [Mole 网络统计分析](docs/Mole-network-analysis.md)。

## 测试

```bash
swift test
# 额外运行本机 nettop 冒烟测试：
TINYNET_LIVE_TESTS=1 swift test
# 在已登录的 macOS 桌面会话中检查菜单窗口、深浅色和关闭行为：
make test-ui
```

`Package.swift` 仅用于测试统计核心和 macOS 采样器；App 仍通过 Xcode/Makefile 构建。

## 清理构建产物

```bash
make clean
```
