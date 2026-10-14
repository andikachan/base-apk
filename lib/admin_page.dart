import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'api_config.dart';

class AdminPage extends StatefulWidget {
  final String sessionKey;

  const AdminPage({super.key, required this.sessionKey});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with TickerProviderStateMixin {
  late String sessionKey;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  final List<String> roleOptions = ['reseller', 'vip', 'member'];
  String selectedRole = 'member';

  int currentPage = 1;
  int itemsPerPage = 25;

  final deleteController = TextEditingController();
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  String newUserRole = 'member';
  bool isLoading = false;

  // ─── Warna Biru Tua Metalik Modern ───────────────────────────────────────
  static const Color bgBase      = Color(0xFF070D18);
  static const Color bgSurface   = Color(0xFF0D1526);
  static const Color bgCard      = Color(0xFF111D33);
  static const Color borderColor = Color(0xFF1E3055);
  static const Color primary     = Color(0xFF2B6CB0);
  static const Color primaryLit  = Color(0xFF4299E1);
  static const Color accent      = Color(0xFF63B3ED);
  static const Color accentGlow  = Color(0xFF90CDF4);
  static const Color textPrimary = Color(0xFFEBF8FF);
  static const Color textMuted   = Color(0xFF718096);
  static const Color textSub     = Color(0xFF4A6FA5);

  // ─── Animasi ──────────────────────────────────────────────────────────────
  late AnimationController _headerController;
  late AnimationController _pulseController;
  late Animation<double> _headerFade;
  late Animation<double> _headerSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<double>(begin: -24, end: 0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _headerController.forward();
    _fetchUsers();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── API ──────────────────────────────────────────────────────────────────
  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
            '$baseUrl/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _alert('Error', data['message'] ?? 'Tidak diizinkan.', isError: true);
      }
    } catch (_) {
      _alert('Koneksi Gagal', 'Tidak dapat menghubungi server.', isError: true);
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList =
          fullUserList.where((u) => u['role'] == selectedRole).toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = start + itemsPerPage;
    return filteredList.sublist(
        start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _alert('Perhatian', 'Masukkan username yang ingin dihapus.',
          isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/deleteUser?key=$sessionKey&username=$username'));
      final data = jsonDecode(res.body);
      if (data['deleted'] == true) {
        _alert('Berhasil', "User '${data['user']['username']}' telah dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _alert('Gagal', data['message'] ?? 'Gagal menghapus user.',
            isError: true);
      }
    } catch (_) {
      _alert('Error', 'Tidak dapat menghubungi server.', isError: true);
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final username = createUsernameController.text.trim();
    final password = createPasswordController.text.trim();
    final day = createDayController.text.trim();

    if (username.isEmpty || password.isEmpty || day.isEmpty) {
      _alert('Perhatian', 'Semua field wajib diisi.', isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/userAdd?key=$sessionKey&username=$username&password=$password&day=$day&role=$newUserRole'));
      final data = jsonDecode(res.body);
      if (data['created'] == true) {
        _alert('Sukses', "Akun '${data['user']['username']}' berhasil dibuat.");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        setState(() => newUserRole = 'member');
        _fetchUsers();
      } else {
        _alert('Gagal', data['message'] ?? 'Gagal membuat akun.',
            isError: true);
      }
    } catch (_) {
      _alert('Error', 'Gagal menghubungi server.', isError: true);
    }
    setState(() => isLoading = false);
  }

  // ─── Dialog Modern ────────────────────────────────────────────────────────
  void _alert(String title, String message, {bool isError = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withOpacity(0.4)
                  : primaryLit.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isError ? Colors.redAccent : primaryLit)
                    .withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isError ? Colors.redAccent : primaryLit)
                      .withOpacity(0.12),
                ),
                child: Icon(
                  isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: isError ? Colors.redAccent : accentGlow,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  )),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: textMuted, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              _buildButton(
                label: 'OK',
                onTap: () => Navigator.pop(ctx),
                isDestructive: false,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(String username) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.redAccent.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.12),
                blurRadius: 40,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.12),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Hapus User',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text("Yakin ingin menghapus '$username'?\nTindakan ini tidak bisa dibatalkan.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: textMuted, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      label: 'Batal',
                      onTap: () => Navigator.pop(ctx, false),
                      isDestructive: false,
                      isOutline: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      label: 'Hapus',
                      onTap: () => Navigator.pop(ctx, true),
                      isDestructive: true,
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

