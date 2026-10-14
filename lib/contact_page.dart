import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Palette (konsisten dengan halaman lain) ──────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  static const blue      = Color(0xFF1B6FBD);
  static const blueMid   = Color(0xFF2D8FE8);
  static const blueLight = Color(0xFF56AEF5);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);
}

// ─── Contact data ─────────────────────────────────────────────────────────────
class _Contact {
  final String label;
  final String handle;
  final IconData icon;
  final Color color;
  final Color colorDim;
  final String url;

  const _Contact({
    required this.label,
    required this.handle,
    required this.icon,
    required this.color,
    required this.colorDim,
    required this.url,
  });
}

const _contacts = [
  _Contact(
    label:    'Telegram',
    handle:   '@NdikaOfficial',
    icon:     FontAwesomeIcons.telegram,
    color:    Color(0xFF39A7E0),
    colorDim: Color(0xFF1A4D6E),
    url:      'https://t.me/NdikaOfficial',
  ),
  _Contact(
    label:    'WhatsApp',
    handle:   '+62 822-4118-2487',
    icon:     FontAwesomeIcons.whatsapp,
    color:    Color(0xFF25D366),
    colorDim: Color(0xFF0D4A27),
    url:      'https://wa.me/6282241182487',
  ),
  _Contact(
    label:    'Website',
    handle:   'ndikz-api.vercel.app',
    icon:     FontAwesomeIcons.globe,
    color:    Color(0xFF00F2FE),
    colorDim: Color(0xFF0C4A6E),
    url:      'https://ndikz-api.vercel.app',
  ),
  _Contact(
    label:    'GitHub',
    handle:   'NdikzOne',
    icon:     FontAwesomeIcons.github,
    color:    Color(0xFFE2E8F0),
    colorDim: Color(0xFF334155),
    url:      'https://github.com/NdikzOne',
  ),
];

// ─── Page ─────────────────────────────────────────────────────────────────────
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _heroCtrl;
  late AnimationController _listCtrl;

  late Animation<double> _heroScale;
  late Animation<double> _heroFade;
  late Animation<double> _heroGlow;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutBack),
    );
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _heroCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _listCtrl.forward();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _heroCtrl.dispose();
    (_heroGlow as AnimationController).dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Tidak dapat membuka link'),
          backgroundColor: _C.card,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _StaggerItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ContactCard(
                            contact: _contacts[i],
                            onTap: () => _launch(_contacts[i].url),
                          ),
                        ),
                      ),
                      childCount: _contacts.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _BackBtn(onTap: () => Navigator.pop(context)),
      title: const Text(
        'Customer Service',
        style: TextStyle(
          color: _C.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: FadeTransition(
        opacity: _heroFade,
        child: ScaleTransition(
          scale: _heroScale,
          child: Column(
            children: [
              // Animated icon
              AnimatedBuilder(
                animation: _heroGlow,
                builder: (_, __) {
                  final g = (_heroGlow as Animation<double>).value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _C.blueMid.withOpacity(g * 0.25),
                            width: 1,
                          ),
                        ),
                      ),
                      // Mid ring
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _C.blueMid.withOpacity(g * 0.4),
                            width: 1,
                          ),
                        ),
                      ),
                      // Core circle
                      Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _C.blue.withOpacity(0.9),
                              _C.blueMid,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _C.blueMid.withOpacity(g * 0.5),
                              blurRadius: 28,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Ada yang bisa kami bantu?',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tim kami siap membantu kamu\nmelalui platform di bawah ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.textSub,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // Response time badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x5522C55E),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Biasanya merespons dalam beberapa menit',
                      style: TextStyle(
                        color: _C.textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Card ─────────────────────────────────────────────────────────────
class _ContactCard extends StatefulWidget {
  final _Contact contact;
  final VoidCallback onTap;

  const _ContactCard({required this.contact, required this.onTap});

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _hoverCtrl;
  late Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _arrowSlide = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _hoverCtrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _hoverCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _hoverCtrl.reverse();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _pressed ? _C.card.withOpacity(0.9) : _C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? c.color.withOpacity(0.3) : _C.border,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: c.color.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _pressed
                      ? c.color.withOpacity(0.18)
                      : c.colorDim.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.color.withOpacity(_pressed ? 0.4 : 0.15),
                  ),
                ),
                child: Center(
                  child: FaIcon(c.icon, color: c.color, size: 22),
                ),
              ),

              const SizedBox(width: 16),

              // Label + handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.handle,
                      style: const TextStyle(
                        color: _C.textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow with slide animation
              AnimatedBuilder(
                animation: _arrowSlide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(_arrowSlide.value, 0),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _pressed
                          ? c.color.withOpacity(0.15)
                          : _C.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: _pressed
                            ? c.color.withOpacity(0.3)
                            : _C.border,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _pressed ? c.color : _C.textSub,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stagger Item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: ch),
      ),
      child: child,
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
    // Grid
    final grid = Paint()
      ..color = _C.border.withOpacity(0.28)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.blue
              .withOpacity(0.10 + math.sin(t * math.pi * 2) * 0.03),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.22),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.22), size.width * 0.65, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── AppBar Back Button ───────────────────────────────────────────────────────
class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _down ? _C.border : _C.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textSub, size: 16),
        ),
      ),
    );
  }
}
