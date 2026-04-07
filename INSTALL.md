# Installation Instructions

This document explains how to set up the AWS-SAA Learning Skill and the QBank Trainer tool.

## 1. AWS-SAA Learning Skill

1. Clone or download the repository:
   ```bash
   git clone https://github.com/DodgeHo/aws-saa-learning-skill.git
   ```
2. Place course subtitles and materials in the `translations/` directory as described in the main `README.md`.
3. (Optional) Create an [Obsidian](https://obsidian.md/) vault and install the recommended spaced repetition plugin.
4. Use the interactive commands (`开始学习`, `学习 章节名`, etc.) via your preferred interface.

No additional dependencies are required for the learning skill itself; it is primarily a collection of markdown and supporting scripts.

## 2. Question Bank Trainer (Flutter)

本项目的题库助手已使用 Flutter 重新实现，放在仓库根目录。
它支持 Windows、macOS、Linux 桌面，Android 手机/平板，以及 Web（可选）。

### Build & Run

```bash
# 先安装 Flutter SDK
git clone https://github.com/DodgeHo/aws-saa-learning-skill.git
cd aws-saa-learning-skill
flutter pub get
flutter run          # 在默认连接的设备或模拟器上运行
# 指定平台示例：flutter run -d windows/android/ios
# Web 也支持：flutter run -d chrome
```

> **注意（Windows 桌面）**
> 
> 构建/运行 Windows 版本需要
> 1. 在系统设置中启用 **开发者模式**（符号链接支持）；
> 2. 安装 **Visual Studio 2022/2023** 并添加 “Desktop development with C++” 工作负载。
>    `flutter doctor` 会提示缺少此工具链。完成安装后重新运行 `flutter run -d windows`。


应用首次启动时会从 `assets/data.db` 将题库复制到设备的本地数据库目录。
（可在命令行日志看到复制操作，目标路径由 `getDatabasesPath()` 决定，例如
`C:\Users\<user>\AppData\Local\...`)。

> 如果想使用新的题库，请将替换好的 SQLite 文件重命名为 `assets/data.db`，
> 然后重新运行或打包应用；旧的本地数据库会被覆盖或手动删除后再次启动。
> 
> 对于 Web 需要额外生成 JSON 版本：
> ```bash
> py scripts/export_questions_to_json.py
> ```
> 该命令会写入或更新 `assets/questions.json`，用于 Web 模式的初始数据。

用户设置和 AI Key 保存在本地（`shared_preferences` + 系统安全存储），
刷题状态与 AI 对话历史保存在本地数据库（原生 SQLite / Web IndexedDB）。

### 本地数据备份建议

- 在设置页可使用“导出所有对话历史（JSON）”进行手动备份。
- 在新环境可通过“导入对话历史（JSON）”恢复历史记录。
- 若发生浏览器站点数据清理、系统重装、应用卸载，本地数据可能不可恢复，请提前导出备份。

### Packaging

```bash
flutter build windows   # 生成 Windows 可执行文件
flutter build macos
flutter build linux
flutter build apk       # Android APK
flutter build web       # Web 应用
```

构建成果静态放在各自的 `build/` 子目录下，可按需打包分发。

### Web 部署（腾讯云服务器）

如果你将 Web 版本部署到腾讯云服务器（如 CVM + Nginx）：

1. 先构建：
   ```bash
   flutter build web
   ```
2. 将 `build/web/` 全量上传到站点目录。
3. 建议缓存策略：
   - `index.html`：`Cache-Control: no-cache`
   - `flutter_bootstrap.js`、`flutter.js`：`Cache-Control: no-cache`
   - `main.dart.js`、`assets/*`：可使用较长缓存（文件名随构建变化时更安全）
4. 更新版本后，先刷新 `index.html`，再让静态资源按新清单加载，避免“页面更新但资源未更新”的混合版本问题。

> 说明：当前项目目标是“已加载内容可离线回访”，并非完整离线安装包模式。

当前实现已启用自定义 Service Worker（`web/sw.js`）。
若你修改了缓存策略或离线资源列表，请同步更新 `CACHE_VERSION`，以便浏览器清理旧缓存并拉取新版本。

#### `CACHE_VERSION` 更新规范

- 命名格式固定为：`aws-saa-web-v{数字}`（例如 `aws-saa-web-v2`）。
- 以下情况必须递增版本号：
   1. `STATIC_ASSETS` 列表变化；
   2. 缓存策略变化（`networkFirst` / `cacheFirst` / `staleWhileRevalidate` 逻辑调整）；
   3. 已发生“线上更新后仍命中旧缓存”的问题并需要强制刷新。
- 递增后重新 `flutter build web` 并全量发布 `build/web/`。

#### 上线前后检查清单（Web）

- 上线前：
   1. 执行 `flutter build web`，确认构建成功；
   2. 确认 `web/sw.js` 中 `CACHE_VERSION` 已按本次变更递增；
   3. 全量上传 `build/web/`（不要只传部分静态文件）。
- 上线后：
   1. 在线首次访问，确认题库、切题、标记、AI 提问正常；
   2. 刷新页面后确认刷题状态仍存在；
   3. 切离线后回访同地址，确认已加载页面可打开；
   4. 若仍命中旧版本，清理站点缓存后再次验证。

### Chrome 离线内测验收清单（建议）

以下清单用于验证“已加载内容可离线回访”是否满足内测标准：

1. **首次在线加载**
   - 在联网状态打开应用。
   - 确认题目可显示、可切题、可标记（会/不会/收藏）。
2. **本地持久化检查**
   - 标记几道题，刷新页面后状态仍在。
   - 进入错题循环模式，确认仅在“不会”题集中循环。
3. **离线回访检查**
   - 保持该页面已访问过，断网（或 DevTools 切到 Offline）。
   - 重新打开同地址，确认页面可打开且可查看已加载题目。
4. **键盘与交互检查**
   - 验证快捷键：`←`/`→`、`A`、`K`/`D`/`F`、`/`。
   - 验证输入框聚焦时，快捷键不会误触发刷题动作。
5. **异常提示检查**
   - 在无题可刷或加载失败场景下，确认有清晰提示和重试入口。

满足以上 5 项，可视为 Chrome 离线内测版“可用”。

### 一键本地自测步骤（开发机）

```bash
flutter clean
flutter pub get
flutter test
flutter run -d chrome
```

打开后按以下顺序快速验证：

1. 标记 2-3 道题并刷新，确认状态不丢失。
2. 开启“错题循环”，使用方向键循环切题。
3. 按 `/` 聚焦 AI 提问框，再输入并回车发送。
4. 断网后回访同页面，确认已访问内容可打开。

### 常见问题排查（离线内测）

- **离线打不开页面**：先确认该地址在联网状态下至少访问过一次。
- **更新后页面还是旧版**：检查 `web/sw.js` 的 `CACHE_VERSION` 是否递增。
- **快捷键无效**：先确认焦点不在输入框；若在输入框中，快捷键会被输入行为接管。
- **题目为空**：检查 `assets/questions.json` 是否已更新并被打包。

## 3. Environment Variables

- `DEEPSEEK_API_KEY` 或 `OPENAI_API_KEY`：仅在使用 AI 提问功能时需要。
  也可以在应用设置页直接输入 API Key。


