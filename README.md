# PhotoSync - 照片同步 App

通过局域网将小米手机上的照片和视频单向同步到电脑。

## 项目结构

```
photo_sync/
├── packages/
│   └── photo_sync_core/          # 共享核心库（通信协议、同步逻辑、配对认证）
├── app_mobile/                   # 手机端 App (Android)
├── app_desktop/                  # 电脑端桌面 App (Windows/macOS/Linux)
└── README.md
```

## 技术栈

- **语言**: Dart
- **框架**: Flutter (手机端 + 桌面端)
- **通信**: HTTP REST + mDNS 局域网发现
- **认证**: 扫码配对 + JWT Token

## 快速开始

### 前置条件

- Flutter SDK >= 3.0.0
- Android Studio（手机端开发）
- 对应平台的桌面开发支持已启用

### 1. 安装依赖

```bash
# 核心库
cd packages/photo_sync_core && dart pub get

# 手机端
cd ../../app_mobile && flutter pub get

# 电脑端
cd ../app_desktop && flutter pub get
```

### 2. 运行电脑端

```bash
cd app_desktop

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 3. 运行手机端

```bash
cd app_mobile
flutter run
```

### 4. 使用方式

1. 启动电脑端 App → 自动显示配对二维码
2. 手机端打开 App → 点击"扫码连接" → 扫描二维码
3. 确认双方显示的配对确认码一致
4. 连接成功后，点击"开始同步"

## 功能特性

- ✅ 局域网自动发现 + 扫码配对
- ✅ 照片 + 视频同步
- ✅ 增量同步（基于时间戳 + 快速指纹）
- ✅ 传输进度显示
- ✅ 暂停/恢复同步
- ✅ 按来源相册自动归类
- ✅ 文件去重
- ✅ 同步完成通知
- ✅ 电脑端照片浏览
- ✅ 磁盘空间预警
- ✅ 同步记录重置（全量/按日期/按相册）
