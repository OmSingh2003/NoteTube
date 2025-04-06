import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'youtube_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class WhisperService {
  static const String _apiUrl =
      'https://api.lemonfox.ai/v1/audio/transcriptions';
  static String? _apiKey;
  static const int _maxRetries = 3;
  static const int _timeoutSeconds = 300; // 5 minutes timeout
  static const int _maxFileSizeMB = 25;

  static Future<void> initialize() async {
    _apiKey = dotenv.env['LEMONFOX_API_KEY'];
    if (_apiKey == null) {
      throw Exception('LEMONFOX_API_KEY not found in .env file');
    }
    debugPrint('WhisperService initialized successfully');
  }

  static String? get apiKey => _apiKey;

  static Future<void> _validateFile(File file) async {
    if (!file.existsSync()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final fileSizeBytes = await file.length();
    final fileSizeMB = fileSizeBytes / (1024 * 1024);
    if (fileSizeMB > _maxFileSizeMB) {
      throw Exception(
          'File size (${fileSizeMB.toStringAsFixed(1)}MB) exceeds maximum allowed size of ${_maxFileSizeMB}MB');
    }
  }

  static Future<String?> transcribeAudio(File file) async {
    if (_apiKey == null) {
      await initialize();
    }

    await _validateFile(file);
    int retryCount = 0;
    Exception? lastError;

    while (retryCount < _maxRetries) {
      try {
        debugPrint('Attempt ${retryCount + 1} of $_maxRetries');

        var request = http.MultipartRequest('POST', Uri.parse(_apiUrl))
          ..headers['Authorization'] = 'Bearer $_apiKey'
          ..fields['model'] = 'whisper-1'
          ..fields['response_format'] = 'json'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        debugPrint('Sending transcription request...');
        var response = await request.send().timeout(
          Duration(seconds: _timeoutSeconds),
          onTimeout: () {
            throw TimeoutException(
                'Request timed out after $_timeoutSeconds seconds');
          },
        );

        debugPrint('Response status code: ${response.statusCode}');
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final jsonResponse = jsonDecode(responseBody);
          return jsonResponse['text'];
        } else if (response.statusCode == 429) {
          // Rate limit exceeded - wait longer before retry
          await Future.delayed(Duration(seconds: 30 * (retryCount + 1)));
          throw Exception('Rate limit exceeded');
        } else {
          final errorBody = await response.stream.bytesToString();
          throw Exception('API Error: ${response.statusCode} - $errorBody');
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('Error in transcribeAudio (attempt ${retryCount + 1}): $e');

        if (e is TimeoutException ||
            e.toString().contains('Connection reset by peer') ||
            e.toString().contains('Operation timed out')) {
          // Exponential backoff for network-related errors
          await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
          retryCount++;
          continue;
        }

        // For other errors, throw immediately
        rethrow;
      }
    }

    throw Exception(
        'Failed after $_maxRetries attempts. Last error: ${lastError?.toString()}');
  }

  static Future<String> transcribeFromURL(String input) async {
    if (_apiKey == null) {
      await initialize();
    }

    YoutubeExplode yt = YoutubeExplode();
    try {
      String videoId;

      if (input.contains('youtube.com') || input.contains('youtu.be')) {
        // If it's a URL, extract the video ID
        videoId = VideoId.fromString(input).value;
      } else {
        // If it's just an ID, validate it
        videoId =
            VideoId.fromString('https://youtube.com/watch?v=$input').value;
      }

      // Verify the video exists
      final videoInfo = await yt.videos.get(videoId);
      debugPrint('Found video: ${videoInfo.title}');

      debugPrint('Extracting audio from video ID: $videoId');
      final audioFile = await YouTubeService.downloadAudio(videoId);

      if (audioFile == null) {
        throw Exception('Failed to download audio');
      }

      debugPrint('Audio downloaded successfully, now transcribing...');
      final transcription = await transcribeAudio(audioFile);

      if (transcription == null) {
        throw Exception('Failed to transcribe audio');
      }

      return transcription;
    } catch (e) {
      debugPrint('Error in transcribeFromURL: $e');
      if (e is VideoUnplayableException || e is VideoUnavailableException) {
        throw Exception('Invalid YouTube URL or video ID');
      }
      rethrow;
    } finally {
      yt.close();
    }
  }
}
