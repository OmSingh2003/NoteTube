import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'services/whisper_service.dart';
import 'utils/pdf_generator.dart';
import 'package:path/path.dart' as path;
import 'screens/study_tools_screen.dart';

Future<void> main() async {
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

  ThemeData _getDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: Colors.grey[900],
      useMaterial3: true,
      brightness: Brightness.dark,
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[850],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoteTube',
      theme: _getDarkTheme(),
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

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPDFs() async {
    final pdfs = await PDFGenerator.getAllPDFs();
    setState(() {
      _savedPDFs = pdfs;
    });
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

      final pdfFile = await PDFGenerator.generatePdf(
        _transcription!,
        title: title,
      );

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

      _loadSavedPDFs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
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
              leading: const Icon(Icons.text_snippet),
              title: const Text('Open in Study Tools'),
              onTap: () {
                Navigator.pop(context);
                _openStudyTools(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename PDF'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(file);
              },
            ),
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

  Future<void> _showRenameDialog(File file) async {
    final TextEditingController nameController = TextEditingController();
    final String currentName = path.basenameWithoutExtension(file.path);
    nameController.text = currentName;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new name for the PDF',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(context);
                return;
              }

              try {
                final directory = file.parent;
                final newPath = path.join(directory.path, '$newName.pdf');
                await file.rename(newPath);

                if (!mounted) return;
                Navigator.pop(context);

                _loadSavedPDFs();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed to $newName.pdf')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error renaming file: $e')),
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStudyTools(File file) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudyToolsScreen(pdfFile: file)),
    );
  }

  Future<void> _deletePDF(File file) async {
    try {
      await PDFGenerator.deletePDF(file);
      _loadSavedPDFs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted: ${path.basename(file.path)}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error deleting PDF: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.note_alt_outlined,
              size: 32,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Text(
              'NoteTube',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'YouTube Transcription',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _linkController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Paste YouTube video link',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.link, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _transcribeFromYouTubeLink,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isLoading
                              ? 'Transcribing...'
                              : 'Transcribe from YouTube'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[900]!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[200],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (_transcription != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Transcription',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _downloadPdf,
                              icon: const Icon(Icons.download),
                              label: const Text('Save as PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _transcription!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (_savedPDFs.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              color: Colors.teal,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Saved Transcriptions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _savedPDFs.length,
                          itemBuilder: (context, index) {
                            final file = _savedPDFs[index];
                            final fileName = path.basename(file.path);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.grey[800],
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.withOpacity(0.2),
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.teal,
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  'Created: ${file.lastModifiedSync().toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.more_vert,
                                      color: Colors.grey[400]),
                                  onPressed: () => _showPDFOptions(file),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
