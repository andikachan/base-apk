import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  static const blue      = Color(0xFF1B6FBD);
  static const blueMid   = Color(0xFF2D8FE8);
  static const blueLight = Color(0xFF56AEF5);

  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFFA78BFA);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Rules data ───────────────────────────────────────────────────────────────
const _rules = [
  _Rule(
    title: 'Larangan Barter Akun',
    desc:  'Akun tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun.',
    icon:  Icons.swap_horiz_rounded,
    color: Color(0xFFF59E0B),
  ),
  _Rule(
    title: 'Larangan Membagikan Akun',
    desc:  'Setiap akun bersifat pribadi dan hanya boleh digunakan oleh pemilik akun yang terdaftar.',
    icon:  Icons.share_rounded,
    color: Color(0xFF60A5FA),
  ),
  _Rule(
    title: 'Larangan Menjual Akun',
    desc:  'Member TIDAK diperbolehkan menjual akun. Penjualan hanya boleh dilakukan oleh role yang diizinkan secara resmi.',
    icon:  Icons.sell_rounded,
    color: Color(0xFFEF4444),
  ),
  _Rule(
    title: 'Larangan Jual Durasi Ilegal',
    desc:  'Dilarang menjual akses harian, mingguan, trial, atau sejenisnya di luar ketentuan yang telah ditetapkan.',
    icon:  Icons.timer_off_rounded,
    color: Color(0xFFA78BFA),
  ),
  _Rule(
    title: 'Larangan Banting Harga',
    desc:  'Dilarang merusak atau menurunkan harga yang telah ditentukan di bawah ketentuan NDIKA OFFICIAL',
    icon:  Icons.trending_down_rounded,
    color: Color(0xFF34D399),
  ),
];

class _Rule {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _Rule({required this.title, required this.desc,
      required this.icon, required this.color});
}

// ─── Fallback Data (agar tidak loading terus) ────────────────────────────────
const _fallbackServerInfo = {
  'name': 'Astral Server',
  'version': '1..0',
  'status': 'online',
};

