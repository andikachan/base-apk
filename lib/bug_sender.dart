import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'api_config.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF060B14);
  static const surface    = Color(0xFF0C1424);
  static const card       = Color(0xFF101A2E);
  static const cardHover  = Color(0xFF152035);
  static const border     = Color(0xFF1A2D4A);
  static const borderLit  = Color(0xFF1E3A5F);

  static const blue       = Color(0xFF1B6FBD);
  static const blueMid    = Color(0xFF2D8FE8);
  static const blueLight  = Color(0xFF56AEF5);
  static const blueFrost  = Color(0xFF90CEF7);

  static const green      = Color(0xFF22C55E);
  static const greenDim   = Color(0xFF16A34A);
  static const red        = Color(0xFFEF4444);

  static const text       = Color(0xFFE2EDF9);
  static const textSub    = Color(0xFF7A9BBF);
  static const textDim    = Color(0xFF3A5470);

  // Gradients
  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient btnRedGrad = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class BugSenderPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const BugSenderPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<BugSenderPage> createState() => _BugSenderPageState();
}

class _BugSenderPageState extends State<BugSenderPage>
    with TickerProviderStateMixin {
  List<dynamic> senderList = [];
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;

  // Animasi
  late AnimationController _bgOrbitCtrl;   // orbit ring bg
  late AnimationController _headerCtrl;    // header entrance
  late AnimationController _fabPulseCtrl;  // FAB pulse
  late AnimationController _listCtrl;      // list stagger trigger

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _fabScale;
  late Animation<double> _fabGlow;

  @override
  void initState() {
    super.initState();

    _bgOrbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _fabPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _fabScale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _fabPulseCtrl, curve: Curves.easeInOut));
    _fabGlow  = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _fabPulseCtrl, curve: Curves.easeInOut));

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _headerCtrl.forward();
    _fetchSenders();
  }

  @override
  void dispose() {
    _bgOrbitCtrl.dispose();
    _headerCtrl.dispose();
    _fabPulseCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchSenders() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          setState(() => senderList = data["connections"] ?? []);
          _listCtrl.forward(from: 0);
        } else {
          setState(() => errorMessage = data["message"] ?? "Failed to fetch");
        }
      } else {
        setState(() => errorMessage = "Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => errorMessage = "Connection failed");
    } finally {
      setState(() { isLoading = false; isRefreshing = false; });
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  Future<void> _addSender(String number) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          "$baseUrl/getPairing?key=${widget.sessionKey}&number=$number"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          _showPairingCodeDialog(number, data['pairingCode']);
        } else {
          _toast(data['message'] ?? "Failed to generate pairing code", error: true);
        }
      } else {
        _toast("Server error: ${res.statusCode}", error: true);
      }
    } catch (_) {
      _toast("Connection failed", error: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  Future<void> _deleteSender(String senderId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.delete(Uri.parse(
          "$baseUrl/deleteSender?key=${widget.sessionKey}&id=$senderId"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          _toast("Sender deleted successfully");
          _fetchSenders();
        } else {
          _toast(data["message"] ?? "Failed", error: true);
        }
      } else {
        _toast("Server error: ${res.statusCode}", error: true);
      }
    } catch (_) {
      _toast("Connection failed", error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? _C.red : _C.greenDim,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────────
  void _showAddSenderDialog() {
    final phoneCtrl = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: _DialogShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                _DialogIcon(icon: Icons.add_link_rounded, color: _C.blueMid),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tambah Sender',
                        style: TextStyle(color: _C.text, fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text('Masukkan nomor WhatsApp',
                        style: TextStyle(color: _C.textSub, fontSize: 12)),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
              _InputField(
                controller: phoneCtrl,
                label: 'Nomor Telepon',
                hint: '628xxx',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _OutlineBtn(
                  label: 'Batal',
                  onTap: () => Navigator.pop(ctx),
                )),
                const SizedBox(width: 12),
                Expanded(child: _GradBtn(
                  label: 'Generate Pairing',
                  icon: Icons.link_rounded,
                  onTap: () {
                    final num = phoneCtrl.text.trim();
                    if (num.isEmpty) {
                      _toast('Masukkan nomor telepon', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _addSender(num);
                  },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showPairingCodeDialog(String number, String code) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PairingDialog(
          number: number,
          code: code,
          onClose: () {
            Navigator.pop(ctx);
            _fetchSenders();
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm(Map<String, dynamic> sender) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: _DialogShell(
          accentColor: _C.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogIcon(icon: Icons.delete_forever_rounded, color: _C.red),
              const SizedBox(height: 16),
              const Text('Hapus Sender?',
                  style: TextStyle(color: _C.text, fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                "Sender '${sender['sessionName'] ?? sender['id']}' akan dihapus permanen.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _OutlineBtn(
                  label: 'Batal',
                  onTap: () => Navigator.pop(ctx, false),
                )),
                const SizedBox(width: 12),
                Expanded(child: _GradBtn(
                  label: 'Hapus',
                  icon: Icons.delete_outline_rounded,
                  gradient: _C.btnRedGrad,
                  onTap: () => Navigator.pop(ctx, true),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) _deleteSender(sender['id']);
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────────
  Widget _buildSenderCard(Map<String, dynamic> sender, int index) {
    final name    = sender['sessionName'] ?? 'WhatsApp Sender';
    final isConn  = true; // placeholder — bisa pakai field status dari API

    return _StaggerItem(
      index: index,
      child: _SenderCard(
        name: name,
        isConnected: isConn,
        onRefresh: _refreshSenders,
        onDelete: () => _showDeleteConfirm(sender),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _EmptyState(onAdd: _showAddSenderDialog);
  }

  Widget _buildErrorState() {
    return _ErrorState(
      message: errorMessage ?? 'Unknown error',
      onRetry: _fetchSenders,
    );
  }

  Widget _buildLoading() {
    return const Center(child: _DotsLoader());
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(child: _AnimatedBg(controller: _bgOrbitCtrl)),

          // Content
          SafeArea(
            child: _buildBody(),
          ),

          // Loading overlay (subtle)
          if (isLoading && senderList.isNotEmpty)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 12,
              left: 0, right: 0,
              child: const Center(child: _ThinProgress()),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _AppBarBtn(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
      ),
      title: FadeTransition(
        opacity: _headerFade,
        child: SlideTransition(
          position: _headerSlide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bug Sender',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  )),
              Text('${senderList.length} sender aktif',
                  style: const TextStyle(color: _C.textSub, fontSize: 11)),
            ],
          ),
        ),
      ),
      actions: [
        _AppBarBtn(
          icon: Icons.refresh_rounded,
          onTap: isLoading ? null : _refreshSenders,
          spinning: isRefreshing,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading && senderList.isEmpty) return _buildLoading();
    if (errorMessage != null && senderList.isEmpty) return _buildErrorState();
    if (senderList.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: _C.blueMid,
      backgroundColor: _C.card,
      onRefresh: _refreshSenders,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Stat strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _StatStrip(total: senderList.length),
            ),
          ),
          // Cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildSenderCard(
                    Map<String, dynamic>.from(senderList[i]), i),
                childCount: senderList.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _fabPulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: _fabScale.value,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.blueMid.withOpacity(_fabGlow.value),
                blurRadius: 28,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.white24,
              onTap: _showAddSenderDialog,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
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
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(controller.value),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = _C.border.withOpacity(0.35)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Slow orbit glow circles
    final cx = size.width * 0.5;
    final cy = size.height * 0.18;

    for (int i = 0; i < 3; i++) {
      final angle = (t * math.pi * 2) + (i * math.pi * 2 / 3);
      final r = 80.0 + i * 55.0;
      final ox = cx + math.cos(angle) * r * 0.3;
      final oy = cy + math.sin(angle) * r * 0.15;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _C.blue.withOpacity(0.07 - i * 0.015),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: r));
      canvas.drawCircle(Offset(ox, oy), r, paint);
    }

    // Top vignette
    final vigPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF060B14), Colors.transparent],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.4), vigPaint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Sender Card ─────────────────────────────────────────────────────────────
class _SenderCard extends StatefulWidget {
  final String name;
  final bool isConnected;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  const _SenderCard({
    required this.name,
    required this.isConnected,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<_SenderCard> createState() => _SenderCardState();
}

class _SenderCardState extends State<_SenderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _dot;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _dot = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top accent line
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _C.blueMid, Colors.transparent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                children: [
                  // Row 1: avatar + info + status
                  Row(
                    children: [
                      // WhatsApp-style avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _C.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _C.borderLit),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(FontAwesomeIcons.whatsapp,
                                  color: _C.blueLight, size: 24),
                            ),
                            // Online dot
                            Positioned(
                              right: 5, bottom: 5,
                              child: AnimatedBuilder(
                                animation: _dot,
                                builder: (_, __) => Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isConnected
                                        ? _C.green.withOpacity(_dot.value)
                                        : _C.red,
                                    boxShadow: widget.isConnected
                                        ? [BoxShadow(
                                            color: _C.green.withOpacity(
                                                _dot.value * 0.6),
                                            blurRadius: 6,
                                          )]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.name,
                                style: const TextStyle(
                                    color: _C.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(children: [
                              AnimatedBuilder(
                                animation: _dot,
                                builder: (_, __) => Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isConnected
                                        ? _C.green.withOpacity(_dot.value)
                                        : _C.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isConnected ? 'Connected' : 'Disconnected',
                                style: TextStyle(
                                  color: widget.isConnected
                                      ? _C.green
                                      : _C.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.isConnected
                              ? _C.green.withOpacity(0.1)
                              : _C.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isConnected
                                ? _C.green.withOpacity(0.3)
                                : _C.red.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          widget.isConnected ? 'ACTIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: widget.isConnected ? _C.green : _C.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Divider
                  Container(
                    height: 1,
                    color: _C.border,
                  ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(children: [
                    Expanded(
                      child: _CardBtn(
                        label: 'Refresh',
                        icon: Icons.refresh_rounded,
                        onTap: widget.onRefresh,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CardBtn(
                        label: 'Hapus',
                        icon: Icons.delete_outline_rounded,
                        isDestructive: true,
                        onTap: widget.onDelete,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Button ──────────────────────────────────────────────────────────────
class _CardBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? _C.red : _C.blueLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 42,
        decoration: BoxDecoration(
          color: _pressed
              ? color.withOpacity(0.15)
              : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed
                ? color.withOpacity(0.5)
                : color.withOpacity(0.2),
          ),
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 130),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pairing Code Dialog (premium) ────────────────────────────────────────────
class _PairingDialog extends StatefulWidget {
  final String number;
  final String code;
  final VoidCallback onClose;

  const _PairingDialog({
    required this.number,
    required this.code,
    required this.onClose,
  });

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon area
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.blue.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: _C.blueMid.withOpacity(_glow.value * 0.4),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                    color: _C.blueMid.withOpacity(_glow.value * 0.5)),
              ),
              child: const Icon(Icons.phonelink_lock_rounded,
                  color: _C.blueLight, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kode Pairing',
              style: TextStyle(
                  color: _C.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Nomor: ${widget.number}',
              style: const TextStyle(color: _C.textSub, fontSize: 13)),

          const SizedBox(height: 24),

          // Code box
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF070E1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _C.blueMid.withOpacity(_glow.value * 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.blueMid.withOpacity(_glow.value * 0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Text(
                widget.code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.blueLight.withOpacity(0.9 + _glow.value * 0.1),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Copy button
          _CopyBtn(
            code: widget.code,
            onCopied: () => setState(() => _copied = true),
            copied: _copied,
          ),

          const SizedBox(height: 8),

          // Instruction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: _C.textSub, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buka WhatsApp → Linked Devices → Link a device → Enter code',
                  style: TextStyle(color: _C.textSub, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          _GradBtn(
            label: 'Selesai & Refresh',
            icon: Icons.check_rounded,
            fullWidth: true,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

// ─── Copy Button ──────────────────────────────────────────────────────────────
class _CopyBtn extends StatelessWidget {
  final String code;
  final VoidCallback onCopied;
  final bool copied;

  const _CopyBtn({
    required this.code,
    required this.onCopied,
    required this.copied,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: _PressableInk(
        onTap: copied
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: code));
                onCopied();
              },
        borderRadius: 12,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: copied
                ? _C.green.withOpacity(0.12)
                : _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: copied
                  ? _C.green.withOpacity(0.4)
                  : _C.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(copied),
                  color: copied ? _C.green : _C.textSub,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  copied ? 'Disalin!' : 'Salin Kode',
                  key: ValueKey(copied),
                  style: TextStyle(
                    color: copied ? _C.green : _C.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ─── Stat Strip ──────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final int total;
  const _StatStrip({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_rounded,
              color: _C.blueLight, size: 18),
          const SizedBox(width: 10),
          Text('$total sender terdaftar',
              style: const TextStyle(
                  color: _C.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.green.withOpacity(0.3)),
            ),
            child: const Text('LIVE',
                style: TextStyle(
                    color: _C.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ─── Stagger Item ────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 70).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatefulWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _float,
              builder: (_, ch) => Transform.translate(
                  offset: Offset(0, _float.value), child: ch),
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: _C.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.borderLit),
                  boxShadow: [
                    BoxShadow(
                        color: _C.blue.withOpacity(0.2), blurRadius: 30),
                  ],
                ),
                child: const Icon(FontAwesomeIcons.whatsapp,
                    color: _C.blueLight, size: 38),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Belum Ada Sender',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Tambah WhatsApp sender pertama\nuntuk mulai mengirim pesan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSub, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            _GradBtn(
              label: 'Tambah Sender',
              icon: Icons.add_rounded,
              onTap: widget.onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _C.red.withOpacity(0.3)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: _C.red, size: 30),
            ),
            const SizedBox(height: 24),
            const Text('Koneksi Gagal',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 32),
            _GradBtn(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable primitives ─────────────────────────────────────────────────────

/// Shell container untuk semua dialog
class _DialogShell extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const _DialogShell({required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _C.blueMid;
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 50,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _DialogIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DialogIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Gradient primary button
class _GradBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final bool fullWidth;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = _C.btnGrad,
    this.fullWidth = false,
  });

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 17),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outline secondary button
class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        decoration: BoxDecoration(
          color: _down ? _C.border.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _down ? _C.textDim : _C.border),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(
                  color: _C.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

/// Input field
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
      cursorColor: _C.blueMid,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
        hintStyle: const TextStyle(color: _C.textDim),
        floatingLabelStyle:
            const TextStyle(color: _C.blueMid, fontSize: 12),
        prefixIcon: Icon(icon, color: _C.textSub, size: 18),
        filled: true,
        fillColor: _C.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.blueMid, width: 1.5)),
      ),
    );
  }
}

/// AppBar icon button
class _AppBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;

  const _AppBarBtn({required this.icon, this.onTap, this.spinning = false});

  @override
  State<_AppBarBtn> createState() => _AppBarBtnState();
}

class _AppBarBtnState extends State<_AppBarBtn>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(_AppBarBtn old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      _spinCtrl.repeat();
    } else if (!widget.spinning) {
      _spinCtrl.stop();
      _spinCtrl.reset();
    }
  }

  @override
  void dispose() { _spinCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 40, height: 40,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: _down ? _C.border : _C.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _C.border),
        ),
        child: AnimatedBuilder(
          animation: _spinCtrl,
          builder: (_, child) => Transform.rotate(
            angle: _spinCtrl.value * math.pi * 2,
            child: child,
          ),
          child: Icon(widget.icon,
              color: widget.onTap == null ? _C.textDim : _C.textSub,
              size: 18),
        ),
      ),
    );
  }
}

/// Dots loading animation
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final scale = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.4 + scale * 0.6,
              child: Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blueMid.withOpacity(0.4 + scale * 0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Thin progress bar
class _ThinProgress extends StatelessWidget {
  const _ThinProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      height: 2,
      child: const LinearProgressIndicator(
        backgroundColor: _C.border,
        color: _C.blueMid,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}

/// Pressable ink wrapper
class _PressableInk extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _PressableInk({
    required this.child,
    this.onTap,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: _C.blue.withOpacity(0.15),
        child: child,
      ),
    );
  }
}
