import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

// ─── Palette (sama dengan BugSenderPage & AdminPage) ─────────────────────────
class _C {
  static const bg       = Color(0xFF060B14);
  static const surface  = Color(0xFF0C1424);
  static const card     = Color(0xFF101A2E);
  static const border   = Color(0xFF1A2D4A);
  static const borderLit= Color(0xFF1E3A5F);

  static const blue     = Color(0xFF1B6FBD);
  static const blueMid  = Color(0xFF2D8FE8);
  static const blueLight= Color(0xFF56AEF5);
  static const blueFrost= Color(0xFF90CEF7);

  static const green    = Color(0xFF22C55E);
  static const red      = Color(0xFFEF4444);

  static const text     = Color(0xFFE2EDF9);
  static const textSub  = Color(0xFF7A9BBF);
  static const textDim  = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ChangePasswordPage extends StatefulWidget {
  final String username;
  final String sessionKey;

  const ChangePasswordPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with TickerProviderStateMixin {
  final oldPassCtrl     = TextEditingController();
  final newPassCtrl     = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool isLoading       = false;
  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  // Strength meter
  double _strength = 0;
  String _strengthLabel = '';
  Color  _strengthColor = _C.textDim;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _iconCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double>  _iconRotate;
  late Animation<double>  _iconScale;
  late Animation<Offset>  _formSlide;
  late Animation<double>  _formFade;
  late Animation<double>  _shake;

  // Field focus nodes
  final _oldFocus     = FocusNode();
  final _newFocus     = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _formFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconRotate = Tween<double>(begin: -0.15, end: 0.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutBack));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),    weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
    _iconCtrl.forward();

    newPassCtrl.addListener(_evalStrength);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _iconCtrl.dispose();
    _shakeCtrl.dispose();
    oldPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _evalStrength() {
    final p = newPassCtrl.text;
    double s = 0;
    if (p.length >= 8)  s += 0.25;
    if (p.length >= 12) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(p)) s += 0.2;

    String label;
    Color color;
    if (p.isEmpty)    { s = 0; label = '';        color = _C.textDim; }
    else if (s < 0.4) {        label = 'Lemah';   color = _C.red; }
    else if (s < 0.7) {        label = 'Sedang';  color = const Color(0xFFF59E0B); }
    else              {        label = 'Kuat';    color = _C.green; }

