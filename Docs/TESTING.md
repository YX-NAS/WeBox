# v0.1 测试说明

自动测试覆盖实例模型、Bundle Identifier 生成、SQLite 保存/删除和应用目录复制。发布前人工验收：创建一个副本、以 `codesign --verify --deep --strict` 验证、启动两个实例、重启 macOS 后确认数据库列表存在，并连续运行 72 小时。
