import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'api_config.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  final targetController = TextEditingController();
  final PageController _bugPageController = PageController(viewportFraction: 0.85);

  String? _selectedBugId;
  bool _isSending = false;
  String? _responseMessage; // format: "type|message"
  int _currentBugPage = 0;

  // Sender
  List<String> _globalSenders = [];
  bool _isLoadingSenders = false;
  int _privateSenderCount = 0;
  int _globalSenderCount = 0;
  bool _loadingSender = false;
  Timer? _senderTimer;

  String _selectedSender = 'private';

  // Colors
  final Color _tealAccent = const Color(0xFF00E5FF);
  final Color _greenAccent = const Color(0xFF00FF88);
  final Color _textWhite = Colors.white;
  final Color _textGrey = const Color(0xFF8BAAB8);

  bool get canAccessGlobalSender {
    final r = widget.role.toLowerCase();
    return r == 'owner' ||
        r == 'admin' ||
        r == 'moderator' ||
        r == 'partner' ||
        r == 'vip';
  }

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset('assets/videos/background.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));

    _fetchSenderStats();
    _loadGlobalSenders();
    _senderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchSenderStats();
    });

    if (widget.listBug.isNotEmpty) {
      final firstBug = widget.listBug[0];
      _selectedBugId = firstBug['bug_id'] as String? ?? '0';
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _resultCtrl.dispose();
    targetController.dispose();
    _bugPageController.dispose();
    _senderTimer?.cancel();
    super.dispose();
  }

  // ─── Fetch sender stats (private & global count) ──────────────────────────
  Future<void> _fetchSenderStats() async {
    if (_loadingSender) return;
    setState(() => _loadingSender = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/getSenderStats?key=${widget.sessionKey}"),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _privateSenderCount = data['private'] ?? 0;
            _globalSenderCount = data['global'] ?? 0;
            _loadingSender = false;
          });
        } else {
          setState(() => _loadingSender = false);
        }
      } else {
        setState(() => _loadingSender = false);
      }
    } catch (_) {
      setState(() => _loadingSender = false);
    }
  }

  // ─── Load global senders list from server ─────────────────────────────────
  Future<void> _loadGlobalSenders() async {
    setState(() => _isLoadingSenders = true);
    try {
      final res = await http.get(Uri.parse(
        '$baseUrl/getActiveSenders?key=${widget.sessionKey}',
      )).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['senders'] != null) {
        if (mounted) {
          setState(() {
            _globalSenders = List<String>.from(data['senders']);
            _globalSenderCount = _globalSenders.length;
          });
        }
      } else {
        if (mounted) setState(() => _globalSenders = []);
      }
    } catch (_) {
      if (mounted) setState(() => _globalSenders = []);
    } finally {
      if (mounted) setState(() => _isLoadingSenders = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  void _setResponse(String type, String msg) {
    if (!mounted) return;
    setState(() => _responseMessage = '$type|$msg');
    _resultCtrl.forward(from: 0);
  }

  // ─── Send Bug ─────────────────────────────────────────────────────────────
  Future<void> _sendBug() async {
  final rawInput = targetController.text.trim();
  final key = widget.sessionKey;

  // Validasi nomor saja (tanpa pengecekan group)
  if (formatPhoneNumber(rawInput) == null) {
    _showAlert("❌ Nomor Tidak Valid",
        "Gunakan format internasional.\nContoh: +62812xxxxxxxx");
    return;
  }

  if (_selectedSender == 'global' && !canAccessGlobalSender) {
    _showAlert("❌ Akses Ditolak",
        "Sender Global hanya untuk Owner, Admin, Moderator, Partner & VIP!");
    return;
  }

  if (_selectedBugId == null || _selectedBugId!.isEmpty) {
    _showAlert("❌ No Bug Selected", "Pilih 1 bug untuk dikirim.");
    return;
  }

  if (_selectedSender == 'private' && _privateSenderCount == 0) {
    _showAlert("❌ No Private Sender", "Tidak ada private sender tersedia.");
    return;
  }
  if (_selectedSender == 'global' && _globalSenderCount == 0) {
    _showAlert("❌ No Global Sender", "Tidak ada global sender tersedia.");
    return;
  }

  setState(() {
    _isSending = true;
    _responseMessage = null;
  });
  _resultCtrl.reset();

  try {
    final encodedTarget = Uri.encodeComponent(rawInput);
    final res = await http.get(Uri.parse(
      '$baseUrl/sendBug'
      '?key=$key'
      '&target=$encodedTarget'
      '&bug=${_selectedBugId}'
      '${_selectedSender == 'global' ? '&senderMode=global' : '&sender=private'}',
    )).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);

    if (data['valid'] == false) {
      _setResponse('error', 'Session key tidak valid. Silakan login ulang.');
    } else if (data['cooldown'] == true) {
      final wait = data['wait'] ?? 0;
      _setResponse('warning', 'Cooldown aktif! Tunggu $wait detik lagi.');
    } else if (data['sended'] == true) {
      final role = data['role'] ?? widget.role;
      _setResponse('success', 'Bug berhasil dikirim ke $rawInput! [$role]');
      targetController.clear();
    } else {
      _setResponse('error', 'Gagal mengirim. Server sedang maintenance.');
    }
  } on Exception catch (e) {
    if (e.toString().contains('TimeoutException')) {
      _setResponse('error', 'Request timeout. Periksa koneksi internet.');
    } else {
      _setResponse('error', 'Koneksi error. Periksa jaringan dan coba lagi.');
    }
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  // ─── Alert Dialog ─────────────────────────────────────────────────────────
  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _tealAccent.withOpacity(0.4), width: 1.5),
          ),
          title: Text(title,
              style: TextStyle(
                  color: _tealAccent,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold)),
          content: Text(msg, style: TextStyle(color: _textGrey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK",
                  style: TextStyle(
                      color: _tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Glass Card Helper ────────────────────────────────────────────────────
  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    BorderRadius? borderRadius,
    Color? borderColor,
    double blurSigma = 12,
    Color? bgColor,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white.withOpacity(0.07),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.15),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ─── Top App Bar ──────────────────────────────────────────────────────────
  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tealAccent.withOpacity(0.2),
              border: Border.all(color: _tealAccent, width: 1.5),
            ),
            child: Icon(Icons.shield_rounded, color: _tealAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'ASTRAL ENGINE',
            style: TextStyle(
              color: _textWhite,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tealAccent, width: 1.5),
              color: Colors.transparent,
            ),
            child: Text(
              'v1.0',
              style: TextStyle(
                color: _tealAccent,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header / User Card ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _tealAccent, width: 2.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person, color: _tealAccent, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.username.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.role.toUpperCase(),
                      style: TextStyle(
                        color: _tealAccent,
                        fontFamily: 'ShareTechMono',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, color: _textGrey, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      widget.expiredDate,
                      style: TextStyle(
                        color: _textWhite,
                        fontFamily: 'ShareTechMono',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _buildStatItem(Icons.bug_report_rounded, _tealAccent,
                    '${widget.listBug.length}', 'Total Bugs'),
                _buildStatDivider(),
                _buildStatItem(Icons.bolt_rounded, _greenAccent, 'GACOR', 'Success Rate'),
                _buildStatDivider(),
                _buildStatItem(
                    Icons.check_circle_rounded, _greenAccent, 'ACTIVE', 'Status'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'Orbitron')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: _textGrey, fontSize: 10, fontFamily: 'ShareTechMono')),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 52, color: Colors.white.withOpacity(0.12));
  }

  // ─── Target Input + Bug Carousel ──────────────────────────────────────────
  Widget _buildNomorAndBugPanel() {
  return _glassCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Icon(Icons.phone_android_rounded, color: _tealAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              'NOMOR TARGET',
              style: TextStyle(
                color: _textWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // Input field
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
              ),
              child: TextField(
                controller: targetController,
                style: TextStyle(color: _textWhite, fontFamily: 'ShareTechMono', fontSize: 15),
                cursorColor: _tealAccent,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Contoh: +62812xxxxxxxx',
                  hintStyle: TextStyle(color: _textGrey.withOpacity(0.5), fontFamily: 'ShareTechMono'),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.language_rounded, color: _textGrey, size: 20),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // PILIH BUG label
        Row(
          children: [
            Icon(Icons.bug_report, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'PILIH BUG',
              style: TextStyle(
                color: _textWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bug Carousel
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _bugPageController,
            itemCount: widget.listBug.length,
            onPageChanged: (i) {
              setState(() {
                _currentBugPage = i;
                final bug = widget.listBug[i];
                final bugId = bug['bug_id'] as String? ?? '$i';
                _selectedBugId = bugId;
              });
            },
            itemBuilder: (context, index) {
              final bug = widget.listBug[index];
              final bugId = bug['bug_id'] as String? ?? '$index';
              final isSelected = _selectedBugId == bugId;

              return AnimatedBuilder(
                animation: _bugPageController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_bugPageController.position.haveDimensions) {
                    double diff = (_bugPageController.page! - index).abs();
                    scale = (1 - diff * 0.07).clamp(0.93, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: GestureDetector(
                  onTap: () => setState(() => _selectedBugId = bugId),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? _tealAccent.withOpacity(0.18) : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? _tealAccent : Colors.white.withOpacity(0.15),
                              width: isSelected ? 2 : 1.2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: _tealAccent.withOpacity(0.35), blurRadius: 24, spreadRadius: 2)
                            ] : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.shield_rounded, color: isSelected ? _tealAccent : _textGrey, size: 36),
                                  if (isSelected) Icon(Icons.check_circle, color: _greenAccent, size: 24),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                (bug['bug_name'] as String? ?? 'BUG').toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? _tealAccent : _textWhite,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bug['bug_id']?.toString().toLowerCase() ?? 'bug',
                                  style: TextStyle(color: _textGrey, fontFamily: 'ShareTechMono', fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.listBug.length, (i) {
            final isActive = i == _currentBugPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? _tealAccent : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

  // ─── Sender Panel ─────────────────────────────────────────────────────────
  Widget _buildSenderPanel() {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: _textWhite, size: 20),
              const SizedBox(width: 8),
              Text(
                'PILIH SENDER',
                style: TextStyle(
                  color: _textWhite,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: () {
                  _fetchSenderStats();
                  _loadGlobalSenders();
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: (_isLoadingSenders || _loadingSender)
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _tealAccent))
                      : Icon(Icons.refresh_rounded, color: _textGrey, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              // Online count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tealAccent),
                  color: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tealAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _loadingSender
                          ? '-- sender online'
                          : '${_privateSenderCount + _globalSenderCount} sender online',
                      style: TextStyle(
                          color: _tealAccent,
                          fontFamily: 'ShareTechMono',
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sender cards
          Row(
            children: [
              // PRIVATE SENDER
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSender = 'private'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 155,
                    decoration: BoxDecoration(
                      color: _selectedSender == 'private'
                          ? _greenAccent.withOpacity(0.85)
                          : Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedSender == 'private'
                            ? _greenAccent
                            : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: _selectedSender == 'private'
                          ? [
                              BoxShadow(
                                color: _greenAccent.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: _selectedSender == 'private'
                              ? Colors.black
                              : _textGrey,
                          size: 38,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Pribadi',
                          style: TextStyle(
                            color: _selectedSender == 'private'
                                ? Colors.black
                                : _textGrey,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _privateSenderCount == 0
                            ? Text(
                                '✕ Kosong',
                                style: TextStyle(
                                  color: _selectedSender == 'private'
                                      ? Colors.black54
                                      : Colors.redAccent,
                                  fontFamily: 'ShareTechMono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : Text(
                                '$_privateSenderCount sender',
                                style: TextStyle(
                                  color: _selectedSender == 'private'
                                      ? Colors.black87
                                      : _tealAccent,
                                  fontFamily: 'ShareTechMono',
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // GLOBAL SENDER
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!canAccessGlobalSender) {
                      _showAlert('❌ Akses Ditolak',
                          'Sender Global hanya untuk Owner, Admin, Moderator, Partner & VIP!');
                      return;
                    }
                    setState(() => _selectedSender = 'global');
                    _loadGlobalSenders();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 155,
                    decoration: BoxDecoration(
                      color: _selectedSender == 'global'
                          ? _tealAccent.withOpacity(0.85)
                          : Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedSender == 'global'
                            ? _tealAccent
                            : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: _selectedSender == 'global'
                          ? [
                              BoxShadow(
                                color: _tealAccent.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: double.infinity),
                            Icon(
                              Icons.public_rounded,
                              color: _selectedSender == 'global'
                                  ? Colors.black
                                  : _textGrey,
                              size: 38,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Global',
                              style: TextStyle(
                                color: _selectedSender == 'global'
                                    ? Colors.black
                                    : _textGrey,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _globalSenderCount == 0
                                ? Text(
                                    '✕ Kosong',
                                    style: TextStyle(
                                      color: _selectedSender == 'global'
                                          ? Colors.black54
                                          : Colors.redAccent,
                                      fontFamily: 'ShareTechMono',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  )
                                : Text(
                                    '$_globalSenderCount sender',
                                    style: TextStyle(
                                      color: _selectedSender == 'global'
                                          ? Colors.black87
                                          : _tealAccent,
                                      fontFamily: 'ShareTechMono',
                                      fontSize: 12,
                                    ),
                                  ),
                          ],
                        ),
                        // Lock icon for non-privileged users
                        if (!canAccessGlobalSender)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber,
                                border: Border.all(
                                    color: Colors.black26, width: 1.5),
                              ),
                              child: const Icon(Icons.lock_rounded,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Info quota / active sender list (when global selected)
          if (_selectedSender == 'global' && _globalSenders.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.format_list_bulleted_rounded,
                        color: _textGrey, size: 13),
                    const SizedBox(width: 6),
                    Text('${_globalSenders.length} sender aktif',
                        style: TextStyle(
                            color: _textGrey,
                            fontSize: 11,
                            fontFamily: 'ShareTechMono',
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  ...(_globalSenders.take(3).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _greenAccent)),
                          const SizedBox(width: 8),
                          Text(s,
                              style: TextStyle(
                                  color: _tealAccent,
                                  fontSize: 11,
                                  fontFamily: 'ShareTechMono')),
                        ]),
                      ))),
                  if (_globalSenders.length > 3)
                    Text('+ ${_globalSenders.length - 3} lainnya...',
                        style: TextStyle(color: _textGrey, fontSize: 10)),
                ],
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _textGrey, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Sisa kirim global hari ini: 8 / 8',
                  style: TextStyle(
                      color: _textGrey,
                      fontFamily: 'ShareTechMono',
                      fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Send Button ──────────────────────────────────────────────────────────
  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF00FFB3)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _tealAccent
                    .withOpacity(0.25 + _pulseController.value * 0.35),
                blurRadius: 24 + _pulseController.value * 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendBug,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: _isSending
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 3))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded,
                          color: Colors.black87, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'SEND BUG',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          fontFamily: 'Orbitron',
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ─── Response Banner ──────────────────────────────────────────────────────
  Widget _buildResponseMessage() {
    if (_responseMessage == null) return const SizedBox.shrink();

    final parts = _responseMessage!.split('|');
    final type = parts[0];
    final msg = parts.length > 1 ? parts[1] : '';

    Color color;
    IconData icon;
    String title;
    switch (type) {
      case 'success':
        color = _greenAccent;
        icon = Icons.check_circle_outline;
        title = 'Berhasil';
        break;
      case 'warning':
        color = Colors.amber;
        icon = Icons.warning_rounded;
        title = 'Peringatan';
        break;
      default:
        color = Colors.redAccent;
        icon = Icons.error_outline;
        title = 'Gagal';
    }

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.12)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: color,
                                fontFamily: 'Orbitron',
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(msg,
                            style: TextStyle(
                                color: _textGrey,
                                fontFamily: 'ShareTechMono',
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _responseMessage = null);
                      _resultCtrl.reset();
                    },
                    child: Icon(Icons.close_rounded, color: _textGrey, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Video Background
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _videoController.value.isInitialized
                ? VideoPlayer(_videoController)
                : Container(color: Colors.black),
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(),
                Container(
                    height: 1, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 14),
                        _buildNomorAndBugPanel(),
                        const SizedBox(height: 14),
                        _buildSenderPanel(),
                        const SizedBox(height: 20),
                        _buildSendButton(),
                        _buildResponseMessage(),
                        const SizedBox(height: 24),
                      ],
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
}
