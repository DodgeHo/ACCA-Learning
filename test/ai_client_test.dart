import 'package:aws_saa_trainer/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AiClient.ask', () {
    test('throws when api key is empty', () async {
      await expectLater(
        () => AiClient.ask(
          provider: 'deepseek',
          apiKey: '   ',
          prompt: 'test',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('API Key'),
          ),
        ),
      );
    });

    test('throws readable error for unsupported provider', () async {
      await expectLater(
        () => AiClient.ask(
          provider: 'unknown-provider',
          apiKey: 'key',
          prompt: 'test',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('不支持的 AI 提供者'),
          ),
        ),
      );
    });

    test('throws readable error for non-2xx response', () async {
      final mockClient = MockClient((_) async {
        return http.Response('{"error":"rate limit"}', 500);
      });

      await expectLater(
        () => AiClient.ask(
          provider: 'deepseek',
          apiKey: 'key',
          prompt: 'test',
          client: mockClient,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('AI 请求失败(500)'),
          ),
        ),
      );
    });

    test('returns parsed content on success response', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          '{"choices":[{"message":{"content":"ok-answer"}}]}',
          200,
        );
      });

      final result = await AiClient.ask(
        provider: 'deepseek',
        apiKey: 'key',
        prompt: 'test',
        client: mockClient,
      );

      expect(result, 'ok-answer');
    });
  });
}
