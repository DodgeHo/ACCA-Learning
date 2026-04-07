import 'dart:convert';

class Question {
  final int id;
  final String? qNum;
  final String? stemEn;
  final String? stemZh;
  final List<String>? optionsEn;
  final List<String>? optionsZh;
  final String? correctAnswer;
  final String? explanationEn;
  final String? explanationZh;
  final String? sourceDoc;
  final int? sourcePage;

  Question({
    required this.id,
    this.qNum,
    this.stemEn,
    this.stemZh,
    this.optionsEn,
    this.optionsZh,
    this.correctAnswer,
    this.explanationEn,
    this.explanationZh,
    this.sourceDoc,
    this.sourcePage,
  });

  static ({String? cleanedStem, String? extractedAnswer}) _splitAnswerFromZhStem(String? stemZh) {
    if (stemZh == null || stemZh.trim().isEmpty) {
      return (cleanedStem: stemZh, extractedAnswer: null);
    }

    final match = RegExp(
      r'(?:\r?\n|\s)答案[:：]\s*([A-Fa-f][A-Fa-f\s、,，/]*)\s*$',
      multiLine: true,
    ).firstMatch(stemZh);
    if (match == null) {
      return (cleanedStem: stemZh, extractedAnswer: null);
    }

    final extracted = match.group(1)?.trim();
    final cleaned = stemZh.substring(0, match.start).trimRight();
    return (cleanedStem: cleaned, extractedAnswer: extracted);
  }

  static String? _normalizeAnswer(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    final letters = RegExp(r'[A-Fa-f]')
        .allMatches(text)
        .map((m) => m.group(0)!.toUpperCase())
        .join();
    if (letters.isNotEmpty) return letters;
    return text;
  }

  factory Question.fromMap(Map<String, dynamic> m) {
    final rawStemZh = m['stem_zh'] as String?;
    final split = _splitAnswerFromZhStem(rawStemZh);

    final rawCorrect = m['correct_answer'] as String?;
    final normalizedCorrect = _normalizeAnswer(rawCorrect) ?? _normalizeAnswer(split.extractedAnswer);

    return Question(
      id: m['id'] as int,
      qNum: m['q_num'] as String?,
      stemEn: m['stem_en'] as String?,
      stemZh: split.cleanedStem,
      optionsEn: (m['options_en'] != null)
          ? List<String>.from(json.decode(m['options_en']))
          : null,
      optionsZh: (m['options_zh'] != null)
          ? List<String>.from(json.decode(m['options_zh']))
          : null,
      correctAnswer: normalizedCorrect,
      explanationEn: m['explanation_en'] as String?,
      explanationZh: m['explanation_zh'] as String?,
      sourceDoc: m['source_doc'] as String?,
      sourcePage: m['source_page'] as int?,
    );
  }
}
