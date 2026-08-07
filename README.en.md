# WeBox for macOS

English | [中文](README.md)

> A local macOS app-instance manager for isolated app copies and lifecycle control.

![macOS](https://img.shields.io/badge/macOS-13%2B-0A84FF?logo=apple&logoColor=white)
![Version](https://img.shields.io/badge/version-1.3.0-6C5CE7)

WeBox detects supported apps in `/Applications`, creates compatible app copies with unique bundle identifiers, re-signs them, and stores instance status locally. It doesn't read messages, credentials, contacts, or network traffic.

## Features

- Chinese and English in-app interface; switch languages from the More menu.
- Create and manage compatible WeChat copies plus experimental QQ and WhatsApp copies.
- Search and filter instances by app and status; start, stop, repair, or move copies to Trash.
- Local SQLite persistence, health checks, diagnostics, and a menu bar overview.
- Compatibility center, visible creation progress, and JSON export/import for WeBox configuration only.
- ChatGPT is intentionally not listed as creatable because its signed Keychain and app-group identity can't be safely preserved after bundle-ID changes.

## Requirements and limits

- macOS 13+ on Apple Silicon; source applications must be in `/Applications`.
- Copies use ad-hoc signing and aren't Developer ID notarized.
- QQ, WhatsApp, and Discord remain compatibility-dependent: creation is tested where installed, while independent sign-in and long-running behavior must be verified with a real account.

## Build and test

```bash
./Scripts/test.sh
./Scripts/integration-test.sh
./Scripts/release.sh
```

## License and third-party notice

WeBox is licensed under [MIT](LICENSE), covering only WeBox source code. It grants no trademark, client, or service-terms rights for WeChat, QQ, WhatsApp, Discord, or any other third party. WeBox isn't affiliated with or endorsed by these products.
