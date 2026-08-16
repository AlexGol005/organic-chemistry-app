// === МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OrganicChemistryApp());
}

class OrganicChemistryApp extends StatelessWidget {
  const OrganicChemistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Органическая химия',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Включаем современный красивый дизайн Material 3
      ),
      // Проверяем при старте, авторизован ли уже пользователь
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    // Ищем сохраненный токен в безопасном хранилище смартфона
    final token = await _storage.read(key: 'auth_token');
    setState(() {
      _isLoggedIn = token != null;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Пока идет чтение из памяти телефона — показываем индикатор загрузки
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Если токен есть — сразу ведем в пульт тестов, если нет — на логин
    return _isLoggedIn ? const MenuScreen() : const LoginScreen();
  }
}
// === КОНЕЦ БЛОКА МОБИЛЬНОЕ ПРИЛОЖЕНИЕ ===
