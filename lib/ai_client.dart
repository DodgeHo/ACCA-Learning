import 'dart:convert';

import 'package:http/http.dart' as http;

class AiClient {
  static Future<String> ask({
    required String provider,
    required String apiKey,
    required String prompt,
    String? model,
    String? baseUrl,
    http.Client? client,
  }) async {
    final trimmedProvider = provider.trim().toLowerCase();
    final trimmedKey = apiKey.trim();

    if (trimmedKey.isEmpty) {
      throw Exception('请先在设置中填写 API Key。');
    }

    final uri = _endpointFor(trimmedProvider, baseUrl: baseUrl);
    final selectedModel = (model ?? '').trim().isEmpty
      ? _defaultModelFor(trimmedProvider)
      : model!.trim();

    final payload = {
      'model': selectedModel,
      'messages': [
        {
          'role': 'system',
          'content': '你是 AWS SAA 学习助手。回答请简洁、结构化、中文优先，必要时补充英文术语。'
        },
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.4,
    };

    final httpClient = client ?? http.Client();
    http.Response response;
    try {
      response = await httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer $trimmedKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI 请求失败(${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = (choices.first as Map<String, dynamic>)['message'];
      if (message is Map<String, dynamic>) {
        final content = message['content'];
        final text = _contentToText(content);
        if (text.isNotEmpty) return text;
      }
    }

    throw Exception('AI 返回格式异常，未解析到有效内容。');
  }

  static Uri _endpointFor(String provider, {String? baseUrl}) {
    final customBase = (baseUrl ?? '').trim();
    if (customBase.isNotEmpty) {
      final normalized = customBase.endsWith('/')
          ? customBase.substring(0, customBase.length - 1)
          : customBase;
      final full = normalized.endsWith('/chat/completions')
          ? normalized
          : '$normalized/chat/completions';
      return Uri.parse(full);
    }

    switch (provider) {
      case 'deepseek':
        return Uri.parse('https://api.deepseek.com/chat/completions');
      case 'openai':
        return Uri.parse('https://api.openai.com/v1/chat/completions');
      default:
        throw Exception('不支持的 AI 提供者: $provider');
    }
  }

  static String _defaultModelFor(String provider) {
    switch (provider) {
      case 'deepseek':
        return 'deepseek-chat';
      case 'openai':
        return 'gpt-4o-mini';
      default:
        return 'deepseek-chat';
    }
  }

  static String _contentToText(dynamic content) {
    if (content == null) return '';
    if (content is String) return content.trim();

    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            parts.add(text.trim());
          }
        }
      }
      return parts.join('\n').trim();
    }

    return content.toString().trim();
  }
}
