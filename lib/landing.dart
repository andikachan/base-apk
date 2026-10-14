import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  // ── Palette ──
  static const Color _bg = Color(0xFF070B14);
  static const Color _surface = Color(0xFF0D1527);
  static const Color _card = Color(0xFF111D35);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _blueMid = Color(0xFF0284C7);
  static const Color _purple = Color(0xFF9D4EDD);
  static const Color _text = Color(0xFFF1F5F9);
  static const Color _textSub = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initVideo();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/landing.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl?.setLooping(true);
        _videoCtrl?.setVolume(0);
        _videoCtrl?.play();
      }).catchError((_) {
        if (mounted) setState(() => _videoReady = false);
      });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://t.me/NdikaOfficial');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _enterLogin() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background Video
          if (_videoCtrl != null && _videoReady)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoCtrl!.value.size.width,
                  height: _videoCtrl!.value.size.height,
                  child: VideoPlayer(_videoCtrl!),
                ),
              ),
            ),

          // Dark Overlay for readability
          Positioned.fill(
            child: Container(
              color: _bg.withOpacity(0.78),
            ),
          ),

          // Cyber Ambient Glow Orbs
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 260 * _pulseAnim.value,
                height: 260 * _pulseAnim.value,
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
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purple.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Cyber Grid Painter
          Positioned.fill(
            child: CustomPaint(painter: _LandingGridPainter()),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // Top Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _cyan.withOpacity(0.35)),
                      boxShadow: [
                        BoxShadow(
                          color: _cyan.withOpacity(0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SYSTEM ONLINE  •  NDIKA BASE v6.0',
                          style: TextStyle(
                            fontFamily: 'ShareTechMono',
                            color: _cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Brand Hero Emblem with Logo Asset
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_cyan, _blueMid, _purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _cyan.withOpacity(0.5),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _surface,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.security_rounded,
                              color: _cyan,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF60A5FA), Color(0xFFC084FC)],
                    ).createShader(bounds),
                    child: const Text(
                      'NDIKA BASE',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Next-Gen WhatsApp Automation & Cyber Intelligence Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSub,
                      height: 1.5,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  // 1. Enter System
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [_cyan, _blueMid, _purple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _enterLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'ACCESS DASHBOARD',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Support / Buy
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _openSupport,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _cyan.withOpacity(0.5), width: 1.5),
                        foregroundColor: _cyan,
                        backgroundColor: _surface.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'OFFICIAL TELEGRAM',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Section Header
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CORE MODULES',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4 Feature Cards
                  _buildFeatureCard(
                    icon: Icons.bolt_rounded,
                    title: 'AUTOMATION CORE',
                    subtitle: 'Payload sender WA ultra cepat dengan proteksi multi-target',
                    gradient: [_cyan, _blueMid],
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'OSINT ARSENAL',
                    subtitle: 'Verifikasi NIK, deep domain check, phone lookup & email osint',
                    gradient: [_purple, const Color(0xFF6200EA)],
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureCard(
                    icon: Icons.dns_rounded,
                    title: 'SERVER CONTROL',
                    subtitle: 'Manajemen server Pterodactyl, kontrol node & inspeksi log',
                    gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureCard(
                    icon: Icons.menu_book_rounded,
                    title: 'ISLAMI & AL-QURAN',
                    subtitle: 'Al-Quran digital komplit dengan audio & terjemahan',
                    gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Text(
                    'NDIKA OFFICIAL © 2026 • ALL RIGHTS RESERVED',
                    style: TextStyle(
                      fontFamily: 'ShareTechMono',
                      fontSize: 10,
                      color: _textSub.withOpacity(0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blueMid.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSub,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.04)
      ..strokeWidth = 0.8;
    const step = 32.0;
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
