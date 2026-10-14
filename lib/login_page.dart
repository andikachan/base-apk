import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'api_config.dart';
import 'splash.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePass = true;
  String? _androidId;

  late AnimationController _entranceCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // Neon palette matching the screenshot
  static const Color _bgDark = Color(0xFF050A12);
  static const Color _cardDark = Color(0xFF0C1420);
  static const Color _cyan = Color(0xFF2196F3); // blue primary
  static const Color _purple = Color(0xFFE53935); // red accent
  static const Color _fieldBg = Color(0xFF121A28);
  static const Color _hint = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
    _initLogin();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLogin() async {
    final info = await DeviceInfoPlugin().androidInfo;
    _androidId = info.id;

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');
    final savedKey = prefs.getString('key');

    if (savedUser != null && savedPass != null && savedKey != null) {
      try {
        final res = await http.get(Uri.parse(
            '$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$_androidId&key=$savedKey'));
        final data = jsonDecode(res.body);

        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => SplashScreen(
                      username: savedUser,
                      password: savedPass,
                      role: data['role'],
                      sessionKey: data['key'],
                      expiredDate: data['expiredDate'],
                      listBug: _parseList(data['listBug']),
                      listDoos: _parseList(data['listDDoS']),
                      news: _parseList(data['news']),
                    )),
          );
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userCtrl.text.trim();
    final password = passCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      final res = await http.post(Uri.parse('$baseUrl/validate'), body: {
        'username': username,
        'password': password,
        'androidId': _androidId ?? 'unknown',
      });
      final data = jsonDecode(res.body);

      if (data['expired'] == true) {
        _showAlert(
          title: 'Akses Habis',
          message: 'Masa akses Anda telah berakhir. Silakan perpanjang.',
          isError: false,
          showContact: true,
        );
      } else if (data['valid'] != true) {
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (msg.contains('perangkat') ||
            msg.contains('device') ||
            msg.contains('another')) {
          _showAlert(
            title: 'Sesi Aktif',
            message: 'Akun ini sedang login di perangkat lain.',
            isError: false,
          );
        } else {
          _showAlert(
            title: 'Login Gagal',
            message: 'Username atau password salah.',
            isError: true,
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('username', username);
        prefs.setString('password', password);
        prefs.setString('key', data['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => SplashScreen(
                      username: username,
                      password: password,
                      role: data['role'],
                      sessionKey: data['key'],
                      expiredDate: data['expiredDate'],
                      listBug: _parseList(data['listBug']),
                      listDoos: _parseList(data['listDDoS']),
                      news: _parseList(data['news']),
                    )),
          );
        }
      }
    } catch (_) {
      _showAlert(
        title: 'Koneksi Error',
        message: 'Gagal terhubung ke server. Periksa jaringan Anda.',
        isError: true,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showAlert({
    required String title,
    required String message,
    required bool isError,
    bool showContact = false,
  }) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.5), width: 1),
        ),
        title: Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message,
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: Colors.white70)),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await launchUrl(Uri.parse('https://t.me/NdikaOfficial'),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text('HUBUNGI NDIKA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _cyan)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Grid background
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

          // Soft neon glow orbs
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purple.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        decoration: BoxDecoration(
                          color: _cardDark.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _cyan.withOpacity(0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _cyan.withOpacity(0.12),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: _purple.withOpacity(0.08),
                              blurRadius: 60,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Neon Logo Circle
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2196F3),
                                    Color(0xFF7B1FA2),
                                    Color(0xFFE53935),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _cyan.withOpacity(0.55),
                                    blurRadius: 22,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: _purple.withOpacity(0.35),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3.5),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0A0E17),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.bolt_rounded,
                                        size: 42,
                                        color: _cyan,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Title NDIKA SYSTEM
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF00F2FE),
                                  Color(0xFF4FACFE),
                                  Color(0xFFA855F7),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'NDIKA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 5,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF00F2FE),
                                  Color(0xFFA855F7),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'EXPLOIT SUITE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                  height: 1.1,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'WhatsApp Automation & Crasher Engine',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF00F2FE).withOpacity(0.75),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Username field
                            _buildField(
                              controller: userCtrl,
                              hint: 'Username',
                              icon: Icons.person_rounded,
                              isPassword: false,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Username wajib diisi'
                                      : null,
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            _buildField(
                              controller: passCtrl,
                              hint: 'Password',
                              icon: Icons.lock_rounded,
                              isPassword: true,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Password wajib diisi'
                                      : null,
                            ),

                            const SizedBox(height: 28),

                            // LOGIN button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2196F3),
                                      Color(0xFF7B1FA2),
                                      Color(0xFFE53935),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyan.withOpacity(0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.arrow_forward_rounded,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'LOGIN',
                                              style: TextStyle(
                                                fontFamily: 'Orbitron',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 2.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Secure footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Secure Login  •  Encrypted Connection',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.4),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePass : false,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _cyan,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _hint.withOpacity(0.8),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: _cyan.withOpacity(0.85), size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _hint,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              )
            : null,
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _cyan, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
        ),
      ),
    );
  }
}

/// Subtle cyber grid background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.05)
      ..strokeWidth = 0.8;

    const double step = 28;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
