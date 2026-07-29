# WeBox for macOS

WeBox v0.1 管理微信应用副本：检测原版微信、复制应用、设置新的 Bundle Identifier、使用本机 ad-hoc 签名、启动和保存实例状态。

## 前置条件

- macOS 13 或更高版本；原版微信位于 `/Applications/WeChat.app`。
- 应用需要可写入 `/Applications`；首次创建可能要求管理员授权。
- v0.1 不读取微信消息、不改微信协议，也不迁移账号数据。

## 使用

打开 WeBox，点击“创建工作微信”。成功后会生成 `/Applications/WeBox_工作微信.app`，可在列表中启动或关闭。删除列表记录不会删除应用副本，避免误删账号数据。

## 验证

使用 `swift test` 运行模型、数据库和复制单元测试。完整签名、真实微信多开和长时间运行须在具备完整 Xcode 的 macOS 测试机验证。
