// === МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TestScreen extends StatefulWidget {
  final String mode;
  final List<String> selectedGroups;

  const TestScreen({super.key, required this.mode, required this.selectedGroups});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final String _baseUrl = 'https://химия.site';
  final _storage = const FlutterSecureStorage();
  final _textController = TextEditingController();

  late final WebViewController _webViewController;
  
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isJsmeReady = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
    _fetchTestQuestions();
  }

  // Запуск WebView с редактором JSME
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _verifyAnswerOnServer(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isJsmeReady = true;
            });
            _loadMoleculeIfRequired();
          },
        ),
      );
    _webViewController.loadFlutterAsset('assets/jsme/index.html');
  }

  // Получение 10 вопросов от Django API
  Future<void> _fetchTestQuestions() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/test/start/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'mode': widget.mode,
          'selected_groups': widget.selectedGroups,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _questions = data['questions'] ?? [];
          _isLoading = false;
        });
        _loadMoleculeIfRequired();
      } else {
        setState(() {
          _error = 'Ошибка генерации теста на сервере.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети при подключении к химия.site';
        _isLoading = false;
      });
    }
  }

  void _loadMoleculeIfRequired() {
    if (_isLoading || !_isJsmeReady || _questions.isEmpty || _currentIndex >= _questions.length) return;
    final currentQuestion = _questions[_currentIndex];
    if (widget.mode == 'mol_to_name' && currentQuestion['molecule_smiles'] != null) {
      _webViewController.runJavaScript('setSmilesToEditor("${currentQuestion['molecule_smiles']}");');
    }
  }

  void _submitJsmeDrawing() {
    _webViewController.runJavaScript('getSmilesFromEditor();');
  }
// === КОНЕЦ БЛОКА МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
// === МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
  // Отправка ответа на Django сервер для проверки через RDKit
  Future<void> _verifyAnswerOnServer(String userAnswer) async {
    if (_currentIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentIndex];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/test/check/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'id': currentQuestion['id'],
          'mode': widget.mode,
          'user_answer': userAnswer,
        }),
      );

      if (mounted) Navigator.pop(context); // Закрываем лоадер

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final bool isCorrect = result['is_correct'] ?? false;
        
        if (isCorrect) _score++;

        _showFeedbackDialog(isCorrect, result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка проверки ответа сервером')),
        );
      }
    }
  }

  // Окно с разбором ошибок (в точности как на вашем сайте)
  void _showFeedbackDialog(bool isCorrect, Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isCorrect ? '🎉 Правильно!' : '❌ Неверно',
          style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.mode == 'name_to_mol' || widget.mode == 'mol_to_name')
                Text('Правильные названия: ${result['all_correct_names']}'),
              if (widget.mode == 'form_to_class' && result['general_formula'] != null)
                Text('Общая формула класса: ${result['general_formula']}'),
              if (result['both_answers_text'] != null && result['both_answers_text'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(result['both_answers_text'], style: const TextStyle(fontStyle: FontStyle.italic)),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToNextQuestion();
            },
            child: const Text('Далее'),
          ),
        ],
      ),
    );
  }

  void _goToNextQuestion() {
    _textController.clear();
    setState(() {
      _currentIndex++;
    });
    
    if (_currentIndex < _questions.length) {
      _loadMoleculeIfRequired();
    } else {
      _showFinalResults();
    }
  }

  // Экран результатов теста
  void _showFinalResults() {
    int percent = ((_score / _questions.length) * 100).toInt();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Тест завершен!'),
        content: Text('Ваш результат: $_score из ${_questions.length} ($percent%)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Закрыть диалог
              Navigator.pop(context); // Вернуться в меню
            },
            child: const Text('В меню'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error.isNotEmpty) {
      return Scaffold(body: Center(child: Text(_error, style: const TextStyle(color: Colors.red))));
    }
    if (_currentIndex >= _questions.length) {
      return const Scaffold(body: Center(child: Text('Расчет результатов...')));
    }

    final currentQuestion = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Вопрос ${_currentIndex + 1} из ${_questions.length}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: _buildQuestionHeader(currentQuestion),
            ),
          ),
          Expanded(
            child: _buildAnswerInterface(currentQuestion),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader(Map<String, dynamic> question) {
    if (widget.mode == 'name_to_mol') {
      return Text(
        'Нарисуйте вещество:\n${question['display_name']}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      );
    } else if (widget.mode == 'mol_to_name') {
      return const Text(
        'Изучите структуру молекулы ниже и введите её название:',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      );
    } else {
      return Text(
        'Определите класс вещества по формуле:\n${question['formula']}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      );
    }
  }

  Widget _buildAnswerInterface(Map<String, dynamic> question) {
    if (widget.mode == 'name_to_mol') {
      return Column(
        children: [
          Expanded(child: WebViewWidget(controller: _webViewController)),
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitJsmeDrawing,
              child: const Text('Проверить молекулу'),
            ),
          )
        ],
      );
    } 
    else if (widget.mode == 'mol_to_name') {
      return Column(
        children: [
          Expanded(child: WebViewWidget(controller: _webViewController)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Введите название вещества',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _verifyAnswerOnServer(_textController.text),
              child: const Text('Проверить название'),
            ),
          )
        ],
      );
    } 
    else {
      List<dynamic> options = question['options'] ?? [];
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 65,
            mainAxisSpacing: 12,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return ElevatedButton(
              style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft),
              onPressed: () => _verifyAnswerOnServer(option['slug']),
              child: Text(option['label'], style: const TextStyle(fontSize: 16)),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
// === КОНЕЦ БЛОКА МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
