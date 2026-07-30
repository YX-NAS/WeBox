# WeBox 1.0 测试说明

运行离线自动验收：

```bash
./Scripts/test.sh
./Scripts/integration-test.sh
./Scripts/release.sh
```

自动验收覆盖实例模型、Bundle Identifier 规则、SQLite 增删改查、应用目录复制、应用包健康检查、筛选逻辑和发布包签名。脚本不会操作 `/Applications/WeChat.app` 或真实微信实例。

集成测试会对 `/Applications` 中已安装的受支持应用，在系统临时目录执行“复制、修改 Bundle Identifier、签名、验证、持久化”闭环；不会启动副本、不会登录账号，也不会写入 `/Applications`。未安装的应用会明确跳过。

发布前人工验收：创建两个中文名称副本；分别启动、关闭、删除并重新创建；人为移走副本并确认异常状态；升级原版微信后确认“需要更新”；对未运行副本执行修复；重启 macOS 后确认实例列表仍存在。长时间稳定性目标为两个实例持续在线 72 小时，需在真实用户环境单独记录结果。
