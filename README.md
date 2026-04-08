# ACCA Learning

这是一个给 ACCA 学习者使用的刷题应用，目标是让你在手机、电脑、网页都能做题，不需要你懂编程。

## 先下载，马上用

如果你只是想做题，不想折腾环境，请直接下载已经打包好的版本：

- Release 页面（点开就能下载）：
  https://github.com/DodgeHo/ACCA-Learning/releases

### 外行下载路径（一步一步）

1. 打开上面的 Release 页面。
2. 选择最新版本（通常在最上面）。
3. 展开 Assets。
4. 按你的设备下载对应文件：
   - Windows 电脑：下载 windows-x64.zip
   - 安卓手机：下载 android.apk
   - 网页版：下载 web.zip（解压后可部署到静态网站）

如果你不确定选哪个，优先选 Windows 或 Android 对应文件。

## 这个仓库适合谁

- 想专门刷 ACCA 科目题库的同学
- 想按科目切换题库（PM、TX、FR、AA、FM、SBL、SBR、AFM、APM、AAA）
- 想要一个本地可用、可追踪学习进度的练习工具

## 你会得到什么

- 会/不会/收藏标记
- 进度追踪与筛选
- 随机刷题
- 主观题（Case/Essay）结构化展示
- 图表/附件题展示

## 当前题库覆盖

- pm、tx、fr、aa、fm、sbl、sbr、afm、apm、aaa

## 想自己运行（给会一点命令行的同学）

1. 安装 Flutter 环境
2. 执行依赖安装
   flutter pub get
3. 切换题库（示例：PM）
   powershell -ExecutionPolicy Bypass -File scripts/select_question_bank.ps1 -Bank pm
4. 启动应用
   flutter run

## 发布与说明文档

- 构建矩阵说明：release/0.3.0/BUILD_MATRIX.md
- 8 科上传与校验说明：release/0.3.0/UPLOAD_NOTES_ACCA_8_SUBJECTS.md
- SHA256 验签清单：release/0.3.0/checksums-acca-8-subjects.sha256

## 温馨说明

- 这是学习工具，不是官方 ACCA 产品。
- 如果你只想使用，不必阅读 scripts 和开发代码。

## 许可证

MIT License
