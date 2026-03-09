# AWS-SAA Learning Skill

一个用于学习 AWS Certified Solutions Architect Associate (SAA) 的 AI 学习辅导系统。课程内容来自 Stéphane Maarek 的 AWS SAA 课程, 学习框架参考 AlphaMao Skills。

## 项目定位

- 面向自学: 用本地字幕材料构建可复习的学习路径
- 面向实操: 将 Hands-On 章节视为实践任务
- 面向复习: 通过进度追踪与间隔复习强化记忆

## 课程来源

- 课程名称: AWS Certified Solutions Architect Associate
- 讲师: Stéphane Maarek
- 官方认证页面: https://aws.amazon.com/certification/certified-solutions-architect-associate/

> 说明: 本仓库不包含课程视频或字幕文件, 仅提供学习框架与结构化模板。课程素材需由学习者自行准备并放置在translations路径中。

## 学习框架来源

- 项目: AlphaMao Skills
- 链接: https://github.com/z1993/AlphaMao_Skills/tree/main
- 说明: 本项目在学习流程与结构设计上参考该仓库的思路, 保留原作者署名与链接。
- 许可证: 上游仓库未标注明确许可证 (GitHub API 显示 license = null)。如需严格许可声明, 请先确认上游许可证后再发布。

## 核心特点

- **课程素材**: 来自课程中的字幕文件
- **自动整理**: 转换字幕为可读的 Markdown 并放入 translations/
- **结构化学习**: 按章节生成学习清单与进度模板
- **中文优先**: 材料来自中文字幕, 术语保留英文
- **进度追踪**: 在 Obsidian Vault 中管理进度与复习

## Flutter 题库助手 (跨平台)

本仓库已移除旧的 Python/Tkinter 实现，所有功能已迁移到 Flutter。
生成的应用支持 Windows、macOS、Linux 桌面、Android 手机/平板以及 Web。
Web 端使用 `assets/questions.json` + `sembast` (IndexedDB) 存储，不依赖 `sqflite`。
界面采用响应式布局：宽屏为题目区+AI区双栏，窄屏自动切换为上下布局，兼容键鼠与触屏。

Web 离线策略（当前）：

- 已启用自定义 Service Worker（`web/sw.js`），首次在线访问后可离线回访已加载页面与题库 JSON。
- 导航请求采用 network-first，静态资源采用 cache-first，题库 JSON 采用 stale-while-revalidate。
- 这仍是“已加载内容可离线回访”模式，不等同于完整离线发行包。

功能概览：

- 启动时从 `assets/data.db` 复制题库到本地 SQLite 数据库。（首次运行可在日志中看到复制路径，文件位于
  `getDatabasesPath()` 返回的位置）
- 若要更新题库，可用新的 SQLite 文件替换 `assets/data.db` 然后重新 `flutter build`。
  旧版 release 目录中的 `data.db` 仅用于 Python MVP，不会被 Flutter 项目使用。
- 按状态筛选题目（All/Know/DontKnow/Favorite），支持随机顺序。
- 浏览题目、显示答案，记录和查询状态、进度。
- 题目概览页面可跳转、统计各类题目数量。
- AI 问答模块已接入，支持 DeepSeek / OpenAI 兼容接口。
- 设置页支持配置 AI Provider、Model、Base URL 与 API Key。
- 设置页支持 AI 对话历史导出/导入（JSON）用于手动备份恢复。
- 设置页面可调整字体大小、选择 AI 提供者及输入 API Key，保存于本地。
- 全局状态由 `AppModel` 使用 `provider` 管理。

本地数据与备份建议：

- 题库与刷题状态、AI 对话历史均保存于本地数据库（原生为 SQLite，Web 为 IndexedDB）。
- 若清理浏览器站点数据、卸载应用或更换设备，本地数据可能丢失。
- 建议定期在设置页使用“导出所有对话历史（JSON）”做手动备份。

快速启动：

```bash
flutter pub get
flutter run        # 在当前设备或模拟器上运行
# 或指定平台：flutter run -d windows/android/ios/web
```

打包示例：

```bash
flutter build windows
flutter build apk
flutter build web
```

项目结构：

```
aws-saa-learning/
├── lib/                # Dart 源代码
│   ├── main.dart
│   ├── app_model.dart
│   ├── db.dart
│   └── models.dart
├── assets/
│   └── data.db         # 初始题库
├── pubspec.yaml
├── README.md
├── INSTALL.md
└── …（其他文档与翻译资料）
```

## 安装

1. 将此文件夹复制到你的 Skills 目录:
   ```
   # Windows
   C:\Users\你的用户名\.gemini\antigravity\skills\aws-saa-learning\
   C:\Users\你的用户名\.copilot\skills\aws-saa-learning\
   
   # macOS/Linux
   ~/.gemini/antigravity/skills/aws-saa-learning/
   ```

2. 创建或准备一个 Obsidian Vault（首次运行时会询问路径）

3. 安装 Obsidian 插件 (推荐):
   - https://github.com/st3v3nmw/obsidian-spaced-repetition

## 使用方法

### 开始学习

```
开始学习
```

系统会：
1. 读取你的当前进度
2. 询问学习模式
3. 逐篇引导学习

### 核心命令

| 命令 | 作用 |
|------|------|
| `开始学习` | 首次启动, 选择学习模式 |
| `学习 章节名` | 学习指定章节 |
| `读 [材料名]` | 阅读指定材料 |
| `解释 [术语]` | 获得通俗解释 |
| `读完了` | 完成阅读, 进入问答环节 |
| `我的进度` | 查看学习进度 |

### 学习流程

```
选择材料 -> 阅读字幕整理稿 -> 解释疑问 -> 回答问题 -> 生成笔记 -> 周末生成定制闪卡
```

## 文件结构

```
aws-saa-learning/
├── lib/                # Dart 源代码
├── assets/             # 包含初始题库 data.db
├── pubspec.yaml
├── README.md
├── INSTALL.md
├── SKILL.md
├── PROJECT_PLAN.md
├── ISSUES.md
├── translations/       # 课程字幕整理稿
├── references/         # 附加文档
└── templates/          # 结构化笔记模板
```

## 许可证

MIT License

## 贡献指南 (GitHub)

欢迎提交 issue 与 PR。为便于协作, 建议遵循以下流程:

1. 在 [ISSUES.md](ISSUES.md) 中确认是否已有相关问题
2. 新建 issue 描述动机、影响范围与期望结果
3. Fork 仓库并创建分支: `feature/<short-name>` 或 `fix/<short-name>`
4. 保持改动聚焦、提交信息清晰 (建议: `type: summary` 格式)
5. 在 PR 中说明变更背景、验证方式与相关 issue

如果涉及学习材料或模板更新, 请同时更新 [CHANGELOG.md](CHANGELOG.md)。

## 发布说明 (GitHub)

本项目采用 GitHub Releases 发布。建议使用语义化版本号 (SemVer):

- 版本格式: `MAJOR.MINOR.PATCH`
- 变更记录: 统一维护在 [CHANGELOG.md](CHANGELOG.md)
- 发布节奏: 重要内容合并后发布; 小修复可累积后发布

发布步骤建议:

1. 更新 [CHANGELOG.md](CHANGELOG.md) 并确保版本号一致
2. 打 tag 并推送到 GitHub
3. 在 GitHub Releases 页面发布对应版本说明

## 相关链接

- https://aws.amazon.com/certification/certified-solutions-architect-associate/
- https://github.com/z1993/AlphaMao_Skills/tree/main