// ─── Page ─────────────────────────────────────────────────────────────────────
class InfoPage extends StatefulWidget {
  final String sessionKey;
  const InfoPage({super.key, required this.sessionKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  Map<String, dynamic> serverInfo = _fallbackServerInfo; // Langsung pakai fallback
  bool isLoading = false; // Langsung false, tidak loading

  bool   _apiOnline   = false;
  int    _pingMs      = 0;
  String _pingStatus  = 'Checking...';
  Timer? _pingTimer;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _pingDotCtrl;
  late AnimationController _sanctionCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _entrance;
  late Animation<double> _pingDot;
  late Animation<double> _sanctionGlow;
  late Animation<double> _pulseAnim;

  int? _expandedRule; // Untuk accordion effect

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);

    _pingDotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pingDot = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pingDotCtrl, curve: Curves.easeInOut));

    _sanctionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _sanctionGlow = Tween<double>(begin: 0.2, end: 0.6)
        .animate(CurvedAnimation(parent: _sanctionCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Fetch di background, UI sudah tampil
    _fetchServerInfo();
    _startPingLoop();
    
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _pingDotCtrl.dispose();
    _sanctionCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── API (background, tidak nge-freeze UI) ─────────────────────────────────
  Future<void> _fetchServerInfo() async {
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/getServerInfo?key=${widget.sessionKey}'));
      if (res.statusCode == 200 && mounted) {
        setState(() { serverInfo = jsonDecode(res.body); });
      }
    } catch (_) {
      // Tetap pakai fallback, no problem
    }
  }

  void _startPingLoop() {
    _checkPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPing());
  }

  Future<void> _checkPing() async {
    final start = DateTime.now();
    try {
      final res = await http.get(Uri.parse(
              '$baseUrl/ping?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 3));
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _apiOnline  = true;
          _pingMs     = ms;
          _pingStatus = '${ms}ms';
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) setState(() { 
        _apiOnline = false; 
        _pingMs = 0; 
        _pingStatus = 'Offline'; 
      });
    }
  }

  Color get _pingColor {
    if (!_apiOnline) return _C.red;
    if (_pingMs < 200) return _C.green;
    if (_pingMs < 500) return _C.amber;
    return const Color(0xFFF97316);
  }

  String get _pingLabel {
    if (!_apiOnline) return 'OFFLINE';
    if (_pingMs < 200) return 'EXCELLENT';
    if (_pingMs < 500) return 'GOOD';
    return 'SLOW';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                children: [
                  // Header Hero Section (Baru & Modern)
                  _buildHeroHeader(),
                  const SizedBox(height: 20),

                  // API Status Card (Redesigned)
                  _buildStatusCardModern(),
                  const SizedBox(height: 24),

                  // Rules Section Header (Modern)
                  _buildModernSectionHeader(),
                  const SizedBox(height: 16),

                  // Rules List (Accordion Style)
                  ..._rules.asMap().entries.map((e) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModernRuleCard(
                        rule: e.value,
                        number: e.key + 1,
                        isExpanded: _expandedRule == e.key,
                        onTap: () => setState(() {
                          _expandedRule = _expandedRule == e.key ? null : e.key;
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sanction Card (Enhanced)
                  _buildSanctionCardModern(),
                  const SizedBox(height: 24),

                  // Footer note
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero Header Baru ──────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.blueLight.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.info_outline_rounded, color: _C.blueLight, size: 28),
              ),
            ),
          ),
          // Title dengan efek gradient
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [_C.text, _C.blueLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
            child: const Text('Peraturan &\nInformasi',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                )),
          ),
          const SizedBox(height: 8),
          const Text('Patuhi aturan untuk kenyamanan bersama',
              style: TextStyle(color: _C.textSub, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Status Card Modern ────────────────────────────────────────────────────
  Widget _buildStatusCardModern() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.card, _C.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _apiOnline ? _pingColor.withOpacity(0.3) : _C.red.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_apiOnline ? _pingColor : _C.red).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Animated Status Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (_apiOnline ? _pingColor : _C.red).withOpacity(0.15),
                        (_apiOnline ? _pingColor : _C.red).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _apiOnline ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _apiOnline ? _pingColor : _C.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('API SERVER',
                          style: TextStyle(
                              color: _C.textDim, fontSize: 11,
                              fontWeight: FontWeight.w600, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(_apiOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                              color: _apiOnline ? _pingColor : _C.red,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Ping Ring
                Container(
                  width: 56, height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50, height: 50,
                        child: CircularProgressIndicator(
                          value: _apiOnline ? (_pingMs / 500).clamp(0.0, 1.0) : 0,
                          strokeWidth: 3,
                          backgroundColor: _C.border,
                          color: _pingColor,
                        ),
                      ),
                      Text(_apiOnline ? '$_pingMs' : '0',
                          style: TextStyle(
                              color: _pingColor, fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_apiOnline)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: _C.red, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Koneksi ke server terputus',
                          style: TextStyle(color: _C.textSub, fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Modern Section Header ─────────────────────────────────────────────────
  Widget _buildModernSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4, height: 28,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('PERATURAN',
                style: TextStyle(color: _C.text, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Text('Tap untuk melihat detail',
                style: TextStyle(color: _C.textSub, fontSize: 11)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${_rules.length} ATURAN',
              style: const TextStyle(color: _C.blueLight, fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ─── Sanction Card Modern ──────────────────────────────────────────────────
  Widget _buildSanctionCardModern() {
    return AnimatedBuilder(
      animation: _sanctionCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.card.withOpacity(0.5), _C.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _C.red.withOpacity(0.3 + _sanctionGlow.value * 0.2),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.gavel_rounded,
                    size: 100, color: _C.red.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _C.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.warning_rounded,
                              color: _C.red.withOpacity(0.8 + _sanctionGlow.value * 0.2),
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('SANKSI TEGAS',
                              style: TextStyle(color: _C.red, fontSize: 16,
                                  fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.red.withOpacity(0.15)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block_rounded, color: _C.red, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Akun akan DIHAPUS secara permanen',
                                style: TextStyle(color: _C.text, fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _sanctionChip(Icons.account_balance_wallet_rounded, 'Tanpa refund'),
                        _sanctionChip(Icons.sync_disabled_rounded, 'Tanpa kompensasi'),
                        _sanctionChip(Icons.person_off_rounded, 'Permanent ban'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sanctionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _C.red.withOpacity(0.08),
        border: Border.all(color: _C.red.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.red, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: _C.textSub, fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_moon_rounded, color: _C.blueLight, size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Dengan menggunakan aplikasi ini, pengguna dianggap telah '
                'menyetujui seluruh peraturan yang berlaku.',
                style: TextStyle(color: _C.textSub, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          height: 2, width: 30,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Astral Engine',
            style: TextStyle(color: _C.textDim, fontSize: 10,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(width: 10),
        Container(
          height: 2, width: 30,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    ]);
  }

  PreferredSizeWidget _buildAppBar() {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    automaticallyImplyLeading: false,
    centerTitle: true,
    title: const SizedBox.shrink(), 
    );
  }
}

// ─── Modern Rule Card (Accordion) ────────────────────────────────────────────
class _ModernRuleCard extends StatelessWidget {
  final _Rule rule;
  final int number;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ModernRuleCard({
    required this.rule,
    required this.number,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rule.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isExpanded ? color.withOpacity(0.06) : _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded ? color.withOpacity(0.4) : _C.border,
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Number badge
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text('$number',
                          style: TextStyle(color: color, fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(rule.icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(rule.title,
                        style: TextStyle(
                          color: isExpanded ? _C.text : _C.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  // Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? color : _C.textDim, size: 20),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3, height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(rule.desc,
                            style: const TextStyle(color: _C.textSub, fontSize: 12,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _C.border.withOpacity(0.2)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.blueMid.withOpacity(0.06 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.9).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.15),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.15), size.width * 0.7, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}