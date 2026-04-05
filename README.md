# TinyNet

TinyNet 是一个 macOS 菜单栏网速工具，使用 **Rust + SwiftUI** 实现：

- 菜单栏实时显示上传/下载速度
- 菜单项支持「开机启动」与「退出」
- Rust 负责网速计算核心，SwiftUI 负责 UI

> [!NOTE]
>
> Claude code 实验产物

Claude code实验产物

## 项目结构

```text
TinyNet/
├── src/
│   ├── rust/                 # Rust 核心与 FFI
│   └── swift/                # SwiftUI 应用代码
├── tests/rust/               # Rust 测试
├── bridge/                   # Swift <-> Rust 桥接产物与头文件
├── scripts/build_rust.sh     # Rust 构建脚本（Xcode/CLI 共用）
├── TinyNetMenuApp.xcodeproj  # Xcode 工程
└── Makefile                  # 一键构建/运行
```

## 环境要求

- macOS
- Xcode（已安装并可使用 `xcodebuild`）
- Rust 工具链（`cargo`）

> `scripts/build_rust.sh` 会尝试从常见路径查找 `cargo`：
> `~/.cargo/bin`、`/opt/homebrew/bin`、`/usr/local/bin`

## 编译与运行

在项目根目录执行：

### 1) 一键编译并运行

```bash
make run
```

### 2) 仅编译 Rust 核心

```bash
make build-rust
```

### 3) 编译 macOS App

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
.build/DerivedData/Build/Products/<CONFIGURATION>/TinyNetMenuApp.app
```

例如 Debug：

```text
.build/DerivedData/Build/Products/Debug/TinyNetMenuApp.app
```

## 使用 Xcode 运行

1. 打开 `TinyNetMenuApp.xcodeproj`
2. 选择 `TinyNetMenuApp` scheme
3. 直接 Run

工程已包含 Rust 构建脚本阶段（Build Rust Core），运行时会自动先编译 Rust。

## 清理构建产物

```bash
make clean
```
