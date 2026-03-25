import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_client.dart';
import 'app_model.dart';
import 'db.dart';
import 'models.dart';

void main() {
  runApp(const AwsSaaTrainerApp());
}

class AwsSaaTrainerApp extends StatelessWidget {
  const AwsSaaTrainerApp({super.key});

  ThemeData _buildTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    );

    // On Windows, prefer a Chinese-friendly font stack to improve readability.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final windowsTextTheme = base.textTheme.apply(
        fontFamily: 'Microsoft YaHei UI',
        fontFamilyFallback: const ['Microsoft YaHei', 'Segoe UI'],
      );
      final windowsPrimaryTextTheme = base.primaryTextTheme.apply(
        fontFamily: 'Microsoft YaHei UI',
        fontFamilyFallback: const ['Microsoft YaHei', 'Segoe UI'],
      );
      return base.copyWith(
        textTheme: windowsTextTheme,
        primaryTextTheme: windowsPrimaryTextTheme,
      );
    }

    return base;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final model = AppModel();
        model.loadSettings().then((_) => model.loadQuestions());
        return model;
      },
      child: MaterialApp(
        title: 'SAA 练习',
        theme: _buildTheme(),
        home: const MainScaffold(),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const String _learningNoticeAckKey = 'learning_notice_ack_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showLearningNoticeIfNeeded());
    });
  }

  Future<void> _showLearningNoticeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_learningNoticeAckKey) ?? false;
    if (accepted || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('使用须知'),
        content: const Text(
          '本应用内容仅供交流学习与备考参考，不构成任何官方建议或商业承诺。\n\n'
          '请勿用于违规用途；由使用者自行判断和承担相关责任。',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('我已知晓'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await prefs.setBool(_learningNoticeAckKey, true);
  }

  void _openKeyboardHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('本地快捷键'),
        content: const Text(
          '← 上一题\n'
          '→ 下一题\n'
          'A 显示答案\n'
          'K 标记会\n'
          'D 标记不会\n'
          'F 标记收藏\n'
          '/ 聚焦提问框\n\n'
          '提示：当输入框聚焦时，快捷键不会触发。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _openProgressDialog() {
    final size = MediaQuery.of(context).size;
    final width = (size.width * 0.92).clamp(320.0, 900.0);
    final height = (size.height * 0.92).clamp(320.0, 640.0);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: width,
          height: height,
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: ProgressPage(),
          ),
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    final size = MediaQuery.of(context).size;
    final width = (size.width * 0.92).clamp(320.0, 560.0);
    final height = (size.height * 0.92).clamp(320.0, 520.0);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: width,
          height: height,
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SettingsPage(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 760;
    final model = context.watch<AppModel>();
    final answered = model.answeredQuestionCount;
    final total = model.allQuestions.length;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompact ? 48 : null,
        titleSpacing: isCompact ? 8 : null,
        title: isCompact ? null : const Text('SAA 练习'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Text(
                '进度 $answered/$total',
                style: TextStyle(
                  color: Colors.blueGrey.shade800,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (!isCompact)
            IconButton(
              tooltip: '快捷键帮助',
              icon: const Icon(Icons.keyboard_outlined),
              onPressed: _openKeyboardHelpDialog,
            ),
          IconButton(
            tooltip: '进度',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: _openProgressDialog,
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: const QuizPage(),
    );
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _jumpController = TextEditingController();
  final FocusNode _aiInputFocusNode = FocusNode();
  StateSetter? _aiBottomSheetSetState;
  bool _askingAi = false;
  bool _wrongLoopMode = false;
  bool _attachQuestionContext = true;
  bool _aiQuickPromptsExpanded = true;
  bool _compactHeaderCollapsed = false;
  int _questionNavDirection = 1;
  String _cachedAiHistoryRaw = '';
  List<Map<String, String>> _cachedAiMessages = const <Map<String, String>>[];
  String? _filterBeforeWrongLoop;
  Timer? _fontAdjustTimer;
  int _lastEncouragedMilestone = 0;
  int? _lastEncouragementIndex;
  int? _lastAnsweredQuestionId;
  String? _lastSelectedOption;
  bool? _lastAnswerCorrect;

  static const String _keyboardHint =
      '快捷键：← 上一题，→ 下一题，A 显示答案，K 标记会，D 标记不会，F 标记收藏，/ 聚焦提问框（输入框聚焦时不触发）';

  static const Map<String, String> _filterDisplayToMode = {
    '所有': 'All',
    '会': 'Know',
    '不会': 'DontKnow',
    '收藏': 'Favorite',
  };

  static const Map<String, String> _filterModeToDisplay = {
    'All': '所有',
    'Know': '会',
    'DontKnow': '不会',
    'Favorite': '收藏',
  };

  static const Map<String, String> _statusDisplay = {
    'Know': '会',
    'DontKnow': '不会',
    'Favorite': '收藏 ★',
  };

  static const List<String> _encouragementMessages = [
    '稳住节奏，理解在持续累积。',
    '做得很好，再坚持一轮就更扎实了。',
    '你的判断速度和准确性都在提升。',
    '继续推进，离目标又近了一步。',
    '保持这个状态，今天的复习很高效。',
  ];

  Color _statusColor(String? status) {
    switch (status) {
      case 'Know':
        return Colors.green.shade700;
      case 'DontKnow':
        return Colors.red.shade700;
      case 'Favorite':
        return Colors.amber.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  bool _isTextInputFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText;
  }

  void _runShortcutIfReady(VoidCallback action) {
    if (_isTextInputFocused()) return;
    action();
  }

  void _refreshAiPanelUi([VoidCallback? update]) {
    if (!mounted) return;
    setState(() {
      update?.call();
    });
    _aiBottomSheetSetState?.call(() {});
  }

  void _handleQuestionHorizontalSwipe(AppModel model, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 180) return;
    if (velocity < 0) {
      _nextQuestion(model);
    } else {
      _prevQuestion(model);
    }
  }

  Future<void> _toggleWrongLoopMode(AppModel model, bool enabled) async {
    if (!enabled) {
      final restoreFilter = _filterBeforeWrongLoop;
      setState(() {
        _wrongLoopMode = false;
        _filterBeforeWrongLoop = null;
      });
      if (restoreFilter != null && model.filterMode != restoreFilter) {
        await model.setFilterMode(restoreFilter);
      }
      return;
    }

    _filterBeforeWrongLoop = model.filterMode;
    if (model.filterMode != 'DontKnow') {
      await model.setFilterMode('DontKnow');
    }

    if (!mounted) return;

    if (model.questions.isEmpty) {
      setState(() {
        _wrongLoopMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有“不会”题目，无法开启错题循环')),
      );
      return;
    }

    setState(() {
      _wrongLoopMode = true;
    });
  }

  void _nextQuestion(AppModel model) {
    _questionNavDirection = 1;
    if (_wrongLoopMode && model.questions.isNotEmpty && model.currentIndex >= model.questions.length - 1) {
      model.jumpToDisplayIndex(0);
      return;
    }
    model.next();
  }

  void _prevQuestion(AppModel model) {
    _questionNavDirection = -1;
    if (_wrongLoopMode && model.questions.isNotEmpty && model.currentIndex == 0) {
      model.jumpToDisplayIndex(model.questions.length - 1);
      return;
    }
    model.prev();
  }

  void _focusAiInput(AppModel model) {
    if (model.apiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中填写 API Key')),
      );
      return;
    }
    _aiInputFocusNode.requestFocus();
  }

  Future<void> _markAndMaybeNext(AppModel model, String status) async {
    await model.mark(status);
    if (!mounted) return;
    if (model.autoNextAfterMark &&
        model.filterMode == 'All' &&
        model.currentIndex < model.questions.length - 1) {
      model.next();
    }
  }

  String _buildQuestionTextForCopy(Question q, {bool includeAnswer = false}) {
    final buffer = StringBuffer();
    buffer.writeln('题号：${q.qNum ?? '-'}');
    if (q.stemZh != null && q.stemZh!.trim().isNotEmpty) {
      buffer.writeln('\n【中文题干】');
      buffer.writeln(q.stemZh);
    }
    if (q.optionsZh != null && q.optionsZh!.isNotEmpty) {
      buffer.writeln('\n【中文选项】');
      buffer.writeln(q.optionsZh!.join('\n'));
    }
    if (includeAnswer) {
      buffer.writeln('\n【参考答案】${q.correctAnswer ?? '(空)'}');
      buffer.writeln('\n【中文解析】');
      buffer.writeln(q.explanationZh ?? '(空)');
    }
    return buffer.toString().trim();
  }

  Future<void> _copyQuestionToClipboard(Question q, {required bool includeAnswer}) async {
    final text = _buildQuestionTextForCopy(q, includeAnswer: includeAnswer);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final msg = includeAnswer ? '题目与答案已复制' : '题目已复制';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _changeFontSize(AppModel model, double delta) {
    final next = (model.fontSize + delta).clamp(14.0, 32.0);
    model.setFontSize(next);
  }

  void _startFontAdjustRepeat(AppModel model, double delta) {
    _fontAdjustTimer?.cancel();
    _fontAdjustTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      _changeFontSize(model, delta);
    });
  }

  void _stopFontAdjustRepeat() {
    _fontAdjustTimer?.cancel();
    _fontAdjustTimer = null;
  }

  Widget _buildFontAdjustControl({
    required AppModel model,
    required IconData icon,
    required String tooltip,
    required double delta,
  }) {
    return GestureDetector(
      onLongPressStart: (_) => _startFontAdjustRepeat(model, delta),
      onLongPressEnd: (_) => _stopFontAdjustRepeat(),
      onLongPressCancel: _stopFontAdjustRepeat,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => _changeFontSize(model, delta),
        icon: Icon(icon),
      ),
    );
  }

  bool _isOptionLine(String line) {
    return RegExp(r'^\s*[A-Fa-f][\.、\)]\s*').hasMatch(line);
  }

  String? _extractOptionLabel(String line, int fallbackIndex) {
    final match = RegExp(r'^\s*([A-Fa-f])[\.、\)]\s*').firstMatch(line);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }
    if (fallbackIndex >= 0 && fallbackIndex < 6) {
      return String.fromCharCode('A'.codeUnitAt(0) + fallbackIndex);
    }
    return null;
  }

  String _trimOptionPrefix(String line) {
    return line.replaceFirst(RegExp(r'^\s*[A-Fa-f][\.、\)]\s*'), '').trim();
  }

  List<({String label, String text})> _extractOptions(Question q) {
    final options = <({String label, String text})>[];
    final rawOptions = q.optionsZh;

    if (rawOptions != null && rawOptions.isNotEmpty) {
      for (var i = 0; i < rawOptions.length; i++) {
        final line = rawOptions[i].trim();
        if (line.isEmpty) continue;
        final label = _extractOptionLabel(line, i);
        if (label == null) continue;
        final text = _trimOptionPrefix(line);
        options.add((label: label, text: text.isEmpty ? line : text));
      }
      if (options.isNotEmpty) return options;
    }

    final stem = q.stemZh ?? '';
    for (final raw in stem.split('\n')) {
      final line = raw.trim();
      if (!_isOptionLine(line)) continue;
      final label = _extractOptionLabel(line, options.length);
      if (label == null) continue;
      final text = _trimOptionPrefix(line);
      options.add((label: label, text: text.isEmpty ? line : text));
    }
    return options;
  }

  String _buildStemWithoutOptions(String? stem) {
    if (stem == null || stem.trim().isEmpty) return '';
    final lines = stem.split('\n');
    final kept = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (_isOptionLine(line)) break;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  String _normalizeAnswerLetters(String? raw) {
    if (raw == null) return '';
    return RegExp(r'[A-Fa-f]')
        .allMatches(raw)
        .map((m) => m.group(0)!.toUpperCase())
        .join();
  }

  Future<void> _maybeCelebrateMilestone({
    required int beforeAnswered,
    required int afterAnswered,
  }) async {
    final beforeMilestone = beforeAnswered ~/ 10;
    final afterMilestone = afterAnswered ~/ 10;
    if (afterMilestone <= beforeMilestone || afterMilestone == 0) return;

    final milestone = afterMilestone * 10;
    if (_lastEncouragedMilestone == milestone) return;

    final candidates = List<int>.generate(_encouragementMessages.length, (i) => i)
        .where((i) => i != _lastEncouragementIndex)
        .toList();
    final pool = candidates.isEmpty ? [0] : candidates;
    final picked = pool[DateTime.now().microsecondsSinceEpoch % pool.length];

    _lastEncouragedMilestone = milestone;
    _lastEncouragementIndex = picked;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text('已完成 $milestone 题，${_encouragementMessages[picked]}'),
      ),
    );
  }

  Future<void> _handleOptionAnswer(AppModel model, Question q, String optionLabel) async {
    final beforeAnswered = model.answeredQuestionCount;
    final normalizedCorrect = _normalizeAnswerLetters(q.correctAnswer);
    final isCorrect = normalizedCorrect.length == 1 && normalizedCorrect == optionLabel;

    if (mounted) {
      setState(() {
        _lastAnsweredQuestionId = q.id;
        _lastSelectedOption = optionLabel;
        _lastAnswerCorrect = isCorrect;
      });
    }

    model.showAnswer();
    await _markAndMaybeNext(model, isCorrect ? 'Know' : 'DontKnow');

    final afterAnswered = model.answeredQuestionCount;
    await _maybeCelebrateMilestone(beforeAnswered: beforeAnswered, afterAnswered: afterAnswered);

    if (!mounted) return;
    final feedback = isCorrect
        ? '回答正确，已自动标记为“会”'
      : '回答错误，已自动标记为“不会”（正确答案：${normalizedCorrect.isEmpty ? '-' : normalizedCorrect}）';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(feedback),
      ),
    );
  }

  @override
  void dispose() {
    _stopFontAdjustRepeat();
    _inputController.dispose();
    _scrollController.dispose();
    _jumpController.dispose();
    _aiInputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion(
    AppModel model,
    Question q,
    String text, {
    bool includeQuestionContext = true,
  }) async {
    final t = text.trim();
    if (t.isEmpty || _askingAi) return;

    _refreshAiPanelUi(() {
      _askingAi = true;
      // On mobile, collapse quick prompts after first ask to free reading area.
      if (MediaQuery.of(context).size.width < 760) {
        _aiQuickPromptsExpanded = false;
      }
    });

    await model.appendToCurrentChatHistory('\n### 用户（题号: ${q.qNum ?? '-'}）\n$t\n\n');
    await model.appendToCurrentChatHistory('> 系统：正在请求 ${model.aiProvider.toUpperCase()}...\n\n');

    final prompt = includeQuestionContext
      ? _buildPrompt(q, t)
      : '''
  用户提问：$t

  请按以下要求回答：
  1) 先给结论，再给理由；
  2) 用简洁中文，必要时括号补英文术语；
  3) 回答要可执行，不要空泛。
  ''';

    try {
      final reply = await AiClient.ask(
        provider: model.aiProvider,
        apiKey: model.apiKey,
        prompt: prompt,
        model: model.aiModel,
        baseUrl: model.aiBaseUrl,
      );
      if (!mounted) return;
      await model.appendToCurrentChatHistory('### AI 回复\n$reply\n\n---\n');
    } catch (e) {
      if (!mounted) return;
      await model.appendToCurrentChatHistory('### 错误\n$e\n\n---\n');
    } finally {
      if (mounted) {
        _refreshAiPanelUi(() {
          _askingAi = false;
        });
      }
    }

    _inputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _buildPrompt(Question q, String userQuestion) {
    final zhOptions = q.optionsZh?.join('\n') ?? '';
    final enOptions = q.optionsEn?.join('\n') ?? '';
    return '''
用户提问：$userQuestion

题号：${q.qNum ?? '-'}

中文题干：
${q.stemZh ?? ''}

中文选项：
$zhOptions

英文题干：
${q.stemEn ?? ''}

英文选项：
$enOptions

参考答案：${q.correctAnswer ?? ''}


请按以下要求回答：
1) 先给结论，再给理由；
2) 用简洁中文，必要时括号补英文术语；
3) 如果用户问“为什么”，请对错误选项做简短排除。
''';
  }

  List<Map<String, String>> _parseAiHistory(String history) {
    final items = <Map<String, String>>[];
    String role = '';
    final buffer = StringBuffer();

    void flush() {
      final text = buffer.toString().trim();
      if (role.isNotEmpty && text.isNotEmpty) {
        items.add({'role': role, 'text': text});
      }
      buffer.clear();
    }

    for (final rawLine in history.split('\n')) {
      final line = rawLine.trimRight();
      if (line.startsWith('### 用户')) {
        flush();
        role = 'user';
        continue;
      }
      if (line.startsWith('### AI 回复')) {
        flush();
        role = 'assistant';
        continue;
      }
      if (line.startsWith('### 错误')) {
        flush();
        role = 'error';
        continue;
      }
      if (line.startsWith('> 系统：')) {
        flush();
        items.add({'role': 'system', 'text': line.replaceFirst('> 系统：', '').trim()});
        role = '';
        continue;
      }
      if (line.trim() == '---') {
        flush();
        role = '';
        continue;
      }
      if (role.isNotEmpty) {
        buffer.writeln(line);
      }
    }
    flush();
    return items;
  }

  List<Map<String, String>> _getParsedAiHistoryCached(String history) {
    if (_cachedAiHistoryRaw == history) {
      return _cachedAiMessages;
    }
    final parsed = _parseAiHistory(history);
    _cachedAiHistoryRaw = history;
    _cachedAiMessages = parsed;
    return parsed;
  }

  Widget _buildAiBubbleHistory(AppModel model) {
    final messages = _getParsedAiHistoryCached(model.currentChatHistory);
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          '暂无对话历史',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final role = msg['role'] ?? 'assistant';
        final text = msg['text'] ?? '';
        final isUser = role == 'user';
        final isSystem = role == 'system';
        final isError = role == 'error';

        Alignment align = Alignment.centerLeft;
        Color bg = Colors.blueGrey.shade50;
        Color fg = Colors.black87;
        String title = 'AI';

        if (isUser) {
          align = Alignment.centerRight;
          bg = Colors.blue.shade600;
          fg = Colors.white;
          title = '你';
        } else if (isSystem) {
          align = Alignment.center;
          bg = Colors.orange.shade100;
          fg = Colors.orange.shade900;
          title = '系统';
        } else if (isError) {
          align = Alignment.centerLeft;
          bg = Colors.red.shade50;
          fg = Colors.red.shade900;
          title = '错误';
        }

        return Align(
          alignment: align,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isSystem ? 320 : 360,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownBody(
                    selectable: true,
                    data: text,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(color: fg, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiPanel(
    AppModel model,
    Question q, {
    bool bubbleMode = false,
    bool showAttachSwitch = false,
  }) {
    final hasKey = model.apiKey.trim().isNotEmpty;
    final canAsk = hasKey && !_askingAi;
    final showQuickPrompts = !bubbleMode || _aiQuickPromptsExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('AI 提问', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('提供者: ${model.aiProvider}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        if (!hasKey)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 6),
            child: Text('请先在设置中填写 API Key 后再使用 AI 提问。', style: TextStyle(color: Colors.red)),
          ),
        if (bubbleMode)
          Row(
            children: [
              Text(
                '快捷提问',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _refreshAiPanelUi(() {
                    _aiQuickPromptsExpanded = !_aiQuickPromptsExpanded;
                  });
                },
                icon: Icon(
                  _aiQuickPromptsExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_aiQuickPromptsExpanded ? '收起' : '展开'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: !showQuickPrompts
                ? const SizedBox.shrink()
                : Wrap(
                    key: const ValueKey('quickPromptsExpanded'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: bubbleMode
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                              : null,
                        ),
                        onPressed: canAsk
                            ? () => _sendQuestion(
                                  model,
                                  q,
                                  '这题用到了什么知识？',
                                  includeQuestionContext: _attachQuestionContext,
                                )
                            : null,
                        child: const Text('这题用到了什么知识？'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: bubbleMode
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                              : null,
                        ),
                        onPressed: canAsk
                            ? () => _sendQuestion(
                                  model,
                                  q,
                                  '请用通俗中文解释这道题在问什么，并指出关键词。',
                                  includeQuestionContext: _attachQuestionContext,
                                )
                            : null,
                        child: const Text('这道题是什么意思？'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: bubbleMode
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                              : null,
                        ),
                        onPressed: canAsk
                            ? () => _sendQuestion(
                                  model,
                                  q,
                                  '为什么是这个结果？',
                                  includeQuestionContext: _attachQuestionContext,
                                )
                            : null,
                        child: const Text('为什么是这个结果？'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: bubbleMode
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                              : null,
                        ),
                        onPressed: canAsk
                            ? () => _sendQuestion(
                                  model,
                                  q,
                                  '请用更简单、面向初学者的方式重讲，并给一个生活类比',
                                  includeQuestionContext: _attachQuestionContext,
                                )
                            : null,
                        child: const Text('我没看懂，能更简单吗？'),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (showAttachSwitch)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('关联当前题目内容'),
            subtitle: const Text('关闭后仅按你的文字提问'),
            value: _attachQuestionContext,
            onChanged: (v) {
              _refreshAiPanelUi(() {
                _attachQuestionContext = v;
              });
            },
          ),
        if (!bubbleMode)
          TextField(
            controller: _inputController,
            focusNode: _aiInputFocusNode,
            decoration: const InputDecoration(
              labelText: '自定义问题',
              hintText: '输入提问后回车',
              border: OutlineInputBorder(),
            ),
            enabled: hasKey,
            onSubmitted: (v) => _sendQuestion(
              model,
              q,
              v,
              includeQuestionContext: _attachQuestionContext,
            ),
          ),
        const SizedBox(height: 8),
        if (_askingAi) const LinearProgressIndicator(),
        if (_askingAi) const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => model.clearCurrentChatHistory(),
            child: const Text('清空历史'),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: bubbleMode
                ? _buildAiBubbleHistory(model)
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: MarkdownBody(
                      selectable: true,
                      data: model.currentChatHistory.trim().isEmpty
                          ? '_暂无对话历史_'
                          : model.currentChatHistory,
                    ),
                  ),
          ),
        ),
        if (bubbleMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _aiInputFocusNode,
                  decoration: const InputDecoration(
                    labelText: '自定义问题',
                    hintText: '输入问题...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  enabled: hasKey,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => _sendQuestion(
                    model,
                    q,
                    v,
                    includeQuestionContext: _attachQuestionContext,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '发送',
                onPressed: canAsk
                    ? () => _sendQuestion(
                          model,
                          q,
                          _inputController.text,
                          includeQuestionContext: _attachQuestionContext,
                        )
                    : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openAiBottomSheet(AppModel model, Question q) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, bottomSheetSetState) {
              _aiBottomSheetSetState = bottomSheetSetState;
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: model.currentChatHistory.trim().isNotEmpty ? 0.9 : 0.78,
                minChildSize: 0.48,
                maxChildSize: 0.98,
                builder: (context, _) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                  return ListenableBuilder(
                    listenable: model,
                    builder: (context, __) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
                        child: _buildAiPanel(
                          model,
                          q,
                          bubbleMode: true,
                          showAttachSwitch: true,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      _aiBottomSheetSetState = null;
    }
  }

  Widget _buildQuestionPanel(
    AppModel model,
    Question q, {
    bool compact = false,
    bool showKeyboardHint = true,
  }) {
    final displayFilter = _filterModeToDisplay[model.filterMode] ?? '所有';
    final statusText = _statusDisplay[model.currentStatus] ?? '未标记';
    final statusColor = _statusColor(model.currentStatus);
    final isKnowSelected = model.currentStatus == 'Know';
    final isDontKnowSelected = model.currentStatus == 'DontKnow';
    final isFavoriteSelected = model.currentStatus == 'Favorite';
    final stemBody = _buildStemWithoutOptions(q.stemZh);
    final displayOptions = _extractOptions(q);
    final hasLastAnswerState = _lastAnsweredQuestionId == q.id && _lastAnswerCorrect != null;
    final questionHeadline = '题号 ${q.qNum ?? '-'}';
    final compactHeadline = '题号 ${q.qNum ?? '-'}';
    final headerCollapsed = compact && _compactHeaderCollapsed;
    final answerText =
        '正确答案：${q.correctAnswer ?? '(空)'}\n';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) => _handleQuestionHorizontalSwipe(model, details),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (compact)
          Row(
            children: [
              Expanded(
                child: Text(
                  compactHeadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: model.fontSize),
                ),
              ),
              if (_wrongLoopMode)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '错题循环中',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: (model.fontSize - 8).clamp(10, 13).toDouble(),
                    ),
                  ),
                ),
              IconButton(
                tooltip: '上一题',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _prevQuestion(model),
              ),
              IconButton(
                tooltip: '下一题',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _nextQuestion(model),
              ),
              IconButton(
                tooltip: headerCollapsed ? '展开题目信息' : '折叠题目信息',
                onPressed: () {
                  setState(() {
                    _compactHeaderCollapsed = !_compactHeaderCollapsed;
                  });
                },
                icon: Icon(headerCollapsed ? Icons.unfold_more : Icons.unfold_less),
              ),
            ],
          ),
        if (!headerCollapsed)
          if (!compact)
            Row(
              children: [
                const Text('筛选：'),
                DropdownButton<String>(
                  value: displayFilter,
                  items: _filterDisplayToMode.keys
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final mode = _filterDisplayToMode[v] ?? 'All';
                      model.setFilterMode(mode);
                    }
                  },
                ),
                const SizedBox(width: 16),
                const Text('错题循环'),
                Checkbox(
                  value: _wrongLoopMode,
                  onChanged: (v) {
                    _toggleWrongLoopMode(model, v ?? false);
                  },
                ),
                const SizedBox(width: 8),
                const Text('随机'),
                Checkbox(
                  value: model.randomOrder,
                  onChanged: (v) {
                    model.setRandomOrder(v ?? false);
                  },
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _jumpController,
                    decoration: const InputDecoration(
                      hintText: '题号',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _handleJump(model),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _handleJump(model),
                  child: const Text('跳转'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _confirmClearProgress(model),
                  child: const Text('清空刷题记录'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('筛选：'),
                    DropdownButton<String>(
                      value: displayFilter,
                      items: _filterDisplayToMode.keys
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final mode = _filterDisplayToMode[v] ?? 'All';
                          model.setFilterMode(mode);
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('错题循环'),
                    Checkbox(
                      value: _wrongLoopMode,
                      onChanged: (v) {
                        _toggleWrongLoopMode(model, v ?? false);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('随机'),
                    Checkbox(
                      value: model.randomOrder,
                      onChanged: (v) {
                        model.setRandomOrder(v ?? false);
                      },
                    ),
                  ],
                ),
                SizedBox(
                  width: 86,
                  child: TextField(
                    controller: _jumpController,
                    decoration: const InputDecoration(
                      hintText: '题号',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _handleJump(model),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _handleJump(model),
                  child: const Text('跳转'),
                ),
                OutlinedButton(
                  onPressed: () => _confirmClearProgress(model),
                  child: const Text('清空记录'),
                ),
              ],
            ),
        if (!compact)
          Row(
            children: [
              Expanded(
                child: Text(
                  questionHeadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: model.fontSize),
                ),
              ),
              if (_wrongLoopMode)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '错题循环中',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: (model.fontSize - 7).clamp(10, 14).toDouble(),
                    ),
                  ),
                ),
              IconButton(
                tooltip: '上一题',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _prevQuestion(model),
              ),
              IconButton(
                tooltip: '下一题',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _nextQuestion(model),
              ),
            ],
          ),
        if (compact && !headerCollapsed)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '字号 ${model.fontSize.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: (model.fontSize - 6).clamp(11, 16).toDouble(),
                  color: Colors.grey.shade700,
                ),
              ),
              _buildFontAdjustControl(
                model: model,
                icon: Icons.remove,
                tooltip: '缩小题干字体（长按连续）',
                delta: -1,
              ),
              _buildFontAdjustControl(
                model: model,
                icon: Icons.add,
                tooltip: '放大题干字体（长按连续）',
                delta: 1,
              ),
            ],
          ),
        if (!headerCollapsed)
          Text(
            '状态：$statusText',
            style: TextStyle(
              fontSize: model.fontSize,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (showKeyboardHint)
          Semantics(
            label: '键盘快捷键提示',
            child: Text(
              _keyboardHint,
              style: TextStyle(
                fontSize: (model.fontSize - 8).clamp(10, 14).toDouble(),
                color: Colors.grey.shade700,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stemBody.isNotEmpty)
                    Text('【中文题干】\n$stemBody\n', style: TextStyle(fontSize: model.fontSize)),
                  if (displayOptions.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '【中文选项】',
                          style: TextStyle(
                            fontSize: model.fontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...displayOptions.map((opt) {
                          final isSelected = _lastAnsweredQuestionId == q.id && _lastSelectedOption == opt.label;
                          final selectedColor = (_lastAnswerCorrect ?? false)
                              ? Colors.green.shade100
                              : Colors.red.shade100;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSelected ? selectedColor : null,
                                side: BorderSide(
                                  color: isSelected
                                      ? ((_lastAnswerCorrect ?? false)
                                          ? Colors.green.shade400
                                          : Colors.red.shade400)
                                      : Colors.black26,
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _handleOptionAnswer(model, q, opt.label),
                              child: Text(
                                '${opt.label}. ${opt.text}',
                                style: TextStyle(fontSize: model.fontSize - 1),
                              ),
                            ),
                          );
                        }),
                        if (hasLastAnswerState)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_lastAnswerCorrect ?? false)
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_lastAnswerCorrect ?? false)
                                    ? Colors.green.shade300
                                    : Colors.red.shade300,
                              ),
                            ),
                            child: Text(
                              (_lastAnswerCorrect ?? false)
                                  ? '本题回答正确，已自动标记为“会”'
                                  : '本题回答错误，已自动标记为“不会”',
                              style: TextStyle(
                                color: (_lastAnswerCorrect ?? false)
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (q.stemEn != null)
                    Text('【English Stem】\n${q.stemEn}\n', style: TextStyle(fontSize: model.fontSize)),
                  if (q.optionsEn != null)
                    Text('【English Options】\n${q.optionsEn!.join('\n')}\n',
                        style: TextStyle(fontSize: model.fontSize)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (model.currentStatus != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              border: Border.all(color: statusColor.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  '当前题已标记：$statusText',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: model.showAnswer,
              child: const Text('答案'),
            ),
            OutlinedButton(
              onPressed: () => _copyQuestionToClipboard(q, includeAnswer: false),
              child: const Text('复制题目'),
            ),
            OutlinedButton(
              onPressed: () => _copyQuestionToClipboard(q, includeAnswer: true),
              child: const Text('复制题目+答案'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isKnowSelected ? Colors.green.shade800 : Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => _markAndMaybeNext(model, 'Know'),
              child: Text(isKnowSelected ? '会 ✓' : '会'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDontKnowSelected ? Colors.red.shade800 : Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => _markAndMaybeNext(model, 'DontKnow'),
              child: Text(isDontKnowSelected ? '不会 ✓' : '不会'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFavoriteSelected ? Colors.amber.shade700 : Colors.amber.shade600,
                foregroundColor: Colors.black87,
                shape: const StadiumBorder(),
              ),
              onPressed: () => _markAndMaybeNext(model, 'Favorite'),
              child: Text(isFavoriteSelected ? '收藏 ✓' : '收藏'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (model.answerVisible)
          SelectionArea(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(answerText, style: TextStyle(fontSize: model.fontSize - 1)),
            ),
          ),
          ],
        ),
    );
  }

  void _handleJump(AppModel model) {
    final raw = _jumpController.text.trim();
    final num = int.tryParse(raw);
    if (num == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效题号')));
      return;
    }
    final targetIndex = num - 1;
    _questionNavDirection = targetIndex >= model.currentIndex ? 1 : -1;
    final ok = model.jumpToNumber(num);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('题号超出范围')));
      return;
    }
    _jumpController.clear();
  }

  Future<void> _confirmClearProgress(AppModel model) async {
    final yes1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认'),
        content: const Text('此操作将清除所有刷题记录，无法恢复。继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续')),
        ],
      ),
    );
    if (yes1 != true) return;
    if (!mounted) return;

    final yes2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('再确认'),
        content: const Text('真的确定要清除所有记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (yes2 != true) return;

    await model.clearProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刷题记录已清空')));
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('正在加载题库，请稍候...'),
        ],
      ),
    );
  }

  Widget _buildWebErrorState(AppModel model) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('题库加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('当前 Web 环境下题库数据无法打开，请检查网络或静态资源部署。'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: model.loadQuestions,
                  child: const Text('重试加载'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppModel model) {
    final isFiltered = model.filterMode != 'All';
    final message = isFiltered ? '当前筛选下暂无题目。' : '题库为空，请检查数据文件。';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: model.loadQuestions,
                      child: const Text('重新加载题库'),
                    ),
                    if (isFiltered)
                      OutlinedButton(
                        onPressed: () => model.setFilterMode('All'),
                        child: const Text('清除筛选'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedQuestionPanel(
    AppModel model,
    Question q, {
    bool compact = false,
    bool showKeyboardHint = true,
  }) {
    final beginOffset = _questionNavDirection >= 0
        ? const Offset(0.09, 0)
        : const Offset(-0.09, 0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(q.id),
        child: _buildQuestionPanel(
          model,
          q,
          compact: compact,
          showKeyboardHint: showKeyboardHint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AppModel>(context);
    if (model.webError) return _buildWebErrorState(model);

    if (!model.questionsLoaded) return _buildLoadingState();

    final q = model.currentQuestion;
    if (q == null) return _buildEmptyState(model);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => _runShortcutIfReady(() => _prevQuestion(model)),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _runShortcutIfReady(() => _nextQuestion(model)),
          const SingleActivator(LogicalKeyboardKey.keyA): () => _runShortcutIfReady(model.showAnswer),
          const SingleActivator(LogicalKeyboardKey.keyK):
              () => _runShortcutIfReady(() => _markAndMaybeNext(model, 'Know')),
          const SingleActivator(LogicalKeyboardKey.keyD):
              () => _runShortcutIfReady(() => _markAndMaybeNext(model, 'DontKnow')),
          const SingleActivator(LogicalKeyboardKey.keyF):
              () => _runShortcutIfReady(() => _markAndMaybeNext(model, 'Favorite')),
          const SingleActivator(LogicalKeyboardKey.slash):
              () => _runShortcutIfReady(() => _focusAiInput(model)),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            final compact = constraints.maxWidth < 760;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildAnimatedQuestionPanel(model, q),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildAiPanel(model, q)),
                  ],
                ),
              );
            }

            if (compact) {
              final hasHistory = model.currentChatHistory.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildAnimatedQuestionPanel(
                        model,
                        q,
                        compact: true,
                        showKeyboardHint: false,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: FloatingActionButton.extended(
                        onPressed: () => _openAiBottomSheet(model, q),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(hasHistory ? 'AI 对话' : 'AI 提问'),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildAnimatedQuestionPanel(
                      model,
                      q,
                      compact: true,
                      showKeyboardHint: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(flex: 4, child: _buildAiPanel(model, q)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AppModel>(context);
    final total = model.allQuestions.length;

    return FutureBuilder<Map<String, dynamic>>(
      future: _computeAnalytics(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = (snap.data?['stats'] as Map<String, int>?) ?? const <String, int>{};
        final wrongTrend = (snap.data?['wrongTrend'] as Map<String, int>?) ?? const <String, int>{};
        final favoriteHotspots = (snap.data?['favoriteHotspots'] as List<Map<String, dynamic>>?) ?? const <Map<String, dynamic>>[];
        final know = stats['Know'] ?? 0;
        final dont = stats['DontKnow'] ?? 0;
        final fav = stats['Favorite'] ?? 0;
        final knownRate = total > 0 ? (know / total * 100) : 0.0;
        final dontRate = total > 0 ? (dont / total * 100) : 0.0;
        final favRate = total > 0 ? (fav / total * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('共 $total 题'),
              Text('会: $know    不会: $dont    收藏: $fav'),
              const SizedBox(height: 8),
              Text('状态占比：会 ${knownRate.toStringAsFixed(1)}%  ｜ 不会 ${dontRate.toStringAsFixed(1)}%  ｜ 收藏 ${favRate.toStringAsFixed(1)}%'),
              const SizedBox(height: 12),
              const Text('最近 7 天错题趋势（按“标记不会”次数）', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (wrongTrend.isEmpty)
                const Text('暂无错题标记记录')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: wrongTrend.entries
                      .map((e) => Chip(label: Text('${e.key}: ${e.value} 次')))
                      .toList(),
                ),
              const SizedBox(height: 12),
              const Text('收藏高频点（最近累计）', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (favoriteHotspots.isEmpty)
                const Text('暂无收藏高频题')
              else
                ...favoriteHotspots.map(
                  (item) => Text(
                    '题号 ${item['q_num'] ?? '-'} · 收藏 ${item['c'] ?? 0} 次 · ${_shortStem(item['stem_zh']?.toString() ?? '')}',
                  ),
                ),
              const SizedBox(height: 16),
              const Text('题目概览：'),
              Expanded(child: _buildOverviewGrid(context, model)),
            ],
          ),
        );
      },
    );
  }

  String _shortStem(String stem) {
    final s = stem.trim();
    if (s.isEmpty) return '(无题干)';
    if (s.length <= 36) return s;
    return '${s.substring(0, 36)}...';
  }

  Future<Map<String, dynamic>> _computeAnalytics() async {
    final stats = await AppDatabase.countByStatus();
    final trendRaw = await AppDatabase.recentDontKnowTrend(days: 7);
    final favoriteHotspots = await AppDatabase.topFavoriteHotspots(limit: 5);

    final sortedTrendEntries = trendRaw.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final trend = <String, int>{};
    for (final entry in sortedTrendEntries) {
      trend[entry.key] = entry.value;
    }

    return {
      'stats': stats,
      'wrongTrend': trend,
      'favoriteHotspots': favoriteHotspots,
    };
  }

  Widget _buildOverviewGrid(BuildContext context, AppModel model) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final cross = (cons.maxWidth / 40).floor().clamp(4, 20);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross),
          itemCount: model.allQuestions.length,
          itemBuilder: (ctx, idx) {
            final q = model.allQuestions[idx];
            final status = model.statusByQuestionId[q.id];
            Color bg = Colors.grey.shade300;
            if (status == 'Know') bg = Colors.green.shade400;
            if (status == 'DontKnow') bg = Colors.red.shade400;
            if (status == 'Favorite') bg = Colors.yellow.shade600;

            return InkWell(
              onTap: () async {
                await model.jumpToQuestionIdFromOverview(q.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                color: bg,
                child: Text('${idx + 1}${status == 'Favorite' ? ' ★' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _randomSeedController = TextEditingController();
  Timer? _autoSaveTimer;
  String _provider = 'deepseek';
  String _model = 'deepseek-chat';
  String _filterMode = 'All';
  double _fontSize = 20;
  bool _autoNextAfterMark = false;
  bool _randomOrder = false;

  static const Map<String, List<String>> _modelOptions = {
    'deepseek': ['deepseek-chat', 'deepseek-reasoner'],
    'openai': ['gpt-4o-mini', 'gpt-4o', 'o4-mini'],
  };

  List<String> _optionsForProvider(String provider) {
    final options = List<String>.from(_modelOptions[provider] ?? const <String>[]);
    if (_model.trim().isNotEmpty && !options.contains(_model.trim())) {
      options.add(_model.trim());
    }
    return options;
  }

  String _defaultModelFor(String provider) {
    switch (provider) {
      case 'openai':
        return 'gpt-4o-mini';
      case 'deepseek':
      default:
        return 'deepseek-chat';
    }
  }

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppModel>(context, listen: false);
    _provider = model.aiProvider;
    _model = model.aiModel;
    _keyController.text = model.getProviderKey(_provider);
    _baseUrlController.text = model.aiBaseUrl;
    _fontSize = model.fontSize;
    _autoNextAfterMark = model.autoNextAfterMark;
    _filterMode = model.filterMode;
    _randomOrder = model.randomOrder;
    _randomSeedController.text = model.randomSeed.toString();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _keyController.dispose();
    _baseUrlController.dispose();
    _randomSeedController.dispose();
    super.dispose();
  }

  void _scheduleAutoSave({bool immediate = false}) {
    _autoSaveTimer?.cancel();
    if (immediate) {
      unawaited(_persistPrefs());
      return;
    }
    _autoSaveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistPrefs());
    });
  }

  Future<void> _persistPrefs() async {
    final model = Provider.of<AppModel>(context, listen: false);
    final seed = int.tryParse(_randomSeedController.text.trim());
    final validSeed = seed != null && seed > 0;

    await model.applySettings(
      provider: _provider,
      key: _keyController.text.trim(),
      model: _model.trim().isEmpty ? _defaultModelFor(_provider) : _model.trim(),
      baseUrl: _baseUrlController.text.trim(),
      font: _fontSize,
      autoNext: _autoNextAfterMark,
    );
    if (model.filterMode != _filterMode) {
      await model.setFilterMode(_filterMode);
    }
    if (model.randomOrder != _randomOrder) {
      await model.setRandomOrder(_randomOrder);
    }
    if (validSeed && model.randomSeed != seed) {
      await model.setRandomSeed(seed);
    }
  }

  void _generateRandomSeedByNow() {
    final nowSeed = (DateTime.now().millisecondsSinceEpoch & 0x7fffffff).clamp(1, 0x7fffffff);
    _randomSeedController.text = nowSeed.toString();
    setState(() {});
    _scheduleAutoSave(immediate: true);
  }

  Future<void> _clearAllChatHistoryWithTripleConfirm() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('将清空所有题目的 AI 对话历史，且不可恢复。继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('继续')),
        ],
      ),
    );
    if (step1 != true) return;
    if (!mounted) return;

    final step2 = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('二次确认'),
        content: const Text('再次提醒：此操作不可恢复，所有题目的历史都会删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('继续')),
        ],
      ),
    );
    if (step2 != true) return;
    if (!mounted) return;

    final step3 = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('最终确认'),
        content: const Text('最后确认：立即清空全部对话历史（不可恢复）？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('立即清空')),
        ],
      ),
    );
    if (step3 != true) return;
    if (!mounted) return;

    final model = Provider.of<AppModel>(context, listen: false);
    await model.clearAllChatHistories();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所有对话历史已清空')));
  }

  Future<void> _exportAllChatHistoriesJson() async {
    final model = Provider.of<AppModel>(context, listen: false);
    final jsonText = await model.exportAllChatHistoriesJson();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('导出对话历史 JSON'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(jsonText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('导出 JSON 已复制到剪贴板')),
                );
              }
            },
            child: const Text('复制 JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _importAllChatHistoriesJson() async {
    final model = Provider.of<AppModel>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final inputController = TextEditingController();
    bool clearExisting = false;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('导入对话历史 JSON'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请粘贴导出的 JSON 内容。'),
                const SizedBox(height: 8),
                TextField(
                  controller: inputController,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '{"chat_histories": {"1": "..."}}',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: clearExisting,
                      onChanged: (v) => setStateDialog(() => clearExisting = v ?? false),
                    ),
                    const Expanded(child: Text('导入前清空当前所有对话历史')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop({
                  'json': inputController.text,
                  'clear_existing': clearExisting,
                });
              },
              child: const Text('开始导入'),
            ),
          ],
        ),
      ),
    );

    inputController.dispose();

    if (payload == null) return;

    try {
      final stats = await model.importAllChatHistoriesJson(
        (payload['json'] ?? '').toString(),
        clearExisting: payload['clear_existing'] == true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：成功 ${stats['imported']} 条，跳过 ${stats['skipped']} 条，当前总计 ${stats['total_after_import']} 条',
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：${e.message}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 提供者'),
            DropdownButton<String>(
              value: _provider,
              items: const [
                DropdownMenuItem(value: 'deepseek', child: Text('Deepseek')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _provider = v;
                    _keyController.text =
                        Provider.of<AppModel>(context, listen: false).getProviderKey(_provider);
                    final opts = _optionsForProvider(v);
                    if (opts.isNotEmpty && !opts.contains(_model)) {
                      _model = _defaultModelFor(v);
                    }
                  });
                  _scheduleAutoSave();
                }
              },
            ),
            const SizedBox(height: 8),
            const Text('模型'),
            DropdownButton<String>(
              value: _model,
              isExpanded: true,
              items: _optionsForProvider(_provider)
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _model = v);
                  _scheduleAutoSave();
                }
              },
            ),
            const SizedBox(height: 8),
            const Text('自定义 Base URL（可选）'),
            TextField(
              controller: _baseUrlController,
              onChanged: (_) => _scheduleAutoSave(),
              decoration: const InputDecoration(
                hintText: '例如 https://api.deepseek.com 或 OpenAI 兼容网关地址',
              ),
            ),
            const SizedBox(height: 8),
            const Text('API Key'),
            TextField(
              controller: _keyController,
              onChanged: (_) {
                setState(() {});
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _keyController.text.trim().isNotEmpty ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: _keyController.text.trim().isNotEmpty
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _keyController.text.trim().isNotEmpty
                      ? '当前 Key 将保存到系统安全存储'
                      : '未填写 Key（会自动写入系统安全存储）',
                  style: TextStyle(
                    fontSize: 12,
                    color: _keyController.text.trim().isNotEmpty
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('字体大小'),
            Slider(
              value: _fontSize,
              min: 8,
              max: 24,
              divisions: 16,
              label: _fontSize.toStringAsFixed(0),
              onChanged: (v) => setState(() => _fontSize = v),
              onChangeEnd: (_) => _scheduleAutoSave(),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '字体预览：这是一道 AWS SAA 题目的示例文本（EC2 / S3 / IAM）',
                style: TextStyle(fontSize: _fontSize),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('标记后自动下一题（仅 All 筛选时生效）')),
                Checkbox(
                  value: _autoNextAfterMark,
                  onChanged: (v) {
                    setState(() => _autoNextAfterMark = v ?? false);
                    _scheduleAutoSave();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('默认筛选'),
            DropdownButton<String>(
              value: _filterMode,
              items: ['All', 'Know', 'DontKnow', 'Favorite']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _filterMode = v;
                  });
                  _scheduleAutoSave();
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('随机顺序'),
                Checkbox(
                  value: _randomOrder,
                  onChanged: (v) {
                    setState(() {
                      _randomOrder = v ?? false;
                    });
                    _scheduleAutoSave();
                  },
                ),
              ],
            ),
            const Text('随机种子（稳定随机，可跨设备迁移）'),
            TextField(
              controller: _randomSeedController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _scheduleAutoSave(),
              decoration: const InputDecoration(
                hintText: '输入正整数，例如 1709876543',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _generateRandomSeedByNow,
                  child: const Text('按当前时间生成'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: _randomSeedController.text.trim()));
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('随机种子已复制')),
                    );
                  },
                  child: const Text('复制种子'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _exportAllChatHistoriesJson,
              child: const Text('导出所有对话历史（JSON）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _importAllChatHistoriesJson,
              child: const Text('导入对话历史（JSON）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearAllChatHistoryWithTripleConfirm,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('清空所有对话历史（不可恢复）'),
            ),
            const SizedBox(height: 8),
            Text(
              '设置会自动保存',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
