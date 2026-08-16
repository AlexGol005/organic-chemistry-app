// === МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'menu_screen.dart'; // Ссылка на экран главного меню

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  String _errorMessage = '';

  // Полный адрес вашего продакшн-сайта
  final String _baseUrl = 'https://химия.site'; 

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Делаем POST-запрос к вашему Django API для проверки пароля
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login/'),
        body: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Безопасно сохраняем секретный ключ (токен) в память телефона
        await _storage.write(key: 'auth_token', value: token);

        if (mounted) {
          // Открываем главное меню и стираем экран входа из памяти смартфона
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Неверный логин или пароль';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка соединения со звуковым сервером химия.site';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Авторизация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Войдите под своей учетной записью сайта химия.site, чтобы синхронизировать прогресс тестов',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Логин / Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 15),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('Войти в аккаунт', style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
// === КОНЕЦ БЛОКА МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