  // ─── Komponen UI ──────────────────────────────────────────────────────────

  /// Tombol utama — support: normal, outline, destructive
  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isOutline = false,
    bool fullWidth = false,
    IconData? icon,
    bool loading = false,
  }) {
    final Color baseColor = isDestructive ? Colors.redAccent : primaryLit;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 46,
      child: _PressableButton(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: isOutline
                ? null
                : LinearGradient(
                    colors: [
                      baseColor.withOpacity(0.85),
                      baseColor.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isOutline ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(12),
            border: isOutline
                ? Border.all(color: borderColor, width: 1.5)
                : null,
            boxShadow: isOutline
                ? null
                : [
                    BoxShadow(
                      color: baseColor.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: textPrimary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: textPrimary),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: isOutline ? textMuted : textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Input field bersih dengan efek focus
  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        style: const TextStyle(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: primaryLit,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textMuted, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: primaryLit, fontSize: 12),
          prefixIcon:
              Icon(icon, color: textSub, size: 18),
          filled: true,
          fillColor: bgSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLit, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// Dropdown styled konsisten
  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(label,
                  style:
                      const TextStyle(color: textMuted, fontSize: 11)),
            ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: bgCard,
              icon:
                  const Icon(Icons.expand_more, color: textSub, size: 20),
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              items: options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt.toUpperCase(),
                      style: const TextStyle(letterSpacing: 0.5)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// Section card dengan header ikonik
  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    Color? accentColor,
  }) {
    final color = accentColor ?? primaryLit;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header section
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: borderColor.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                            color: textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// User list item dengan animasi shimmer subtle
  Widget _buildUserItem(Map user, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (user['username'] as String)
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: accentGlow,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['username'],
                      style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _badge(user['role'].toUpperCase()),
                      const SizedBox(width: 8),
                      Text("Exp: ${user['expiredDate']}",
                          style: const TextStyle(
                              color: textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text("Parent: ${user['parent'] ?? 'SYSTEM'}",
                      style: const TextStyle(
                          color: textSub, fontSize: 11)),
                ],
              ),
            ),
            // Delete button
            _IconBtn(
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              onTap: () async {
                final confirm =
                    await _confirmDelete(user['username']);
                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Prev
          _PillBtn(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => setState(() => currentPage--),
          ),
          const SizedBox(width: 6),
          ...List.generate(totalPages, (i) {
            final page = i + 1;
            final active = page == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _PillBtn(
                label: '$page',
                active: active,
                onTap: () => setState(() => currentPage = page),
              ),
            );
          }),
          const SizedBox(width: 6),
          // Next
          _PillBtn(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => setState(() => currentPage++),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Background grid pattern
          Positioned.fill(child: _GridBackground()),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _headerController,
                    builder: (_, __) => Opacity(
                      opacity: _headerFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _headerSlide.value),
                        child: _buildHeader(),
                      ),
                    ),
                  ),
                ),

                // ── Content ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats row
                      _buildStatsRow(),
                      const SizedBox(height: 24),

                      // Section: Delete User
                      _buildSection(
                        title: 'Hapus User',
                        subtitle: 'Nonaktifkan akun dari sistem',
                        icon: FontAwesomeIcons.userSlash,
                        accentColor: Colors.redAccent,
                        children: [
                          _buildInput(
                            label: 'Username Target',
                            controller: deleteController,
                            icon: FontAwesomeIcons.user,
                          ),
                          const SizedBox(height: 4),
                          _buildButton(
                            label: 'Hapus Akun',
                            onTap: _deleteUser,
                            icon: Icons.delete_outline_rounded,
                            isDestructive: true,
                            fullWidth: true,
                            loading: isLoading,
                          ),
                        ],
                      ),

                      // Section: Create Account
                      _buildSection(
                        title: 'Buat Akun Baru',
                        subtitle: 'Tambah pengguna ke sistem',
                        icon: FontAwesomeIcons.userPlus,
                        children: [
                          _buildInput(
                            label: 'Username',
                            controller: createUsernameController,
                            icon: FontAwesomeIcons.user,
                          ),
                          _buildInput(
                            label: 'Password',
                            controller: createPasswordController,
                            icon: FontAwesomeIcons.lock,
                            obscure: true,
                          ),
                          _buildInput(
                            label: 'Durasi (Hari)',
                            controller: createDayController,
                            icon: FontAwesomeIcons.calendarDay,
                            type: TextInputType.number,
                          ),
                          _buildDropdown(
                            value: newUserRole,
                            options: roleOptions,
                            label: 'Role',
                            onChanged: (v) =>
                                setState(() => newUserRole = v ?? 'member'),
                          ),
                          const SizedBox(height: 16),
                          _buildButton(
                            label: 'Buat Akun',
                            onTap: _createAccount,
                            icon: Icons.add_rounded,
                            fullWidth: true,
                            loading: isLoading,
                          ),
                        ],
                      ),

                      // Section: User Management
                      _buildSection(
                        title: 'User Management',
                        subtitle:
                            '${filteredList.length} pengguna ditemukan',
                        icon: FontAwesomeIcons.users,
                        children: [
                          _buildDropdown(
                            value: selectedRole,
                            options: roleOptions,
                            label: 'Filter Role',
                            onChanged: (v) {
                              if (v != null) {
                                selectedRole = v;
                                _filterAndPaginate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: _LoadingDots(),
                              ),
                            )
                          else if (filteredList.isEmpty)
                            _buildEmptyState()
                          else
                            Column(
                              children: [
                                ..._getCurrentPageData()
                                    .asMap()
                                    .entries
                                    .map((e) =>
                                        _buildUserItem(e.value, e.key))
                                    .toList(),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
                            ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Row(
        children: [
          // Logo mark
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: primaryLit.withOpacity(0.4 * _pulse.value)),
                boxShadow: [
                  BoxShadow(
                    color: primaryLit.withOpacity(0.2 * _pulse.value),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.admin_panel_settings_outlined,
                  color: primaryLit, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Dashboard',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  )),
              Text('System Management Panel',
                  style: TextStyle(color: textMuted, fontSize: 11)),
            ],
          ),
          const Spacer(),
          // Refresh button
          _IconBtn(
            icon: Icons.refresh_rounded,
            color: textSub,
            onTap: _fetchUsers,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalAll = fullUserList.length;
    final totalReseller =
        fullUserList.where((u) => u['role'] == 'reseller').length;
    final totalMember =
        fullUserList.where((u) => u['role'] == 'member').length;

    return Row(
      children: [
        _buildStatCard('Total User', '$totalAll',
            Icons.people_outline_rounded, primaryLit),
        const SizedBox(width: 10),
        _buildStatCard('Reseller', '$totalReseller',
            Icons.storefront_outlined, const Color(0xFF68D391)),
        const SizedBox(width: 10),
        _buildStatCard('Member', '$totalMember',
            Icons.person_outline_rounded, accent),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style:
                    const TextStyle(color: textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: textSub, size: 40),
          const SizedBox(height: 12),
          const Text('Tidak ada data',
              style: TextStyle(color: textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

/// Icon button bulat minimal
class _IconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.15)
              : _AdminPageState.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _AdminPageState.borderColor),
        ),
        child: Icon(widget.icon, color: widget.color, size: 18),
      ),
    );
  }
}

/// Tombol pill untuk pagination
class _PillBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _PillBtn({
    this.label,
    this.icon,
    this.active = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? _AdminPageState.primaryLit
              : _AdminPageState.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? _AdminPageState.primaryLit
                : _AdminPageState.borderColor,
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon,
                  size: 16,
                  color: enabled
                      ? _AdminPageState.textMuted
                      : _AdminPageState.borderColor)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: active
                        ? _AdminPageState.textPrimary
                        : _AdminPageState.textMuted,
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Tombol dengan efek press (scale + opacity)
class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableButton({required this.child, this.onTap});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.45 : (_down ? 0.85 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Loading dots animasi
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_c.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: 0.5 + scale * 0.5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _AdminPageState.primaryLit
                        .withOpacity(0.4 + scale * 0.6),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Background grid pattern
class _GridBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3055).withOpacity(0.3)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Gradient overlay: fade grid ke hitam di pojok
    final gradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 1.5,
      colors: [
        Colors.transparent,
        const Color(0xFF070D18).withOpacity(0.85),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
