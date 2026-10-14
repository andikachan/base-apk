import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';
import 'splash.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _androidId;

  // ── Palette ──
  static const Color _bg = Color(0xFF070B14);
  static const Color _surface = Color(0xFF0D1527);
  static const Color _card = Color(0xFF111D35);
  static const Color _border = Color(0xFF1E3255);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _blueMid = Color(0xFF0284C7);
  static const Color _purple = Color(0xFF9D4EDD);
  static const Color _text = Color(0xFFF1F5F9);
  static const Color _textSub = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _initDeviceAndAutoLogin();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _initDeviceAndAutoLogin() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _androidId = info.id;
    } catch (_) {
      _androidId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');
    final savedKey = prefs.getString('key');

    if (savedUser != null && savedPass != null) {
      _userCtrl.text = savedUser;
      _passCtrl.text = savedPass;

      if (savedKey != null) {
        try {
          final res = await http.get(Uri.parse(
              '$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$_androidId&key=$savedKey'))
              .timeout(const Duration(seconds: 8));
          final data = jsonDecode(res.body);

          if (data['valid'] == true && mounted) {
            _navigateToSplash(
              username: savedUser,
              password: savedPass,
              role: data['role'] ?? 'member',
              sessionKey: data['key'] ?? savedKey,
              expiredDate: data['expiredDate'] ?? '99999-09-99',
              listBug: _parseList(data['listBug']),
              news: _parseList(data['news']),
            );
          }
        } catch (_) {}
      }
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/validate'),
        body: {
          'username': username,
          'password': password,
          'androidId': _androidId ?? 'unknown_device',
        },
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);

      if (data['expired'] == true) {
        _showAlert(
          title: 'AKSES KADALUARSA',
          message: 'Masa aktif akun telah berakhir. Silakan perpanjang lisensi Anda.',
          isError: true,
          showSupport: true,
        );
      } else if (data['valid'] != true) {
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (msg.contains('perangkat') || msg.contains('device') || msg.contains('another')) {
          _showAlert(
            title: 'SESI PERANGKAT AKTIF',
            message: 'Akun ini sedang aktif di perangkat lain. Logout terlebih dahulu dari perangkat lama.',
            isError: false,
          );
        } else {
          _showAlert(
            title: 'AUTENTIKASI GAGAL',
            message: 'Username atau password tidak cocok.',
            isError: true,
          );
        }
      } else {
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setString('key', data['key'] ?? '');
        }

        if (mounted) {
          _navigateToSplash(
            username: username,
            password: password,
            role: data['role'] ?? 'member',
            sessionKey: data['key'] ?? '',
            expiredDate: data['expiredDate'] ?? '99999-09-99',
            listBug: _parseList(data['listBug']),
            news: _parseList(data['news']),
          );
        }
      }
    } catch (_) {
      _showAlert(
        title: 'KONEKSI TERPUTUS',
        message: 'Gagal terhubung ke endpoint server $baseUrl. Pastikan internet aktif.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToSplash({
    required String username,
    required String password,
    required String role,
    required String sessionKey,
    required String expiredDate,
    required List<Map<String, dynamic>> listBug,
    required List<dynamic> news,
  }) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SplashScreen(
          username: username,
          password: password,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
          listBug: listBug,
          listDoos: const [],
          news: news,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showAlert({
    required String title,
    required String message,
    required bool isError,
    bool showSupport = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isError ? const Color(0xFFEF4444).withOpacity(0.5) : _cyan.withOpacity(0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: isError ? const Color(0xFFEF4444).withOpacity(0.2) : _cyan.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError
                      ? const Color(0xFFEF4444).withOpacity(0.15)
                      : _cyan.withOpacity(0.15),
                ),
                child: Icon(
                  isError ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: isError ? const Color(0xFFEF4444) : _cyan,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _textSub, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (showSupport) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final uri = Uri.parse('https://t.me/NdikaOfficial');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _cyan),
                          foregroundColor: _cyan,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SUPPORT', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isError ? const Color(0xFFEF4444) : _cyan,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('OK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyan.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _cyan, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Shield Crest Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _surface,
                          border: Border.all(color: _cyan.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _cyan.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_rounded, color: _cyan, size: 40),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'NDIKA BASE',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _text,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cyber Security & Automation Protocol',
                        style: TextStyle(fontSize: 12, color: _textSub),
                      ),

                      const SizedBox(height: 32),

                      // Glassmorphic Input Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _card.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _border.withOpacity(0.7)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'IDENTIFIER / USERNAME',
                              style: TextStyle(
                                fontFamily: 'ShareTechMono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _cyan,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _userCtrl,
                              style: const TextStyle(color: _text, fontSize: 14),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_rounded, color: _cyan, size: 20),
                                hintText: 'Masukkan username...',
                                hintStyle: const TextStyle(color: _textSub, fontSize: 13),
                                filled: true,
                                fillColor: _surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: _border.withOpacity(0.6)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: _border.withOpacity(0.6)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _cyan, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              validator: (v) => v!.trim().isEmpty ? 'Username wajib diisi' : null,
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              'ACCESS KEY / PASSWORD',
                              style: TextStyle(
                                fontFamily: 'ShareTechMono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _cyan,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              style: const TextStyle(color: _text, fontSize: 14),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.key_rounded, color: _cyan, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: _textSub,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                                hintText: 'Masukkan password...',
                                hintStyle: const TextStyle(color: _textSub, fontSize: 13),
                                filled: true,
                                fillColor: _surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: _border.withOpacity(0.6)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: _border.withOpacity(0.6)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _cyan, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              validator: (v) => v!.trim().isEmpty ? 'Password wajib diisi' : null,
                            ),

                            const SizedBox(height: 16),

                            // Remember Me Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: _cyan,
                                  checkColor: Colors.black,
                                  side: const BorderSide(color: _cyan),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                ),
                                const Text(
                                  'Ingat Sesi Perangkat',
                                  style: TextStyle(color: _textSub, fontSize: 12),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Authenticate Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [_cyan, _blueMid, _purple],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyan.withOpacity(0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login_rounded, size: 18, color: Colors.white),
                                            SizedBox(width: 10),
                                            Text(
                                              'AUTHENTICATE',
                                              style: TextStyle(
                                                fontFamily: 'Orbitron',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Server Connection Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ENDPOINT: base-api.ndichan.xyz',
                              style: TextStyle(
                                fontFamily: 'ShareTechMono',
                                color: _textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
