# WeBox for macOS

[English](README.en.md) | 中文

> 本机多应用实例管理工具：独立运行、本地管理、安全隔离。

![macOS](https://img.shields.io/badge/macOS-13%2B-0A84FF?logo=apple&logoColor=white)
![Version](https://img.shields.io/badge/version-1.2.1-6C5CE7)

WeBox 通过创建本机应用副本，为每个副本生成独立的 Bundle Identifier 并重新签名。它只管理本机应用副本和实例状态，不修改客户端协议、不读取消息，也不自动化操作账号。

## 功能

- 自动检测 `/Applications` 中的微信、QQ、WhatsApp 与 Discord 及版本。
- 支持微信创建独立副本；QQ、WhatsApp 与 Discord 为实验性支持。
- 为每个副本设置独立 Bundle Identifier 并进行 ad-hoc 签名。
- 在卡片界面中启动、关闭和移入废纸篓删除实例。
- SQLite 本地保存实例列表，重启应用后仍可恢复。
- 状态栏入口显示运行账号数和每个账号的实时状态。
- 检测源应用升级，标记需要更新的副本。
- 一键检查副本路径、Bundle Identifier、签名及源应用版本；未运行副本可修复签名。
- 搜索、状态筛选、批量启动/关闭，以及不含账号内容的本地诊断信息。

## 使用方式

1. 将受支持应用安装在 `/Applications`。
2. 打开 WeBox，点击“创建实例”并选择应用。
3. 输入名称，例如“工作”或“生活”。
4. 在实例卡片或状态栏菜单中管理实例。

删除会关闭对应实例、将其副本移入废纸篓并清除记录。不会读取或迁移任何应用账号数据。

## 隐私与安全边界

- WeBox 不访问聊天消息、通讯录、账号凭据或网络流量。
- 实例信息仅保存于本机 Application Support 目录中的 SQLite 数据库。
- 创建副本需要写入 `/Applications`，macOS 可能要求授权。
- 当前发布包使用 ad-hoc 签名；尚未经过 Apple Developer ID 公证。

## 第三方软件与商标声明

MIT 开源许可证只处理 WeBox 自己的代码；不代表取得微信、QQ、WhatsApp、Discord 或其他第三方的商标、客户端或服务条款授权。公开前仍建议单独审查项目名称、图标和功能与相关条款的关系。WeBox 与这些产品及其关联方不存在隶属、合作或授权关系。

## 开发与打包

要求：macOS 13+、Swift 6+、Command Line Tools 或 Xcode。

```bash
./Scripts/test.sh
./Scripts/release.sh
```

构建产物位于 `Release/WeBox-v1.2.1-arm64-macos13.dmg`。完整设计、验收边界与测试说明见 [Docs/PRODUCT_1.0.md](Docs/PRODUCT_1.0.md) 和 [Docs/TESTING.md](Docs/TESTING.md)。

## 项目结构

```text
WeBoxApp/   SwiftUI 主界面、状态栏与图标资源
Core/       检测、复制、签名、实例及进程管理
Models/     领域模型
Database/   SQLite 存储
Tests/      自动测试
Docs/       使用与测试文档
```

## 贡献

提交问题、建议或代码前，请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目采用 [MIT License](LICENSE)。许可证仅覆盖 WeBox 自己的代码，第三方软件、名称、商标及服务条款不在授权范围内。
