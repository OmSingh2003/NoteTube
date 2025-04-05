import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'services/whisper_service.dart';
import 'utils/pdf_generator.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  // Ensure Flutter is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint("Loading .env file...");
    await dotenv.load();
    debugPrint(".env file loaded successfully");
    debugPrint("API Key present: ${dotenv.env['LEMONFOX_API_KEY'] != null}");
    
    debugPrint("Initializing WhisperService...");
    await WhisperService.initialize();
    debugPrint("WhisperService initialized successfully");
  } catch (e, stackTrace) {
    debugPrint("Error during initialization: $e");
    debugPrint("Stack trace: $stackTrace");
  }
  
  runApp(const NoteTubeApp());
}

class NoteTubeApp extends StatelessWidget {
  const NoteTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoteTube',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String? _transcription;
  final TextEditingController _linkController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<File> _savedPDFs = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPDFs();
  }

  Future<void> _loadSavedPDFs() async {
    final pdfs = await PDFGenerator.getAllPDFs();
    setState(() {
      _savedPDFs = pdfs;
    });
  }

  Future<void> _pickAndTranscribeAudio() async {
    try {
      // Configure file picker to open file manager
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'wma'],
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Select Audio File',
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final file = File(result.files.first.path!);
        final text = await WhisperService.transcribeAudio(file);
        
        if (!mounted) return;

        setState(() {
          _transcription = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _transcribeFromYouTubeLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a YouTube link';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final text = await WhisperService.transcribeFromURL(link);
      
      if (!mounted) return;

      setState(() {
        _transcription = text;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_transcription == null) return;

    try {
      final title = _linkController.text.isNotEmpty
          ? 'YouTube_Transcription'
          : 'Audio_Transcription';
          
      final pdfFile = await PDFGenerator.generatePdf(_transcription!, title: title);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF saved: ${path.basename(pdfFile.path)}"),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _showPDFOptions(pdfFile),
          ),
        ),
      );
      
      _loadSavedPDFs(); // Refresh the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e")),
      );
    }
  }

  Future<void> _showPDFOptions(File file) async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(file.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _deletePDF(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePDF(File file) async {
    try {
      await PDFGenerator.deletePDF(file);
      _loadSavedPDFs(); // Refresh the list
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted: ${path.basename(file.path)}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting PDF: $e")),
      );
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NoteTube - Video to Notes"),
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickAndTranscribeAudio,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Select Audio File"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _linkController,
                      decoration: const InputDecoration(
                        labelText: "Paste YouTube video link",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _transcribeFromYouTubeLink,
                      icon: const Icon(Icons.youtube_searched_for),
                      label: const Text("Transcribe from YouTube"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                    if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Transcribing..."),
                            ],
                          ),
                        ),
                      )
                    else if (_transcription != null)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(_transcription!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _downloadPdf,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text("Save as PDF"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_savedPDFs.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Saved Transcriptions",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _savedPDFs.length,
                                itemBuilder: (context, index) {
                                  final file = _savedPDFs[index];
                                  final fileName = path.basename(file.path);
                                  return ListTile(
                                    leading: const Icon(Icons.picture_as_pdf),
                                    title: Text(fileName),
                                    subtitle: Text(
                                      'Created: ${file.lastModifiedSync().toString().split('.')[0]}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () => _showPDFOptions(file),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Expanded(
                        child: Center(
                          child: Text(
                            "No transcriptions yet.\nSelect an audio file or paste a YouTube link to start.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