    setState(() {
      _strength      = s;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  // ─── API ──────────────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final oldPass     = oldPassCtrl.text.trim();
    final newPass     = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _shakeCtrl.forward(from: 0);
      _showResult('Semua field harus diisi.', success: false);
      return;
    }
    if (newPass != confirmPass) {
      _shakeCtrl.forward(from: 0);
      _showResult('Password baru tidak cocok dengan konfirmasi.', success: false);
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/changepass"),
        body: {
          "username":   widget.username,
          "oldPass":    oldPass,
          "newPass":    newPass,
          "sessionKey": widget.sessionKey,
        },
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showResult('Password berhasil diubah!', success: true);
        oldPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
      } else {
        _shakeCtrl.forward(from: 0);
        _showResult(data['message'] ?? 'Gagal mengubah password', success: false);
      }
    } catch (e) {
      _shakeCtrl.forward(from: 0);
      _showResult('Koneksi error.', success: false);
    }
    setState(() => isLoading = false);
  }

  // ─── Result Dialog ────────────────────────────────────────────────────────
  void _showResult(String msg, {required bool success}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 340),
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
            border: Border.all(
              color: (success ? _C.green : _C.red).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (success ? _C.green : _C.red).withOpacity(0.15),
                blurRadius: 50,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? _C.green : _C.red).withOpacity(0.1),
                  border: Border.all(
                      color: (success ? _C.green : _C.red).withOpacity(0.3)),
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  color: success ? _C.green : _C.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                success ? 'Berhasil' : 'Gagal',
                style: const TextStyle(
                    color: _C.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _C.textSub, fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              _GradBtn(
                label: 'OK',
                fullWidth: true,
                gradient: success
                    ? const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : _C.btnGrad,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
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
          // Animated bg
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
                      const SizedBox(height: 16),
                      _buildHeroIcon(),
                      const SizedBox(height: 28),
                      _buildInfoCard(),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shake.value, 0),
                          child: child,
                        ),
                        child: _buildForm(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _AppBarBackBtn(onTap: () => Navigator.pop(context)),
      title: const Text(
        'Ganti Password',
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

  Widget _buildHeroIcon() {
    return AnimatedBuilder(
      animation: _iconCtrl,
      builder: (_, __) => Transform.scale(
        scale: _iconScale.value,
        child: Transform.rotate(
          angle: _iconRotate.value,
          child: _HeroIconWidget(),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.borderLit),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: _C.blueLight, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Akun',
                  style: TextStyle(color: _C.textSub, fontSize: 11)),
              Text(
                widget.username,
                style: const TextStyle(
                    color: _C.text, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.green.withOpacity(0.3)),
            ),
            child: const Text('AKTIF',
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

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: _C.blue.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                gradient: _C.btnGrad,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Perbarui Keamanan',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Text('Masukkan password lama & baru',
                style: TextStyle(color: _C.textSub, fontSize: 12)),
          ),

          const SizedBox(height: 24),

          // Old password
          _PasswordField(
            controller: oldPassCtrl,
            focusNode: _oldFocus,
            label: 'Password Lama',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureOld,
            onToggle: () => setState(() => _obscureOld = !_obscureOld),
            nextFocus: _newFocus,
          ),

          const SizedBox(height: 14),

          // New password
          _PasswordField(
            controller: newPassCtrl,
            focusNode: _newFocus,
            label: 'Password Baru',
            icon: Icons.vpn_key_outlined,
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            nextFocus: _confirmFocus,
          ),

          // Strength bar
          if (newPassCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _StrengthBar(
              strength: _strength,
              label: _strengthLabel,
              color: _strengthColor,
            ),
          ],

          const SizedBox(height: 14),

          // Confirm password
          _PasswordField(
            controller: confirmPassCtrl,
            focusNode: _confirmFocus,
            label: 'Konfirmasi Password',
            icon: Icons.enhanced_encryption_outlined,
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            isLast: true,
            onSubmit: _changePassword,
            // Show match indicator
            matchState: confirmPassCtrl.text.isEmpty
                ? null
                : confirmPassCtrl.text == newPassCtrl.text,
          ),

          const SizedBox(height: 28),

          // Submit button
          _SubmitButton(
            isLoading: isLoading,
            onTap: _changePassword,
          ),

          const SizedBox(height: 16),

          // Tips
          _buildTips(),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.shield_outlined, color: _C.textSub, size: 13),
            SizedBox(width: 6),
            Text('Tips keamanan',
                style: TextStyle(
                    color: _C.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ...[
            'Minimal 8 karakter',
            'Kombinasi huruf besar, angka & simbol',
            'Hindari tanggal lahir atau nama',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, color: _C.textDim, size: 5),
                    ),
                    const SizedBox(width: 8),
                    Text(t,
                        style: const TextStyle(
                            color: _C.textDim, fontSize: 11, height: 1.4)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Hero Icon ────────────────────────────────────────────────────────────────
class _HeroIconWidget extends StatefulWidget {
  @override
  State<_HeroIconWidget> createState() => _HeroIconWidgetState();
}

class _HeroIconWidgetState extends State<_HeroIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.2, end: 0.8)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.blueMid.withOpacity(_glow.value * 0.3),
                    width: 1,
                  ),
                ),
              ),
              // Mid ring
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.blueMid.withOpacity(_glow.value * 0.5),
                    width: 1,
                  ),
                ),
              ),
              // Core
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _C.blue.withOpacity(0.8),
                      _C.blueMid.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(_glow.value * 0.5),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Keamanan Akun',
              style: TextStyle(
                  color: _C.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Perbarui password secara berkala',
              style: TextStyle(color: _C.textSub, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Password Field ───────────────────────────────────────────────────────────
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback onToggle;
  final FocusNode? nextFocus;
  final bool isLast;
  final VoidCallback? onSubmit;
  final bool? matchState; // null=empty, true=match, false=mismatch

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.obscure,
    required this.onToggle,
    this.nextFocus,
    this.isLast = false,
    this.onSubmit,
    this.matchState,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    if (widget.matchState == true) {
      borderColor = _C.green;
    } else if (widget.matchState == false) {
      borderColor = _C.red;
    } else if (_focused) {
      borderColor = _C.blueMid;
    } else {
      borderColor = _C.border;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _focused ? _C.surface : _C.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _C.blueMid.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        textInputAction:
            widget.isLast ? TextInputAction.done : TextInputAction.next,
        onSubmitted: (_) {
          if (widget.nextFocus != null) {
            FocusScope.of(context).requestFocus(widget.nextFocus);
          } else {
            widget.onSubmit?.call();
          }
        },
        style: const TextStyle(
            color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: _C.blueMid, fontSize: 11),
          prefixIcon: Icon(
            widget.icon,
            color: _focused ? _C.blueLight : _C.textSub,
            size: 18,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Match indicator
              if (widget.matchState != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    widget.matchState!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: widget.matchState! ? _C.green : _C.red,
                    size: 16,
                  ),
                ),
              IconButton(
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.textSub,
                  size: 18,
                ),
                onPressed: widget.onToggle,
                splashRadius: 18,
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Strength Bar ─────────────────────────────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  final Color color;

  const _StrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 4, color: _C.border),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  width: MediaQuery.of(context).size.width * strength * 0.65,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Submit Button ────────────────────────────────────────────────────────────
class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isLoading, required this.onTap});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _down || widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      key: ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_reset_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Perbarui Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared: AnimatedBg ───────────────────────────────────────────────────────
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
    final gridPaint = Paint()
      ..color = _C.border.withOpacity(0.28)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Soft glow di tengah-atas
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.blue.withOpacity(0.12 + math.sin(t * math.pi * 2) * 0.04),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.25),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.25), size.width * 0.7, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Shared: AppBar Back Button ───────────────────────────────────────────────
class _AppBarBackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AppBarBackBtn({required this.onTap});

  @override
  State<_AppBarBackBtn> createState() => _AppBarBackBtnState();
}

class _AppBarBackBtnState extends State<_AppBarBackBtn> {
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

// ─── Shared: _GradBtn ─────────────────────────────────────────────────────────
class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final bool fullWidth;
  final IconData? icon;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.gradient = _C.btnGrad,
    this.fullWidth = false,
    this.icon,
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
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
