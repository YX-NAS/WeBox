# 多应用实例支持

WeBox v1.1 支持检测微信、ChatGPT、WhatsApp、Discord。创建独立副本仅对兼容应用开放。

## 工作方式

- WeBox 从 `/Applications` 检测源应用，读取其 Bundle Identifier 和版本。
- 副本采用 `WeBox_<应用>_<实例名>.app` 命名；既有微信副本保持旧命名，避免影响现有用户。
- 每个副本使用 `com.webox.<应用>.<实例名>` 的独立 Bundle Identifier，并进行 ad-hoc 签名。
- 未安装、或受签名保护而不兼容的应用可在创建菜单中看到，但不会成为可选项。

## 兼容性边界

WeBox 仅负责兼容应用副本的创建、状态检查与启动管理。不同应用是否允许独立登录、如何存放本地数据、是否验证应用签名或修改后的 Bundle Identifier，都由该应用自身决定。WeBox 不绕过任何登录、许可证、客户端完整性或服务条款限制。

ChatGPT 使用 OpenAI 的 Developer ID 签名、Keychain 访问组和应用群组；WhatsApp 使用 App Sandbox、iCloud 与应用群组。修改它们的 Bundle Identifier 后无法保留这些受签名保护的身份，WeBox 因此会阻止创建，避免出现“无法打开个人资料”等客户端警告。Discord 被标为实验性支持，需在安装后通过真实启动测试确认兼容性。
