import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;

class YouTubeService {
  static final _yt = YoutubeExplode();
  
  static Future<String> _getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(path.join(appDir.path, 'NoteTube', 'Downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  static String _extractVideoId(String url) {
    try {
      // Handle both full URLs and video IDs
      if (url.length == 11) return url; // Direct video ID
      
      // Try to extract using the library's method
      final videoId = VideoId.parseVideoId(url);
      if (videoId != null) return videoId;
      
      // Fallback to regex if the library method fails
      RegExp regExp = RegExp(
        r'^.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/|shorts\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*',
      );
      final match = regExp.firstMatch(url);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
      
      throw Exception('Could not extract video ID from URL');
    } catch (e) {
      debugPrint('Error extracting video ID: $e');
      rethrow;
    }
  }

  static Future<File> downloadAudio(String url) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      debugPrint('Downloading audio from YouTube URL: $url');
      
      final videoId = _extractVideoId(url);
      debugPrint('Extracted video ID: $videoId');

      if (videoId.isEmpty) {
        throw Exception('Invalid YouTube URL or video ID');
      }

      // Get video metadata
      final video = await yt.videos.get(videoId);
      debugPrint('Got video metadata: ${video.title}');

      // Get the best audio-only stream
      debugPrint('Getting stream manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      
      // Get all audio streams and sort by bitrate
      final audioStreams = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for this video');
      }

      // Try to find the best audio stream
      AudioOnlyStreamInfo? audioStream;
      
      // First try to find an MP4 audio stream
      for (var stream in audioStreams) {
        if (stream.container == StreamContainer.mp4) {
          audioStream = stream;
          break;
        }
      }
      
      // If no MP4 stream found, use the highest bitrate stream
      audioStream ??= audioStreams.first;
      
      debugPrint('Selected audio stream: ${audioStream.bitrate.toString()} - ${audioStream.container.name}');

      // Create a file name based on the video title
      final fileName = '${video.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.mp3'
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase(); // lowercase to avoid case-sensitivity issues
      final downloadsDir = await _getDownloadsDirectory();
      final filePath = path.join(downloadsDir, fileName);
      debugPrint('Saving to: $filePath');

      // Download the audio
      final file = File(filePath);
      final fileStream = file.openWrite();
      
      // Stream with progress reporting
      final stream = yt.videos.streamsClient.get(audioStream);
      final len = audioStream.size.totalBytes;
      var count = 0;
      
      await for (final data in stream) {
        count += data.length;
        fileStream.add(data);
        final progress = ((count / len) * 100).round();
        debugPrint('Download progress: $progress%');
      }
      
      await fileStream.flush();
      await fileStream.close();

      debugPrint('Download completed: $filePath');
      return file;
    } catch (e, stack) {
      debugPrint('Error downloading YouTube audio: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    } finally {
      // Clean up
      yt?.close();
    }
  }

  static Future<String> getPDFDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(path.join(appDir.path, 'NoteTube', 'PDFs'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir.path;
  }
} 