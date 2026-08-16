// === МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'test_screen.dart'; // Ссылка на будущий экран самого теста

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final String _baseUrl = 'https://химия.site';
  
  String _selectedMode = 'name_to_mol'; // По умолчанию режим Название -> Структура
  List<dynamic> _organicGroups = [];
  List<String> _selectedGroups = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMetaAndGroups();
  }

  // Скачиваем мета-данные (ORGANIC_GROUPS) с бэкенда Django
  Future<void> _loadMetaAndGroups() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/meta/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _organicGroups = data['organic_groups'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Не удалось загрузить структуру классов с сайта';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка подключения к сайту химия.site';
        _isLoading = false;
      });
    }
  }

  void _startTest() {
    // Переходим на экран теста, передавая выбранный режим и список выбранных групп
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestScreen(
          mode: _selectedMode,
          selectedGroups: _selectedGroups,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(_error, style: const TextStyle(color: Colors.red))),
      );
    }

    // Скрываем выбор групп, если выбран режим "Формула -> Класс" (как в логике вашего сайта)
    bool showGroups = _selectedMode != 'form_to_class';

    return Scaffold(
      appBar: AppBar(title: const Text('Пульт управления тестами')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Выберите режим теста:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedMode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'name_to_mol', child: Text('Название вещества -> Структурная формула')),
                DropdownMenuItem(value: 'mol_to_name', child: Text('Structural formula -> Name')),
                DropdownMenuItem(value: 'form_to_class', child: Text('Брутто-формула -> Класс (ЕГЭ)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMode = value ?? 'name_to_mol';
                });
              },
            ),
            const SizedBox(height: 20),
            if (showGroups) ...[
              const Text('2. Выберите разделы химии:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _organicGroups.length,
                  itemBuilder: (context, index) {
                    final groupName = _organicGroups[index]['name'];
                    final isChecked = _selectedGroups.contains(groupName);
                    return CheckboxListTile(
                      title: Text(groupName),
                      value: isChecked,
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            _selectedGroups.add(groupName);
                          } else {
                            _selectedGroups.remove(groupName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text('Для режима "Формула -> Класс" выбор разделов не требуется', textAlign: TextAlign.center),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startTest,
                child: const Text('Начать тест (10 вопросов)', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// === КОНЕЦ БЛОКА МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
