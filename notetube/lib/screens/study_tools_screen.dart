import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/ai_service.dart';

class StudyToolsScreen extends StatefulWidget {
  final File pdfFile;

  const StudyToolsScreen({super.key, required this.pdfFile});

  @override
  State<StudyToolsScreen> createState() => _StudyToolsScreenState();
}

class _StudyToolsScreenState extends State<StudyToolsScreen>
    with SingleTickerProviderStateMixin {
  String? _pdfText;
  bool _isLoading = true;
  String? _summary;
  List<Map<String, String>> _quizQuestions = [];
  String? _errorMessage;
  late AnimationController _animationController;
  int? _expandedQuestionIndex;

  @override
  void initState() {
    super.initState();
    _loadPdfContent();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatText(String text) {
    // Remove extra newlines and spaces
    final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Split into sentences and format
    final sentences = cleanText.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.join('\n\n');
  }

  Future<void> _loadPdfContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load the PDF document
      final bytes = await widget.pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Extract text from all pages
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final text = extractor.extractText();

      // Clean up
      document.dispose();

      setState(() {
        _pdfText = _formatText(text);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading PDF: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateSummary() async {
    if (_pdfText == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final summary = await AIService.generateSummary(_pdfText!);

      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating summary: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQuiz() async {
    if (_pdfText == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final questions = await AIService.generateQuizQuestions(_pdfText!);

      setState(() {
        _quizQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating quiz: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _summary == null && _quizQuestions.isEmpty
                ? "Loading content..."
                : "Generating...",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPdfContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required Widget child,
    Color? color,
    IconData? icon,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizQuestion(Map<String, String> question, int index) {
    final isExpanded = _expandedQuestionIndex == index;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedQuestionIndex = isExpanded ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question['question']!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Answer:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question['answer']!,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tools'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage != null
              ? _buildErrorWidget()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildContentCard(
                        title: 'Original Text',
                        icon: Icons.description,
                        color: Colors.blue,
                        child: Text(
                          _pdfText ?? 'No text available',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _generateSummary,
                                icon: const Icon(Icons.summarize),
                                label: const Text('Generate Summary'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _generateQuiz,
                                icon: const Icon(Icons.quiz),
                                label: const Text('Generate Quiz'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_summary != null)
                        _buildContentCard(
                          title: 'Summary',
                          icon: Icons.auto_stories,
                          color: Colors.green,
                          child: Text(
                            _summary!,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      if (_quizQuestions.isNotEmpty)
                        _buildContentCard(
                          title: 'Quiz Questions',
                          icon: Icons.question_answer,
                          color: Colors.orange,
                          child: Column(
                            children: [
                              const Text(
                                'Tap on a question to see the answer',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _quizQuestions.length,
                                itemBuilder: (context, index) {
                                  return _buildQuizQuestion(
                                      _quizQuestions[index], index);
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
