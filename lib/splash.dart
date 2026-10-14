import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    this.listDoos = const [],
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigate();
      }
    });
    _progressCtrl.forward();
    _initVideo();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl.setLooping(true);
        _videoCtrl.setVolume(0);
        _videoCtrl.play();
        _videoCtrl.addListener(_onVideoProgress);
      }).catchError((_) {
        if (mounted) {
          setState(() => _videoReady = false);
          Future.delayed(const Duration(seconds: 5), _navigate);
        }
      });
  }

  void _onVideoProgress() {
    if (!mounted) return;
    // Auto navigate after progress finishes or video ends
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          sessionKey: widget.sessionKey,
          listBug: widget.listBug,
          listDoos: widget.listDoos,
          news: widget.news,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoCtrl.removeListener(_onVideoProgress);
    _videoCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background video / fallback gradient
          if (_videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoCtrl.value.size.width,
                height: _videoCtrl.value.size.height,
                child: VideoPlayer(_videoCtrl),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF4A1C00),
                    Color(0xFF1A0A00),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),

          // Dark vignette
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // NDIKA OFFICIAL logo text
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF00F2FE),
                      Color(0xFF4FACFE),
                      Color(0xFFA855F7),
                      Color(0xFFFFFFFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'NDIKA',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'NDIKA BASE PROTOCOL',
                  style: TextStyle(
                    color: const Color(0xFF00F2FE).withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 24),

                // Quote
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Next-Gen WhatsApp Engine & Exploitation Tools\nCrafted with Precision by Ndika Official',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Powered by @NdikaOfficial',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),

                const Spacer(flex: 2),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnim.value,
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00F2FE),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // SKIP button
                GestureDetector(
                  onTap: _navigate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withOpacity(0.85),
                        width: 1.5,
                      ),
                      color: Colors.black.withOpacity(0.35),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward_rounded,
                            color: Color(0xFF00F2FE), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'SKIP',
                          style: TextStyle(
                            color: Color(0xFF00F2FE),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
