import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static Future<void> initialize() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }
      debugPrint('Initializing Gemini API with key length: ${apiKey.length}');

      // Test the API with a simple request
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Hello, please respond with "Working" if you can read this.'
                }
              ]
            }
          ]
        }),
      );

      debugPrint('Test response status code: ${response.statusCode}');
      debugPrint('Test response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('API test failed: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing Gemini API: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<String> generateSummary(String text) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }

      debugPrint('Generating summary for text length: ${text.length}');
      final prompt =
          'Create a concise summary of this text in 2-3 sentences:\n\n$text';

      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      debugPrint('Summary response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to generate summary: ${response.body}');
      }

      final jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse['candidates'] as List;
      if (candidates.isEmpty) {
        throw Exception('No response from API');
      }

      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      final summaryText = parts[0]['text'] as String;

      debugPrint('Generated summary length: ${summaryText.length}');
      return summaryText;
    } catch (e, stackTrace) {
      debugPrint('Error generating summary: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to generate summary: $e');
    }
  }

  static Future<List<Map<String, String>>> generateQuizQuestions(
      String text) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }

      debugPrint('Generating quiz for text length: ${text.length}');
      final prompt =
          '''Based on the text below, create 3 quiz questions with answers. 
Return ONLY a JSON array in this exact format, with no additional text:
[
  {"question": "First question?", "answer": "First answer"},
  {"question": "Second question?", "answer": "Second answer"},
  {"question": "Third question?", "answer": "Third answer"}
]

Text to analyze:
$text''';

      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      debugPrint('Quiz response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to generate quiz: ${response.body}');
      }

      final jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse['candidates'] as List;
      if (candidates.isEmpty) {
        throw Exception('No response from API');
      }

      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      final responseText = parts[0]['text'] as String;

      debugPrint('Raw API response: $responseText');

      // Extract the JSON array from the response
      final cleanText = responseText.trim();
      String jsonString;

      if (cleanText.startsWith('[') && cleanText.endsWith(']')) {
        jsonString = cleanText;
      } else {
        final startIndex = cleanText.indexOf('[');
        final endIndex = cleanText.lastIndexOf(']') + 1;

        if (startIndex == -1 || endIndex <= startIndex) {
          throw Exception('Invalid response format from API');
        }
        jsonString = cleanText.substring(startIndex, endIndex);
      }

      debugPrint('Extracted JSON: $jsonString');

      final List<dynamic> questions = jsonDecode(jsonString);
      return questions
          .map((q) => {
                'question': q['question'] as String,
                'answer': q['answer'] as String,
              })
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error generating quiz questions: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to generate quiz questions: $e');
    }
  }
}
