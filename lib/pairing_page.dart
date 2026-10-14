import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';
import 'home_page.dart';

class PairingPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const PairingPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage>
    with TickerProviderStateMixin {
  // Theme palette
  static const Color _bg = Color(0xFF070B14);
  static const Color _surface = Color(0xFF0D1527);
  static const Color _card = Color(0xFF101B30);
  static const Color _cardInner = Color(0xFF09101E);
  static const Color _border = Color(0xFF1A2B4C);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _green = Color(0xFF22C55E);
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _purple = Color(0xFF7B2FFF);
  static const Color _text = Color(0xFFF1F5F9);
  static const Color _textSub = Color(0xFF94A3B8);

  final TextEditingController _phoneCtrl = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  // Country code state (supports Indonesia & ALL international countries)
  String _selectedCountryCode = '62';
  String _selectedCountryFlag = '🇮🇩';
  String _selectedCountryName = 'Indonesia';

  final List<Map<String, String>> _countryList = const [
    {'flag': '🇮🇩', 'name': 'Indonesia', 'code': '62'},
    {'flag': '🇲🇾', 'name': 'Malaysia', 'code': '60'},
    {'flag': '🇸🇬', 'name': 'Singapura', 'code': '65'},
    {'flag': '🇺🇸', 'name': 'Amerika Serikat', 'code': '1'},
    {'flag': '🇬🇧', 'name': 'Inggris (UK)', 'code': '44'},
    {'flag': '🇮🇳', 'name': 'India', 'code': '91'},
    {'flag': '🇵🇭', 'name': 'Filipina', 'code': '63'},
    {'flag': '🇻🇳', 'name': 'Vietnam', 'code': '84'},
    {'flag': '🇹🇭', 'name': 'Thailand', 'code': '66'},
    {'flag': '🇸🇦', 'name': 'Arab Saudi', 'code': '966'},
    {'flag': '🇦🇪', 'name': 'Uni Emirat Arab', 'code': '971'},
    {'flag': '🇧🇷', 'name': 'Brasil', 'code': '55'},
    {'flag': '🇷🇺', 'name': 'Rusia', 'code': '7'},
    {'flag': '🇯🇵', 'name': 'Jepang', 'code': '81'},
    {'flag': '🇰🇷', 'name': 'Korea Selatan', 'code': '82'},
    {'flag': '🇩🇪', 'name': 'Jerman', 'code': '49'},
    {'flag': '🇫🇷', 'name': 'Prancis', 'code': '33'},
    {'flag': '🇦🇺', 'name': 'Australia', 'code': '61'},
    {'flag': '🇹🇷', 'name': 'Turki', 'code': '90'},
    {'flag': '🇵🇰', 'name': 'Pakistan', 'code': '92'},
    {'flag': '🇧🇩', 'name': 'Bangladesh', 'code': '880'},
    {'flag': '🇳🇱', 'name': 'Belanda', 'code': '31'},
    {'flag': '🇪🇸', 'name': 'Spanyol', 'code': '34'},
    {'flag': '🇮🇹', 'name': 'Italia', 'code': '39'},
    {'flag': '🇨🇦', 'name': 'Kanada', 'code': '1'},
    {'flag': '🌐', 'name': 'Semua / Manual (Ketik Bebas)', 'code': ''},
  ];

  bool _isGenerating = false;
  String? _generatedPairingCode;
  String? _pairedNumber;
  bool _isCopied = false;

  int _expireSeconds = 120;
  Timer? _countdownTimer;

  List<dynamic> _activeSenders = [];
  bool _isLoadingSenders = false;
  String? _sendersError;

  // Animations
  late AnimationController _radarCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _codeEntranceCtrl;
  late Animation<double> _codeEntranceAnim;

  @override
  void initState() {
    super.initState();

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _codeEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _codeEntranceAnim = CurvedAnimation(
      parent: _codeEntranceCtrl,
      curve: Curves.easeOutBack,
    );

    _fetchActiveSenders();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _radarCtrl.dispose();
    _glowCtrl.dispose();
    _codeEntranceCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _expireSeconds = 120);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expireSeconds <= 1) {
        timer.cancel();
        setState(() => _expireSeconds = 0);
      } else {
        setState(() => _expireSeconds--);
      }
    });
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _cleanNumber(String input) {
    String text = input.trim();
    // Jika user menginput diawali tanda +, gunakan nomor internasional langsung
    if (text.startsWith('+')) {
      return text.replaceAll(RegExp(r'[^0-9]'), '');
    }
    String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    // Mode manual: gunakan digit apa adanya
    if (_selectedCountryCode.isEmpty) {
      return digits;
    }
    // Jika diawali 0, buang 0 (misal 0812... -> 812...)
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    // Jika input sudah diawali kode negara yang dipilih, jangan diduplikasi
    if (digits.startsWith(_selectedCountryCode)) {
      return digits;
    }
    return '$_selectedCountryCode$digits';
  }

  void _showCountryPicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: _border, width: 1),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _countryList.where((c) {
              final q = searchQuery.toLowerCase();
              return c['name']!.toLowerCase().contains(q) ||
                  c['code']!.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _textSub.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.public_rounded, color: _cyan, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'PILIH KODE NEGARA',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _textSub, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _cardInner,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      style: const TextStyle(color: _text, fontSize: 13),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search_rounded, color: _cyan, size: 18),
                        border: InputBorder.none,
                        hintText: 'Cari negara atau kode (cth: Indonesia, 62, 1)',
                        hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        color: _border.withOpacity(0.4),
                        height: 1,
                      ),
                      itemBuilder: (context, idx) {
                        final item = filtered[idx];
                        final isSelected = item['code'] == _selectedCountryCode;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Text(item['flag']!, style: const TextStyle(fontSize: 22)),
                          title: Text(
                            item['name']!,
                            style: TextStyle(
                              color: isSelected ? _cyan : _text,
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? _cyan.withOpacity(0.2) : _cardInner,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? _cyan : _border,
                              ),
                            ),
                            child: Text(
                              item['code']!.isEmpty ? 'MANUAL' : '+${item['code']}',
                              style: TextStyle(
                                color: isSelected ? _cyan : _textSub,
                                fontFamily: 'ShareTechMono',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = item['code']!;
                              _selectedCountryFlag = item['flag']!;
                              _selectedCountryName = item['name']!;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchActiveSenders() async {
    setState(() {
      _isLoadingSenders = true;
      _sendersError = null;
    });

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/mySender?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _activeSenders = data['connections'] ?? [];
          _isLoadingSenders = false;
        });
      } else {
        setState(() {
          _isLoadingSenders = false;
          _sendersError = 'Gagal memuat sesi sender (${res.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSenders = false;
          _sendersError = 'Koneksi timeout atau offline';
        });
      }
    }
  }

  Future<void> _generatePairing() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      _showToast('Masukkan nomor WhatsApp terlebih dahulu', isError: true);
      return;
    }

    final formattedNumber = _cleanNumber(raw);
    if (formattedNumber.length < 8) {
      _showToast('Nomor telepon tidak valid (minimal 8 digit)', isError: true);
      return;
    }

    _phoneFocus.unfocus();
    setState(() {
      _isGenerating = true;
      _isCopied = false;
    });

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/getPairing?key=${widget.sessionKey}&number=$formattedNumber'),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final data = jsonDecode(res.body);

      // Support valid: true (standar response server), status: true, atau pairingCode != null
      final bool hasCode = data['pairingCode'] != null && data['pairingCode'].toString().trim().isNotEmpty;
      final bool isValid = (data['valid'] == true) || (data['status'] == true) || hasCode;

      if (isValid && hasCode) {
        final code = data['pairingCode'].toString().trim();
        setState(() {
          _generatedPairingCode = code;
          _pairedNumber = formattedNumber;
          _isGenerating = false;
        });
        _codeEntranceCtrl.forward(from: 0.0);
        _startCountdown();
        HapticFeedback.mediumImpact();
        _showToast('Kode pairing berhasil di-generate!');
      } else {
        setState(() => _isGenerating = false);
        final errMsg = data['message'] ?? data['error'] ?? 'Gagal membuat kode pairing. Pastikan nomor aktif & benar.';
        _showToast(errMsg.toString(), isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showToast('Gagal terhubung ke server pairing: $e', isError: true);
      }
    }
  }

  Future<void> _deleteSender(dynamic senderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Putus Sesi?',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _text,
              )),
          ],
        ),
        content: const Text(
          'Sesi WhatsApp ini akan dihapus dari server bot. Anda harus melakukan pairing ulang untuk mengaktifkannya kembali.',
          style: TextStyle(color: _textSub, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus Sesi', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/deleteSender?key=${widget.sessionKey}&id=$senderId'),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (data['valid'] == true || data['status'] == true) {
        _showToast('Sesi WhatsApp berhasil diputus');
        _fetchActiveSenders();
      } else {
        _showToast(data['message'] ?? data['error'] ?? 'Gagal menghapus sesi', isError: true);
      }
    } catch (e) {
      _showToast('Gagal memutus sesi: $e', isError: true);
    }
  }

  Future<void> _openWhatsApp() async {
    final uris = [
      Uri.parse('whatsapp://'),
      Uri.parse('https://api.whatsapp.com/'),
    ];
    for (final u in uris) {
      if (await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _showToast('Aplikasi WhatsApp tidak ditemukan di HP ini', isError: true);
  }

  void _copyPairingCode() {
    if (_generatedPairingCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedPairingCode!));
    HapticFeedback.lightImpact();
    setState(() => _isCopied = true);
    _showToast('Kode pairing disalin ke clipboard!');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? const Color(0xFFEF4444) : _green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError ? const Color(0xFFEF4444).withOpacity(0.5) : _green.withOpacity(0.5),
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Background ambient grid
          Positioned.fill(
            child: CustomPaint(
              painter: _GridBackgroundPainter(
                lineColor: _cyan.withOpacity(0.025),
                spacing: 30,
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchActiveSenders,
              color: _green,
              backgroundColor: _surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Radar Node Status Card
                    _buildRadarStatusCard(),
                    const SizedBox(height: 18),

                    // 2. Input Terminal Card
                    _buildInputCard(),
                    const SizedBox(height: 18),

                    // 3. Generated Pairing Code Hologram (if present)
                    if (_generatedPairingCode != null) ...[
                      _buildPairingCodeHologram(),
                      const SizedBox(height: 18),
                    ],

                    // 4. Step by step Visual Guide
                    _buildStepByStepGuide(),
                    const SizedBox(height: 22),

                    // 5. Active Connected Senders Section
                    _buildConnectedSendersSection(),
                  ],
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
      backgroundColor: _surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: _cyan, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.15),
              border: Border.all(color: _green.withOpacity(0.6)),
            ),
            child: const Icon(FontAwesomeIcons.whatsapp, color: _green, size: 14),
          ),
          const SizedBox(width: 10),
          const Text(
            'PAIRING CONSOLE',
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: _isLoadingSenders
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: _green, strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, color: _cyan, size: 22),
          onPressed: _isLoadingSenders ? null : _fetchActiveSenders,
          tooltip: 'Refresh Sesi',
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: _border.withOpacity(0.8),
        ),
      ),
    );
  }

  // ── 1. Radar Node Status Card ──────────────────────────────────────────────
  Widget _buildRadarStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _surface,
            _card,
            _surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _green.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated Radar Scanner Circle
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF041810),
              border: Border.all(color: _green.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _green.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _radarCtrl,
                  child: CustomPaint(
                    size: const Size(58, 58),
                    painter: _RadarSweepPainter(color: _green),
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green,
                        boxShadow: [
                          BoxShadow(color: _green.withOpacity(0.8), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'WHATSAPP PROTOCOL V4',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Multi-Device Pairing Terminal',
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tautkan bot WhatsApp tanpa perlu scan QR code',
                  style: TextStyle(
                    color: _textSub.withOpacity(0.9),
                    fontSize: 11,
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

  // ── 2. Input Terminal Card ─────────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: _cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'TARGET SENDER NUMBER',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: _cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Country badge + Phone Input Row
          Container(
            decoration: BoxDecoration(
              color: _cardInner,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _phoneFocus.hasFocus ? _cyan : _border,
                width: _phoneFocus.hasFocus ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                // Interactive Country Code Chip (Tap to change country)
                InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selectedCountryFlag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          _selectedCountryCode.isEmpty ? '🌐' : '+$_selectedCountryCode',
                          style: const TextStyle(
                            color: _text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'ShareTechMono',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, color: _cyan, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Input Text
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontFamily: 'ShareTechMono',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _selectedCountryCode == '62'
                          ? '81234567890'
                          : _selectedCountryCode == '1'
                              ? '2025550123'
                              : _selectedCountryCode.isEmpty
                                  ? '+628xxx / +1xxx'
                                  : 'Nomor WhatsApp...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        fontFamily: 'ShareTechMono',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_phoneCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: _textSub, size: 18),
                    onPressed: () => setState(() => _phoneCtrl.clear()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Format tips
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.public_rounded, color: _cyan.withOpacity(0.8), size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedCountryCode.isEmpty
                      ? 'Mode Manual: Ketik nomor lengkap dengan kode negara (cth: 628xxx / 1202xxx)'
                      : 'Negara: $_selectedCountryName (+$_selectedCountryCode). Bisa langsung ketik nomor atau awalan +',
                  style: TextStyle(
                    color: _textSub.withOpacity(0.8),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Generate Pairing Code Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [_green, _greenDark, _cyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generatePairing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'MEMINTA KODE PAIRING...',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'GENERATE PAIRING CODE',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Generated Pairing Code Hologram ──────────────────────────────────────
  Widget _buildPairingCodeHologram() {
    final code = _generatedPairingCode ?? '';
    final cleanCode = code.replaceAll('-', '');
    final part1 = cleanCode.length >= 4 ? cleanCode.substring(0, 4) : cleanCode;
    final part2 = cleanCode.length > 4 ? cleanCode.substring(4) : '';

    return ScaleTransition(
      scale: _codeEntranceAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF041B18), Color(0xFF0A1F30), Color(0xFF0B1424)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _cyan.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _cyan.withOpacity(0.2),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _green.withOpacity(0.6)),
                      ),
                      child: const Text(
                        'KODE AKTIF',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _pairedNumber != null ? '+$_pairedNumber' : '',
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        color: _textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _expireSeconds < 30
                        ? const Color(0xFFEF4444).withOpacity(0.18)
                        : _cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _expireSeconds < 30
                          ? const Color(0xFFEF4444)
                          : _cyan.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _expireSeconds < 30 ? const Color(0xFFEF4444) : _cyan,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_expireSeconds),
                        style: TextStyle(
                          fontFamily: 'ShareTechMono',
                          fontWeight: FontWeight.bold,
                          color: _expireSeconds < 30 ? const Color(0xFFEF4444) : _cyan,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Segmented Digit Matrix Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Group 1 (4 chars)
                _buildSegmentGroup(part1),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: _cyan,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Group 2 (4 chars)
                _buildSegmentGroup(part2),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons (Copy & Open WhatsApp)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyPairingCode,
                    icon: Icon(
                      _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isCopied ? 'TERSALIN!' : 'SALIN KODE',
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCopied ? _green : _cyan.withOpacity(0.2),
                      foregroundColor: _isCopied ? Colors.black : _cyan,
                      elevation: 0,
                      side: BorderSide(
                        color: _isCopied ? _green : _cyan.withOpacity(0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(FontAwesomeIcons.whatsapp, size: 16),
                    label: const Text(
                      'BUKA WA',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentGroup(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: text.split('').map((char) {
        return Container(
          width: 32,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF071120),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cyan.withOpacity(0.55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _cyan.withOpacity(0.18),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            char,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 4. Step-by-Step Visual Guide ───────────────────────────────────────────
  Widget _buildStepByStepGuide() {
    final steps = [
      {'num': '1', 'title': 'Buka WhatsApp', 'desc': 'Buka aplikasi WhatsApp di HP target'},
      {'num': '2', 'title': 'Perangkat Tertaut', 'desc': 'Masuk Menu (⋮) atau Pengaturan → Perangkat Tertaut'},
      {'num': '3', 'title': 'Tautkan Perangkat', 'desc': 'Ketuk tombol Tautkan Perangkat → Tautkan dengan nomor saja'},
      {'num': '4', 'title': 'Masukkan 8 Kode', 'desc': 'Ketik kode pairing yang tertera di atas untuk menyambungkan'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: _cyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'PANDUAN TAUTAN SENDER',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withOpacity(0.15),
                      border: Border.all(color: _green.withOpacity(0.6)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s['num']!,
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title']!,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['desc']!,
                          style: TextStyle(
                            color: _textSub.withOpacity(0.85),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 5. Connected Senders Section ───────────────────────────────────────────
  Widget _buildConnectedSendersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 15,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SESI SENDER AKTIF',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.4)),
              ),
              child: Text(
                '${_activeSenders.length} TERHUBUNG',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_isLoadingSenders && _activeSenders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: const Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
                ),
                SizedBox(height: 12),
                Text(
                  'Memeriksa sesi WhatsApp yang terhubung...',
                  style: TextStyle(color: _textSub, fontSize: 12),
                ),
              ],
            ),
          )
        else if (_sendersError != null && _activeSenders.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sendersError!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
                  onPressed: _fetchActiveSenders,
                ),
              ],
            ),
          )
        else if (_activeSenders.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cardInner,
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.phonelink_erase_rounded, color: _textSub, size: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum Ada Sender Terhubung',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masukkan nomor telepon di atas dan ketuk Generate Pairing Code untuk menautkan nomor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSub.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          )
        else
          ..._activeSenders.map((s) => _buildSenderCard(Map<String, dynamic>.from(s))).toList(),
      ],
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender) {
    final senderId = sender['id'] ?? sender['number'] ?? '';
    final senderNumber = sender['number']?.toString() ?? sender['id']?.toString() ?? 'Unknown';
    final senderName = sender['name']?.toString() ?? 'WhatsApp Sender';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withOpacity(0.12),
                  border: Border.all(color: _green.withOpacity(0.5)),
                ),
                child: const Icon(FontAwesomeIcons.whatsapp, color: _green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+$senderNumber',
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      senderName,
                      style: TextStyle(
                        color: _textSub.withOpacity(0.9),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _green.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: _green, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: _green,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        username: widget.username,
                        password: '',
                        listBug: const [],
                        role: widget.role,
                        expiredDate: '',
                        sessionKey: widget.sessionKey,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded, color: _cyan, size: 15),
                label: const Text(
                  'Buka WA Sender',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: _cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                onPressed: () => _deleteSender(senderId),
                tooltip: 'Putus Sesi',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ──────────────────────────────────────────────────────────
class _GridBackgroundPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;

  _GridBackgroundPainter({required this.lineColor, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) => false;
}

class _RadarSweepPainter extends CustomPainter {
  final Color color;

  _RadarSweepPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.0),
          color.withOpacity(0.4),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => true;
}
