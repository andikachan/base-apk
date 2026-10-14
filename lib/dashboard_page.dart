import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'api_config.dart';
import 'nik_check.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'al_quran.dart';

// ─── COLORS ────────────────────────────────────────────────────────────────────
const Color kBg      = Color(0xFF070B14);
const Color kCard    = Color(0xFF0D1527);
const Color kCardAlt = Color(0xFF111D35);
const Color kBorder  = Color(0xFF1E3255);
const Color kCyan    = Color(0xFF00E5FF);
const Color kGreen   = Color(0xFF10B981);
const Color kPink    = Color(0xFFEC4899);
const Color kOrange  = Color(0xFF0284C7);
const Color kBlue    = Color(0xFF38BDF8);
const Color kPurple  = Color(0xFF9D4EDD);
const Color kYellow  = Color(0xFFF59E0B);
const Color kWhite   = Color(0xFFF1F5F9);
const Color kWhite54 = Color(0xFF94A3B8);
const Color kWhite24 = Color(0xFF475569);

// ─── Prayer Time Service ───────────────────────────────────────────────────────
class PrayerTimeService {
  static Future<Map<String, dynamic>> fetchPrayerTimes(String city) async {
    final now = DateTime.now();
    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': city, 'country': 'ID', 'method': '11',
      'day': '${now.day}', 'month': '${now.month}', 'year': '${now.year}',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }
}

// ─── Role helpers ─────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return const Color(0xFFF59E0B);
    case 'admin':    return const Color(0xFFEF4444);
    case 'reseller': return kGreen;
    case 'vip':      return kPurple;
    default:         return kCyan;
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return Icons.workspace_premium_rounded;
    case 'admin':    return Icons.admin_panel_settings_rounded;
    case 'reseller': return Icons.storefront_rounded;
    case 'vip':      return Icons.star_rounded;
    default:         return Icons.person_rounded;
  }
}


class _SysItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SysItem({required this.icon, required this.label, required this.value, required this.color});
}

// ─── ANIMATED DOT ──────────────────────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final double size;
  const _AnimatedDot({required this.color, this.size = 6});
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: widget.color,
        boxShadow: [BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
      ),
    ),
  );
}

// ─── HEXAGON PATTERN PAINTER (Fixed - mirip gambar asli) ──────────────────────
class _HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kCyan.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const double w = 72.0;  // lebar diamond
    const double h = 52.0;  // tinggi diamond

    for (double row = -1; row * h < size.height + h * 2; row++) {
      for (double col = -1; col * w < size.width + w * 2; col++) {
        final double offsetX = (row.toInt() % 2 == 0) ? 0 : w * 0.5;
        final cx = col * w + offsetX;
        final cy = row * h;
        _drawDiamond(canvas, paint, Offset(cx, cy), w * 0.5, h * 0.5);
      }
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double hw, double hh) {
    final path = Path()
      ..moveTo(center.dx, center.dy - hh)   // top
      ..lineTo(center.dx + hw, center.dy)   // right
      ..lineTo(center.dx, center.dy + hh)   // bottom
      ..lineTo(center.dx - hw, center.dy)   // left
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── GRID PATTERN PAINTER ─────────────────────────────────────────────────────
class _GridPatternPainter extends CustomPainter {
  final Color gridColor;
  final Color lineColor;
  final double spacing;
  const _GridPatternPainter({required this.gridColor, required this.lineColor, required this.spacing});
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = gridColor..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final paintLines = Paint()..color = lineColor..strokeWidth = 0.4..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }
    for (double x = -size.height; x < size.width + size.height; x += spacing * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paintLines);
    }
    for (double x = -size.height; x < size.width + size.height; x += spacing * 2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paintLines);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Dashboard Page ───────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    this.listDoos = const [],
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  late String sessionKey, username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;

  late WebSocketChannel channel;
  String androidId = 'unknown';
  File? _profileImage;
  VideoPlayerController? _menuVideoCtrl;

  int _navIndex   = 0;
  int onlineUsers = 0;
  int activeConns = 0;
  String deviceModel = 'Android Device';
  String deviceBrand = '';
  int sdkInt = 0;
  int batteryPercent = 72;
  String batteryStatus = 'Discharging';
  int ramUsedMb = 2340;
  int ramTotalMb = 4096;
  int storageUsedGb = 86;
  int storageTotalGb = 128;
  int wifiPercent = 85;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Online Users polling
  Timer? _statsTimer;

  // News carousel
  late PageController _newsPageCtrl;
  int _newsPageViewKey = 0;
  double _currentNewsPage = 0.0;

  // Quick Actions carousel
  late PageController _qaPageCtrl;
  double _currentQaPage = 0.0;

  // System Menu (swipe cards)
  late PageController _menuPageCtrl;
  double _currentMenuPage = 0.0;

  // ── Tabungan Virtual ──
  double _tabunganSaldo = 0;
  List<Map<String, dynamic>> _tabunganRiwayat = [];
  bool _tabunganLoaded = false;

  // ── Location ──
  bool _locationLoading = false;
  bool _locationGranted = false;

  // ── Prayer times ──
  String _prayerCity = 'Surabaya';
  Map<String, String> _prayerTimes = {};
  String _nextPrayerLabel = '';
  String _nextPrayerTime  = '';
  bool _prayerLoading = true;

  // ── Hadith ──
  Map<String, dynamic>? _hadith;
  bool _hadithLoading = true;
  int _lastHadithNumber = 0;

  @override
  void initState() {
    super.initState();
    sessionKey  = widget.sessionKey;
    username    = widget.username;
    password    = widget.password;
    role        = widget.role;
    expiredDate = widget.expiredDate;
    listBug     = widget.listBug;
    listDoos    = widget.listDoos;
    newsList    = widget.news;

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _newsPageCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _newsPageCtrl.addListener(() {
      if (mounted) setState(() => _currentNewsPage = _newsPageCtrl.page ?? 0.0);
    });

    _qaPageCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _qaPageCtrl.addListener(() {
      if (mounted) setState(() => _currentQaPage = _qaPageCtrl.page ?? 0.0);
    });

    _menuPageCtrl = PageController(viewportFraction: 0.82, initialPage: 1);
    _menuPageCtrl.addListener(() {
      if (mounted) setState(() => _currentMenuPage = _menuPageCtrl.page ?? 0.0);
    });

    _initAndroidId();
    _loadProfileImage();
    _initMenuVideo();
    _detectLocationAndFetchPrayer(); 
    _fetchRandomHadith();
    _loadTabungan();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    channel.sink.close(status.goingAway);
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _menuVideoCtrl?.dispose();
    _newsPageCtrl.dispose();
    _qaPageCtrl.dispose();
    _menuPageCtrl.dispose();
    super.dispose();
  }

  // ── Init helpers ──────────────────────────────────────────────────────────
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('profile_image_$username');
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _profileImage = File(path));
    }
  }

  void _initMenuVideo() {
    _menuVideoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _menuVideoCtrl?.setLooping(true);
        _menuVideoCtrl?.setVolume(0);
        _menuVideoCtrl?.play();
      });
  }

  Future<void> _initAndroidId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    androidId = info.id;
    deviceModel = info.model;
    deviceBrand = info.brand;
    sdkInt = info.version.sdkInt;
    // Keep demo-ish but realistic looking values for battery/ram/storage
    // (no battery_plus dependency). Slight random variation for liveliness.
    final rnd = math.Random();
    batteryPercent = 65 + rnd.nextInt(25);
    batteryStatus = batteryPercent > 20 ? 'Discharging' : 'Low';
    ramTotalMb = 4096;
    ramUsedMb = 1800 + rnd.nextInt(1200);
    storageTotalGb = 128;
    storageUsedGb = 60 + rnd.nextInt(40);
    wifiPercent = 70 + rnd.nextInt(30);
    if (mounted) setState(() {});
    _connectWS();
  }

  void _connectWS() {
  channel = WebSocketChannel.connect(Uri.parse('$baseUrl'));

  // Kirim validate dulu, stats menyusul setelah delay
  channel.sink.add(jsonEncode({
    'type': 'validate',
    'key': sessionKey,
    'androidId': androidId,
  }));

  channel.stream.listen((event) {
    final data = jsonDecode(event);

    // Setelah validate sukses, baru minta stats pertama kali
    if (data['type'] == 'myInfo' && data['valid'] == true && mounted) {
      channel.sink.add(jsonEncode({'type': 'stats'}));
    }

    if (data['type'] == 'stats' && mounted) {
      setState(() {
        onlineUsers = data['onlineUsers'] ?? 0;
        activeConns = data['activeConnections'] ?? 0;
      });
    }

    // Handle force logout
    if (data['type'] == 'myInfo' && data['valid'] == false && mounted) {
      _handleInvalidSession(data['reason'] ?? 'Session invalid');
    }

    if (data['type'] == 'forceLogout' && mounted) {
      _handleInvalidSession(data['reason'] ?? 'Logged out');
    }
  }, onError: (_) {
    // Reconnect kalau putus
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectWS();
    });
  });

  // Polling setiap 5 detik
  _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    try {
      channel.sink.add(jsonEncode({'type': 'stats'}));
    } catch (_) {}
  });
}

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ── Fetch Prayer Times ────────────────────────────────────────────────────
  Future<void> _fetchPrayerTimes() async {
    if (!mounted) return;
    setState(() => _prayerLoading = true);
    final data = await PrayerTimeService.fetchPrayerTimes(_prayerCity);
    if (!mounted) return;
    if (data.isNotEmpty) {
      final timings = data['data']?['timings'] ?? {};
      final Map<String, String> times = {
        'Subuh'  : timings['Fajr']    ?? '--:--',
        'Dzuhur' : timings['Dhuhr']   ?? '--:--',
        'Ashar'  : timings['Asr']     ?? '--:--',
        'Maghrib': timings['Maghrib'] ?? '--:--',
        'Isya'   : timings['Isha']    ?? '--:--',
      };
      final now = TimeOfDay.now();
      String nextLabel = 'Isya';
      String nextTime  = times['Isya'] ?? '--:--';
      for (final entry in times.entries) {
        final parts = entry.value.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          if (h > now.hour || (h == now.hour && m > now.minute)) {
            nextLabel = entry.key;
            nextTime  = entry.value;
            break;
          }
        }
      }
      setState(() {
        _prayerTimes     = times;
        _nextPrayerLabel = nextLabel;
        _nextPrayerTime  = nextTime;
        _prayerLoading   = false;
      });
    } else {
      setState(() => _prayerLoading = false);
    }
  }

  // ── Detect Location ───────────────────────────────────────────────────────
  Future<void> _detectLocationAndFetchPrayer() async {
    if (!mounted) return;
    setState(() => _locationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _prayerCity = 'Surabaya';
          });
          await _fetchPrayerTimes();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationLoading = false;
              _prayerCity = 'Surabaya';
            });
            await _fetchPrayerTimes();
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _prayerCity = 'Surabaya';
          });
          await _fetchPrayerTimes();
        }
        return;
      }

      // Ambil koordinat
      final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium,
);

      // Konversi koordinat -> nama kota
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.subAdministrativeArea?.isNotEmpty == true
            ? place.subAdministrativeArea!
            : place.locality?.isNotEmpty == true
                ? place.locality!
                : place.administrativeArea ?? 'Surabaya';

        setState(() {
          _prayerCity     = city;
          _locationGranted = true;
          _locationLoading = false;
        });

        await _fetchPrayerTimes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Lokasi terdeteksi: $city'),
              ]),
              backgroundColor: kGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _prayerCity = 'Surabaya';
        });
        await _fetchPrayerTimes();
      }
    }
  }

  // ── Fetch Hadith ──────────────────────────────────────────────────────────
  Future<void> _fetchRandomHadith() async {
    if (!mounted) return;
    setState(() => _hadithLoading = true);
    try {
      int randomNumber;
      do {
        randomNumber = Random().nextInt(100) + 1;
      } while (randomNumber == _lastHadithNumber);
      _lastHadithNumber = randomNumber;
      final response = await http
          .get(Uri.parse('https://api.hadith.gading.dev/books/muslim/$randomNumber'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && mounted) {
        setState(() { _hadith = json.decode(response.body); _hadithLoading = false; });
      } else {
        if (mounted) setState(() => _hadithLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _hadithLoading = false);
    }
  }

  // ── Change City Dialog ────────────────────────────────────────────────────
  void _showChangeCityDialog() {
    final ctrl = TextEditingController(text: _prayerCity);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Ganti Lokasi',
            style: TextStyle(color: kWhite, fontFamily: 'Orbitron', fontSize: 14)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: kWhite),
          decoration: InputDecoration(
            hintText: 'Nama kota (misal: Jakarta)',
            hintStyle: const TextStyle(color: kWhite54),
            filled: true, fillColor: kBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.location_city_rounded, color: kGreen),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: kWhite54))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _prayerCity = ctrl.text.trim();
                  _locationGranted = false; // reset icon lokasi
                });
                _fetchPrayerTimes();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Simpan',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Hadith Full Dialog ────────────────────────────────────────────────────
  void _showHadithFullDialog(String arabic, String indo, String source, String number, String grade) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kCyan.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: kCyan.withOpacity(0.08), blurRadius: 30, spreadRadius: 2),
              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  color: kCyan.withOpacity(0.08),
                  border: Border(bottom: BorderSide(color: kBorder.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: kCyan.withOpacity(0.2)),
                      child: const Icon(Icons.menu_book_rounded, color: kCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('HADITH LENGKAP',
                            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Orbitron')),
                        Text(grade, style: const TextStyle(color: kCyan, fontSize: 11)),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kWhite.withOpacity(0.08)),
                        child: const Icon(Icons.close_rounded, color: kWhite54, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF1A1F2E),
                          border: Border.all(color: kBorder.withOpacity(0.3)),
                        ),
                        child: Text(arabic,
                            textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                            style: const TextStyle(color: kWhite, fontSize: 19, height: 2.2)),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(width: 3, height: 18,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: kCyan)),
                        const SizedBox(width: 8),
                        const Text('ARTINYA:', style: TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF141824),
                          border: Border.all(color: kBorder.withOpacity(0.2)),
                        ),
                        child: Text(indo,
                            style: const TextStyle(color: kWhite, fontSize: 14, fontStyle: FontStyle.italic, height: 1.8)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kCyan.withOpacity(0.5)),
                          color: kCyan.withOpacity(0.08),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.receipt_long_rounded, color: kCyan, size: 14),
                          const SizedBox(width: 6),
                          Text('${source.isNotEmpty ? source : "Muslim"} #$number',
                              style: const TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('⚠️ Session Expired', style: TextStyle(color: kWhite)),
        content: Text(message, style: const TextStyle(color: kWhite54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false),
            child: const Text('OK', style: TextStyle(color: kCyan)),
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_newsPageCtrl.hasClients) {
          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
          _newsPageCtrl.jumpToPage(0);
        }
      });
    }
  }

  void _onDrawerNav(int index) {
    Widget page;
    switch (index) {
      case 1: page = SellerPage(keyToken: sessionKey); break;
      case 2: page = AdminPage(sessionKey: sessionKey); break;
      case 3: page = OwnerPage(sessionKey: sessionKey, username: username); break;
      default: return;
    }
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (mounted) {
        setState(() => _navIndex = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_newsPageCtrl.hasClients) {
            setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
            _newsPageCtrl.jumpToPage(0);
          }
        });
      }
    });
  }

  // ── Current Page ──────────────────────────────────────────────────────────
  Widget _buildCurrentPage() {
    switch (_navIndex) {
      case 1:
        return HomePage(
          username: username, password: password,
          listBug: listBug, role: role,
          expiredDate: expiredDate, sessionKey: sessionKey,
        );
      case 2:
        return InfoPage(sessionKey: sessionKey);
      case 3:
        return ToolsPage(sessionKey: sessionKey, userRole: role, listDoos: listDoos);
      case 4:
        return _buildSystemMenuPage();
      case 0:
      default:
        return _buildHomePage();
    }
  }



  // ── TABUNGAN VIRTUAL ──────────────────────────────────────────────────────
  Future<void> _loadTabungan() async {
    final prefs = await SharedPreferences.getInstance();
    final keySaldo = 'tabungan_saldo_$username';
    final keyRiwayat = 'tabungan_riwayat_$username';
    final saldo = prefs.getDouble(keySaldo) ?? 0.0;
    final raw = prefs.getStringList(keyRiwayat) ?? [];
    final list = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        list.add(Map<String, dynamic>.from(jsonDecode(s) as Map));
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _tabunganSaldo = saldo;
        _tabunganRiwayat = list;
        _tabunganLoaded = true;
      });
    }
  }

  Future<void> _saveTabungan() async {
    final prefs = await SharedPreferences.getInstance();
    final keySaldo = 'tabungan_saldo_$username';
    final keyRiwayat = 'tabungan_riwayat_$username';
    await prefs.setDouble(keySaldo, _tabunganSaldo);
    final encoded = _tabunganRiwayat.take(30).map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(keyRiwayat, encoded);
  }

  String _formatRp(double n) {
    final isNeg = n < 0;
    final abs = n.abs();
    final whole = abs.floor();
    final frac = ((abs - whole) * 100).round().toString().padLeft(2, '0');
    final s = whole.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${isNeg ? '-' : ''}Rp ${buf.toString()},$frac';
  }

  Future<void> _nabung(double nominal) async {
    if (nominal <= 0) return;
    setState(() {
      _tabunganSaldo += nominal;
      _tabunganRiwayat.insert(0, {
        'type': 'in',
        'amount': nominal,
        'time': DateTime.now().toIso8601String(),
        'note': 'Nabung',
      });
    });
    await _saveTabungan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhasil nabung ${_formatRp(nominal)}! Saldo: ${_formatRp(_tabunganSaldo)}'),
        backgroundColor: const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _tarikTabungan(double nominal) async {
    if (nominal <= 0 || nominal > _tabunganSaldo) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saldo tidak cukup atau nominal tidak valid'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _tabunganSaldo -= nominal;
      _tabunganRiwayat.insert(0, {
        'type': 'out',
        'amount': nominal,
        'time': DateTime.now().toIso8601String(),
        'note': 'Tarik',
      });
    });
    await _saveTabungan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhasil tarik ${_formatRp(nominal)}. Sisa: ${_formatRp(_tabunganSaldo)}'),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showNabungDialog() {
    final presets = [1000.0, 5000.0, 10000.0, 25000.0, 50000.0, 100000.0];
    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F1520),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.2)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.savings_rounded, color: Color(0xFF00E5FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nabung Sekarang',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Pilih nominal atau isi manual',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _nabung(p);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151C28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                        ),
                        child: Text(_formatRp(p),
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nominal custom (contoh: 1500)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                    filled: true,
                    fillColor: const Color(0xFF151C28),
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final raw = customCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final val = double.tryParse(raw) ?? 0;
                      if (val <= 0) return;
                      Navigator.pop(ctx);
                      _nabung(val);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A0E17),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Nabung Nominal Custom',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTarikDialog() {
    final presets = [1000.0, 5000.0, 10000.0, 25000.0];
    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F1520),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tarik Tabungan',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Saldo tersedia: ${_formatRp(_tabunganSaldo)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...presets.map((p) => GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _tarikTabungan(p);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151C28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                        ),
                        child: Text(_formatRp(p),
                          style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    )),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _tarikTabungan(_tabunganSaldo);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                        ),
                        child: const Text('Tarik Semua',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nominal custom',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                    filled: true,
                    fillColor: const Color(0xFF151C28),
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final raw = customCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final val = double.tryParse(raw) ?? 0;
                      Navigator.pop(ctx);
                      _tarikTabungan(val);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Tarik Custom', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabunganCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2137), Color(0xFF0A1628), Color(0xFF12203A)],
        ),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.12), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TABUNGAN KU',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontFamily: 'Orbitron',
                      )),
                    Text('Virtual Savings • Seru-seruan',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
                ),
                child: const Text('VIRTUAL',
                  style: TextStyle(color: Color(0xFF00C853), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Saldo Tabungan',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            _tabunganLoaded ? _formatRp(_tabunganSaldo) : 'Rp 0,00',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'Orbitron',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showNabungDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nabung', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A0E17),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _tabunganSaldo > 0 ? _showTarikDialog : null,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('Tarik', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB300),
                      side: BorderSide(color: const Color(0xFFFFB300).withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_tabunganRiwayat.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Riwayat terakhir',
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
            const SizedBox(height: 8),
            ..._tabunganRiwayat.take(3).map((r) {
              final isIn = r['type'] == 'in';
              final amt = (r['amount'] as num?)?.toDouble() ?? 0;
              final t = r['time']?.toString() ?? '';
              String timeLabel = t;
              try {
                final dt = DateTime.parse(t);
                timeLabel = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
              } catch (_) {}
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 14,
                      color: isIn ? const Color(0xFF00C853) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${isIn ? 'Nabung' : 'Tarik'} • $timeLabel',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                    ),
                    Text(
                      '${isIn ? '+' : '-'}${_formatRp(amt)}',
                      style: TextStyle(
                        color: isIn ? const Color(0xFF00C853) : const Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── SYSTEM MENU (swipe cards - Spam OTP / Spam Pair / Menu Bug) ───────────
  Widget _buildSystemMenuPage() {
    final menus = [
      {
        'title': 'Spam OTP',
        'subtitle': 'OTP Flood System',
        'desc': 'Kirim spam OTP ke target secara massal dengan delay terkontrol dan multi-session.',
        'icon': Icons.sms_rounded,
        'gradient': [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
        'file': 'spam_otp.dart',
        'action': 'otp',
      },
      {
        'title': 'Spam Pair',
        'subtitle': 'Pairing Code Flood',
        'desc': 'Spam pairing code WhatsApp ke nomor target secara realtime dan berulang.',
        'icon': Icons.link_rounded,
        'gradient': [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
        'file': 'spam_pair.dart',
        'action': 'pair',
      },
      {
        'title': 'Menu Bug',
        'subtitle': 'Bug Sender Panel',
        'desc': 'Akses panel bug WhatsApp lengkap: crash, blank, freeze, dan berbagai payload.',
        'icon': Icons.bug_report_rounded,
        'gradient': [const Color(0xFF00838F), const Color(0xFF006064)],
        'file': 'bug_sender.dart',
        'action': 'bug',
      },
    ];

    final int pageIdx = _currentMenuPage.round().clamp(0, menus.length - 1);
    final current = menus[pageIdx];

    return Container(
      color: const Color(0xFF05080F),
      child: Stack(
        children: [
          // Grid background
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPatternPainter(
                gridColor: const Color(0xFF00E5FF).withOpacity(0.045),
                lineColor: const Color(0xFF00E5FF).withOpacity(0.02),
                spacing: 32,
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SYSTEM MENU',
                              style: TextStyle(
                                color: const Color(0xFF00E5FF).withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                fontFamily: 'Orbitron',
                              )),
                            const SizedBox(height: 4),
                            const Text('Pilih Akses',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              )),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('NDIKA BASE PROTOCOL',
                            style: TextStyle(
                              color: const Color(0xFF00F2FE).withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Orbitron',
                              letterSpacing: 1.0,
                            )),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              // open tools as "explore all"
                              setState(() => _navIndex = 3);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.25)),
                                color: Colors.white.withOpacity(0.06),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.explore_rounded, size: 14, color: Colors.white.withOpacity(0.8)),
                                  const SizedBox(width: 6),
                                  Text('Explore All Menu',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Swipe hint
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.swipe_rounded, size: 16, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 8),
                      Text(
                        'Geser untuk memilih menu (${pageIdx + 1}/${menus.length})',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Swipeable cards
                Expanded(
                  child: PageView.builder(
                    controller: _menuPageCtrl,
                    itemCount: menus.length,
                    onPageChanged: (i) => setState(() => _currentMenuPage = i.toDouble()),
                    itemBuilder: (context, index) {
                      final m = menus[index];
                      final dist = (_currentMenuPage - index).abs();
                      final scale = (1.0 - (dist * 0.08)).clamp(0.88, 1.0);
                      final grads = m['gradient'] as List<Color>;

                      return Transform.scale(
                        scale: scale,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: grads,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: grads[0].withOpacity(0.45),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Decorative circles
                                Positioned(
                                  top: -40,
                                  right: -30,
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 80,
                                  right: -20,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Icon box
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                                        ),
                                        child: Icon(
                                          m['icon'] as IconData,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        m['subtitle'] as String,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        m['title'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Orbitron',
                                          letterSpacing: 0.5,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        m['desc'] as String,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 13.5,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      // Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: () => _openMenuFeature(m['action'] as String),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: const Color(0xFF0A1628),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Buka Halaman',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded, size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom status strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFF00B0FF),
                  child: Text(
                    'Membuka ${current['title']} (${current['file']})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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

  void _openMenuFeature(String action) {
    Widget? page;
    switch (action) {
      case 'otp':
      case 'pair':
      case 'bug':
        page = BugSenderPage(
          sessionKey: sessionKey,
          username: username,
          role: role,
        );
        break;
    }
    if (page != null) {
      Navigator.push(context, _slideRoute(page));
    }
  }


  // ── HOME PAGE ─────────────────────────────────────────────────────────────
  Widget _buildHomePage() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER + DASHBOARD CARD
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            // PAIRING BOT WA HERO CARD
            _buildPairingBotCard(),
            const SizedBox(height: 18),
            // CYBER VIDEO SHOWCASE (plays assets/videos/banner.mp4)
            _buildBannerVideo(),
            const SizedBox(height: 18),
            // Quick Actions title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MAIN ARSENAL',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: Color(0xFFF1F5F9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '6 Modules Online',
                  style: TextStyle(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLightQuickActions(),
            const SizedBox(height: 18),
            // Broadcast / News
            _buildBugPromoBanner(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLightUserCard() {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: kCyan.withOpacity(0.15),
                child: _profileImage != null
                    ? ClipOval(child: Image.file(_profileImage!, width: 52, height: 52, fit: BoxFit.cover))
                    : ClipOval(
                        child: Image.asset(
                          'assets/images/reze.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: kCyan, size: 28),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kOrange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCDD2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(dateStr, style: const TextStyle(color: Color(0xFFC62828), fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat(Icons.phone_android, 'DEVICE', androidId.length > 10 ? androidId.substring(0, 10) : androidId),
              const SizedBox(width: 8),
              _miniStat(Icons.battery_charging_full, 'BATTERY', '—'),
              const SizedBox(width: 8),
              _miniStat(Icons.devices, 'DEVICES', '$activeConns'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: kCardAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: kWhite54),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 9, color: kWhite54, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalChatTeaser() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: Color(0xFF0277BD), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GLOBAL CHAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF01579B), letterSpacing: 0.5)),
                SizedBox(height: 2),
                Text('Tap to open public chat', style: TextStyle(fontSize: 12, color: Color(0xFF0277BD))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF0277BD)),
        ],
      ),
    );
  }

  Widget _buildBugPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1527),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withOpacity(0.12),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
            ),
            child: const Icon(Icons.campaign_rounded, color: Color(0xFF00E5FF), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM BROADCAST',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  newsList.isNotEmpty
                      ? (newsList.first['title']?.toString() ?? 'NDIKA BASE PROTOCOL ACTIVE')
                      : 'NDIKA BASE v6.0.0 is running with maximum stability and security.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingBotCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1527),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.12),
            blurRadius: 16,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
                ),
                child: const Icon(FontAwesomeIcons.whatsapp, color: Color(0xFF22C55E), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PAIRING BOT WA',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: Color(0xFFF1F5F9),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                          ),
                          child: const Text(
                            'READY',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Hubungkan nomor WA via kode pairing 8 digit untuk aktifkan bot sender',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  _slideRoute(BugSenderPage(
                    sessionKey: sessionKey,
                    username: username,
                    role: role,
                  )),
                );
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text(
                'PAIRING BOT / KELOLA SENDER',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: const Color(0xFF070B14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightQuickActions() {
    final actions = [
      {
        'icon': FontAwesomeIcons.whatsapp,
        'title': 'Pairing Bot WA',
        'sub': 'Kode pairing & kelola sender',
        'color': const Color(0xFF22C55E),
        'gradient': [const Color(0xFF22C55E), const Color(0xFF16A34A)],
        'tap': () {
          Navigator.push(
            context,
            _slideRoute(BugSenderPage(
              sessionKey: sessionKey,
              username: username,
              role: role,
            )),
          );
        }
      },
      {
        'icon': Icons.bug_report_rounded,
        'title': 'WA Sender',
        'sub': 'Bug & crash payload sender',
        'color': const Color(0xFFEF4444),
        'gradient': [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
        'tap': () {
          setState(() => _navIndex = 1);
        }
      },
      {
        'icon': Icons.construction_rounded,
        'title': 'Arsenal Hub',
        'sub': 'OSINT, Panel & Downloader',
        'color': const Color(0xFF00E5FF),
        'gradient': [const Color(0xFF00E5FF), const Color(0xFF0284C7)],
        'tap': () {
          setState(() => _navIndex = 3);
        }
      },
      {
        'icon': Icons.apps_rounded,
        'title': 'System Menu',
        'sub': 'Spam OTP & Pairing flood',
        'color': const Color(0xFF9D4EDD),
        'gradient': [const Color(0xFF9D4EDD), const Color(0xFF6B21A8)],
        'tap': () {
          setState(() => _navIndex = 4);
        }
      },
      {
        'icon': Icons.history_rounded,
        'title': 'Activity Logs',
        'sub': 'Riwayat & status eksekusi',
        'color': const Color(0xFF10B981),
        'gradient': [const Color(0xFF10B981), const Color(0xFF047857)],
        'tap': () {
          Navigator.push(context, _slideRoute(RiwayatPage(sessionKey: sessionKey, role: role)));
        }
      },
      {
        'icon': Icons.person_rounded,
        'title': 'Profil Akun',
        'sub': 'Status akun & role user',
        'color': const Color(0xFFF59E0B),
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        'tap': () {
          Navigator.push(
            context,
            _slideRoute(ProfilePage(
              username: username,
              password: password,
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            )),
          );
        }
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, i) {
        final a = actions[i];
        final grad = a['gradient'] as List<Color>;
        final col = a['color'] as Color;

        return GestureDetector(
          onTap: a['tap'] as void Function(),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E3255)),
              boxShadow: [
                BoxShadow(
                  color: col.withOpacity(0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(a['icon'] as IconData, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Text(
                  a['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF1F5F9),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  a['sub'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerVideo() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_menuVideoCtrl != null && _menuVideoCtrl!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _menuVideoCtrl!.value.size.width,
                  height: _menuVideoCtrl!.value.size.height,
                  child: VideoPlayer(_menuVideoCtrl!),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A1A2E), Color(0xFF0D2137), Color(0xFF061018)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
              ),
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.black.withOpacity(0.80),
                  ],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Top tag
            Positioned(
              top: 14, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.55),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('OFFICIAL SHOWCASE',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 9,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom title & logo branding
            Positioned(
              left: 16, bottom: 14, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.7)),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'NDIKA BASE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.5,
                          shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 14)],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.7)),
                      color: const Color(0xFF00E5FF).withOpacity(0.18),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: Color(0xFF00E5FF), size: 13),
                        SizedBox(width: 4),
                        Text('LIVE',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Welcome Card ──────────────────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";
    final isPermanent = expiredDate.toLowerCase().contains('permanent') || 
                        expiredDate.toLowerCase().contains('lifetime') ||
                        expiredDate == '0' || expiredDate.isEmpty;

    // Dark neon palette matching screenshot
    const Color cardBg = Color(0xFF0D1526);
    const Color cardBorder = Color(0xFF00E5FF);
    const Color cyan = Color(0xFF00E5FF);
    const Color purple = Color(0xFF9B5CFF);
    const Color orange = Color(0xFFFFB300);
    const Color green = Color(0xFF00E676);
    const Color fieldBg = Color(0xFF121A2B);

    String shortDevice = deviceModel;
    if (deviceBrand.isNotEmpty) {
      shortDevice = '$deviceBrand $deviceModel';
    }
    if (shortDevice.length > 14) shortDevice = shortDevice.substring(0, 14) + '...';

    String shortSession = sessionKey.length > 8 
        ? sessionKey.substring(0, 8).toUpperCase() 
        : sessionKey.toUpperCase();

    return Column(
      children: [
        // ═══════════════ TOP WELCOME CARD ═══════════════
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cyan.withOpacity(0.35), width: 1.2),
            boxShadow: [
              BoxShadow(color: cyan.withOpacity(0.15), blurRadius: 24, spreadRadius: 1),
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                // Hexagon pattern
                Positioned.fill(
                  child: CustomPaint(painter: _HexagonPatternPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo circle
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF7B2FFF), Color(0xFFFF00AA)],
                              ),
                              boxShadow: [
                                BoxShadow(color: cyan.withOpacity(0.5), blurRadius: 14, spreadRadius: 1),
                              ],
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0A0E17),
                              ),
                              child: ClipOval(
                                child: _profileImage != null
                                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                                    : Image.asset(
                                        'assets/images/reze.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/logo.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: cyan, size: 28),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Selamat Datang,',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 12,
                                    fontFamily: 'Orbitron',
                                  )),
                                const SizedBox(height: 2),
                                Text(username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Orbitron',
                                    letterSpacing: 0.5,
                                  )),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: purple.withOpacity(0.7)),
                                    color: purple.withOpacity(0.15),
                                  ),
                                  child: Text(role.toUpperCase(),
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    )),
                                ),
                              ],
                            ),
                          ),
                          // EXPIRES badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: orange.withOpacity(0.55)),
                              color: const Color(0xFF1A1520),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.power_settings_new, size: 11, color: orange.withOpacity(0.9)),
                                    const SizedBox(width: 3),
                                    Text('EXPIRES',
                                      style: TextStyle(
                                        color: orange.withOpacity(0.85),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                      )),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(isPermanent ? 'PERMANENT' : (expiredDate.length > 10 ? expiredDate.substring(0, 10) : expiredDate),
                                  style: const TextStyle(
                                    color: orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Powered by bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1220).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cyan.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AnimatedDot(color: cyan, size: 5),
                            const SizedBox(width: 8),
                            Text('NDIKA BASE PROTOCOL • @NdikaOfficial',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Orbitron',
                                letterSpacing: 0.8,
                              )),
                            const SizedBox(width: 8),
                            _AnimatedDot(color: cyan, size: 5),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ═══════════════ DASHBOARD CARD ═══════════════
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cyan.withOpacity(0.28), width: 1.1),
            boxShadow: [
              BoxShadow(color: cyan.withOpacity(0.1), blurRadius: 20, spreadRadius: 1),
              BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.dashboard_rounded, color: cyan, size: 18),
                  const SizedBox(width: 8),
                  const Text('DASHBOARD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.5,
                    )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: purple.withOpacity(0.2),
                      border: Border.all(color: purple.withOpacity(0.55)),
                    ),
                    child: Text(isPermanent ? 'PERMANENT' : 'ACTIVE',
                      style: const TextStyle(
                        color: purple,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      )),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Remaining Time
              Text('Remaining Time',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: isPermanent ? 1.0 : 0.65,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(purple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(isPermanent ? 'PERMANENT' : expiredDate,
                    style: TextStyle(
                      color: purple.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
                ],
              ),
              const SizedBox(height: 14),

              // Stats grid 3 columns x 4 rows
              _buildDarkSysGrid([
                _SysItem(icon: Icons.workspace_premium_rounded, label: 'ROLE', value: role.toUpperCase(), color: purple),
                _SysItem(icon: Icons.calendar_today_rounded, label: 'EXPIRED', value: isPermanent ? 'PERMANENT' : (expiredDate.length > 10 ? expiredDate.substring(0, 10) : expiredDate), color: orange),
                _SysItem(icon: Icons.people_rounded, label: 'ONLINE', value: '$onlineUsers Users', color: green),
                _SysItem(icon: Icons.phone_android_rounded, label: 'DEVICE', value: shortDevice, color: cyan),
                _SysItem(icon: Icons.battery_charging_full_rounded, label: 'BATTERY', value: '$batteryPercent% $batteryStatus', color: green),
                _SysItem(icon: Icons.wifi_rounded, label: 'NETWORK', value: 'WiFi $wifiPercent%', color: cyan),
                _SysItem(icon: Icons.memory_rounded, label: 'RAM', value: '$ramUsedMb / ${ramTotalMb}MB', color: cyan),
                _SysItem(icon: Icons.storage_rounded, label: 'STORAGE', value: '$storageUsedGb / ${storageTotalGb}GB', color: cyan),
                _SysItem(icon: Icons.settings_rounded, label: 'SYSTEM', value: 'API $sdkInt', color: cyan),
                _SysItem(icon: Icons.vpn_key_rounded, label: 'SESSION', value: shortSession, color: cyan),
                _SysItem(icon: Icons.link_rounded, label: 'CONN', value: '$activeConns Active', color: green),
                _SysItem(icon: Icons.access_time_rounded, label: 'TIME', value: timeStr, color: orange),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDarkSysGrid(List<_SysItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gap = 8;
        final double itemW = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            final bool hasBar = item.label == 'RAM' || item.label == 'STORAGE';
            double progress = 0.6;
            if (item.label == 'RAM' && ramTotalMb > 0) {
              progress = (ramUsedMb / ramTotalMb).clamp(0.0, 1.0);
            } else if (item.label == 'STORAGE' && storageTotalGb > 0) {
              progress = (storageUsedGb / storageTotalGb).clamp(0.0, 1.0);
            }

            return SizedBox(
              width: itemW,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF121A2B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.color.withOpacity(0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, color: item.color, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.label,
                            style: TextStyle(
                              color: item.color.withOpacity(0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                    if (hasBar) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3.5,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(item.color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSysGrid(List<_SysItem> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 28 - 32 - 16) / 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: kCardAlt.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(item.icon, color: item.color, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(item.label,
                        style: TextStyle(color: item.color.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                        overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(item.value,
                  style: const TextStyle(color: kWhite, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCircleStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
              border: Border.all(color: color.withOpacity(0.6), width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 14, spreadRadius: 2)],
            ),
            child: Center(child: Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: kWhite, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron')),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kWhite54, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatDivider() =>
      Container(width: 1, height: 60, color: kBorder.withOpacity(0.5));

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActionsSection() {
    final actions = [
      _QuickActionData(
        icon: FontAwesomeIcons.whatsapp,
        bgIcon: FontAwesomeIcons.whatsapp,
        title: 'Manage Sender',
        subtitle: 'Manage your active sender',
        gradient: [const Color(0xFFE91E8C), const Color(0xFFAD1457)],
        onTap: () => Navigator.push(
          context,
          _slideRoute(BugSenderPage(sessionKey: sessionKey, username: username, role: role)),
        ).then((_) {
          if (mounted && _newsPageCtrl.hasClients) {
            setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
            _newsPageCtrl.jumpToPage(0);
          }
        }),
      ),
      _QuickActionData(
        icon: FontAwesomeIcons.telegram,
        bgIcon: FontAwesomeIcons.telegram,
        title: 'Join Channel',
        subtitle: 'Ndika Info Channel',
        gradient: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
        onTap: () => _openUrl('https://t.me/NdikaOfficial'),
      ),
      _QuickActionData(
        icon: FontAwesomeIcons.bookQuran,
        bgIcon: FontAwesomeIcons.bookQuran,
        title: 'Al Quran',
        subtitle: 'Baca Al-Quran',
        gradient: [const Color(0xFF7C4DFF), const Color(0xFF4A148C)],
        onTap: () => Navigator.push(context, _slideRoute(AlQuranPage())),
      ),
      _QuickActionData(
        icon: Icons.construction_rounded,
        bgIcon: Icons.construction_rounded,
        title: 'Arsenal Hub',
        subtitle: 'OSINT & Utilities Suite',
        gradient: [const Color(0xFF00E5FF), const Color(0xFF0284C7)],
        onTap: () => setState(() => _navIndex = 3),
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kYellow.withOpacity(0.18),
                  border: Border.all(color: kYellow.withOpacity(0.3)),
                ),
                child: const Icon(Icons.bolt_rounded, color: kYellow, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUICK ACTIONS',
                      style: TextStyle(
                        color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                        fontFamily: 'Orbitron', letterSpacing: 1)),
                  Text('Beberapa Menu Tambahan',
                      style: TextStyle(color: kWhite54, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: kYellow.withOpacity(0.15),
                  border: Border.all(color: kYellow.withOpacity(0.4)),
                ),
                child: Row(children: [
                  Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: kYellow)),
                  const SizedBox(width: 5),
                  const Text('NDIKA',
                      style: TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _qaPageCtrl,
            itemCount: actions.length,
            onPageChanged: (index) {
              if (mounted) setState(() => _currentQaPage = index.toDouble());
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildQuickActionCard(actions[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(actions.length, (index) {
            final bool isActive = _currentQaPage.round() == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive ? kYellow : Colors.white24,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_QuickActionData action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              colors: action.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: action.gradient.first.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12, bottom: -12,
              child: Icon(action.bgIcon, color: Colors.white.withOpacity(0.08), size: 110),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white.withOpacity(0.22)),
                    child: Icon(action.icon, color: kWhite, size: 24),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.22)),
                      child: const Text('Tap →',
                          style: TextStyle(color: kWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(action.title,
                      style: const TextStyle(
                        color: kWhite, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Orbitron')),
                  const SizedBox(height: 4),
                  Text(action.subtitle,
                      style: TextStyle(color: kWhite.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Latest Updates ────────────────────────────────────────────────────────
  Widget _buildLatestUpdates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded, color: kOrange, size: 22),
              const SizedBox(width: 8),
              const Text('LATEST UPDATES',
                  style: TextStyle(
                    color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                    fontFamily: 'Orbitron', letterSpacing: 1)),
              const Spacer(),
              if (newsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: kOrange.withOpacity(0.15),
                    border: Border.all(color: kOrange.withOpacity(0.4)),
                  ),
                  child: Text('${newsList.length} Updates',
                      style: const TextStyle(
                          color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (newsList.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: newsList.length,
              itemBuilder: (ctx, i) => _buildNewsCardHorizontal(newsList[i]),
            ),
          ),
        if (newsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: kCard,
                  border: Border.all(color: kBorder.withOpacity(0.4))),
              child: const Center(
                  child: Text('No updates available', style: TextStyle(color: kWhite54))),
            ),
          ),
      ],
    );
  }

  Widget _buildNewsCardHorizontal(dynamic item) {
    final imgUrl   = item['image']?.toString() ?? '';
    final title    = item['title']?.toString() ?? 'No Title';
    final date     = item['date']?.toString() ?? item['created_at']?.toString() ?? '';
    final cardWidth = (MediaQuery.of(context).size.width / 2) - 22;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: kCard,
        border: Border.all(color: kBorder.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                Container(
                  height: 110, width: double.infinity, color: kCardAlt,
                  child: imgUrl.isNotEmpty
                      ? Image.network(imgUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported, color: kWhite54, size: 30)))
                      : const Center(
                          child: Icon(Icons.article_rounded, color: kWhite54, size: 30)),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.65),
                      border: Border.all(color: kOrange.withOpacity(0.7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle_notifications_rounded, color: kOrange, size: 10),
                        SizedBox(width: 3),
                        Text('NEW',
                            style: TextStyle(
                                color: kOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Text(title,
                style: const TextStyle(
                  color: kWhite, fontSize: 16, fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron', height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: kWhite54, size: 11),
                const SizedBox(width: 4),
                if (date.isNotEmpty)
                  Expanded(
                    child: Text(
                        date.length > 10 ? date.substring(0, 10) : date,
                        style: const TextStyle(color: kWhite54, fontSize: 10)),
                  ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: kOrange.withOpacity(0.18)),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: kOrange, size: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Prayer Section ────────────────────────────────────────────────────────
  Widget _buildPrayerSection() {
    final prayerColors = [
      const Color(0xFF5B4FD4),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFF1E88E5),
      const Color(0xFF1565C0),
    ];
    final prayerIcons = [
      Icons.nights_stay_rounded,
      Icons.wb_sunny_rounded,
      Icons.cloud_rounded,
      Icons.wb_twilight_rounded,
      Icons.nightlight_round,
    ];
    final prayerKeys = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kGreen.withOpacity(0.2),
                    border: Border.all(color: kGreen.withOpacity(0.4)),
                  ),
                  child: const Center(child: Icon(Icons.mosque, color: kGreen, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('JADWAL SHOLAT',
                          style: TextStyle(
                            color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                            fontFamily: 'Orbitron', letterSpacing: 1)),
                      Text(_prayerCity,
                          style: const TextStyle(color: kWhite54, fontSize: 12)),
                    ],
                  ),
                ),
                // Tombol auto-detect lokasi
                GestureDetector(
                  onTap: _locationLoading ? null : _detectLocationAndFetchPrayer,
                  child: Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _locationGranted
                          ? kGreen.withOpacity(0.2)
                          : kWhite24.withOpacity(0.1),
                      border: Border.all(
                        color: _locationGranted
                            ? kGreen.withOpacity(0.6)
                            : kWhite54.withOpacity(0.3),
                      ),
                    ),
                    child: _locationLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: kGreen, strokeWidth: 2),
                          )
                        : Icon(
                            _locationGranted
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            color: _locationGranted ? kGreen : kWhite54,
                            size: 18,
                          ),
                  ),
                ),
                // Tombol ganti manual
                GestureDetector(
                  onTap: _showChangeCityDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: kGreen,
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('GANTI',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Next prayer badge ──
            if (_nextPrayerLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: _AnimatedDot(color: kOrange, size: 10),
                    ),
                    const SizedBox(width: 10),
                    Text('Menuju $_nextPrayerLabel : $_nextPrayerTime',
                        style: const TextStyle(
                          color: kWhite, fontSize: 13, fontWeight: FontWeight.w600,
                          fontFamily: 'Orbitron')),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGreen.withOpacity(0.5)),
                      ),
                      child: const Text('NDIKA',
                          style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // ── Prayer time cards ──
            if (_prayerLoading)
              const Center(child: CircularProgressIndicator(color: kGreen, strokeWidth: 2))
            else
              SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: prayerKeys.length,
                  itemBuilder: (ctx, i) {
                    final key   = prayerKeys[i];
                    final time  = _prayerTimes[key] ?? '--:--';
                    final color = prayerColors[i];
                    final icon  = prayerIcons[i];
                    final isNext = key == _nextPrayerLabel;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.only(right: 10, bottom: isNext ? 0 : 6, top: isNext ? 0 : 6),
                      width: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: color,
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(isNext ? 0.65 : 0.3),
                              blurRadius: isNext ? 18 : 8, offset: const Offset(0, 4))
                        ],
                        border: isNext
                            ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.white, size: 24),
                            const SizedBox(height: 5),
                            Text(key.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9,
                                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            const SizedBox(height: 5),
                            Text(time,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 19,
                                    fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hadith Section ────────────────────────────────────────────────────────
  Widget _buildHadithSection() {
    if (_hadithLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder.withOpacity(0.5)),
          ),
          child: const Center(child: CircularProgressIndicator(color: kCyan, strokeWidth: 2)),
        ),
      );
    }

    final arabic = _hadith?['data']?['text']?['ar'] ??
        'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى';
    final indo   = _hadith?['data']?['text']?['id'] ??
        'Sesungguhnya setiap amalan tergantung pada niatnya.';
    final number = _hadith?['data']?['id']?.toString() ?? '1';
    final source = _hadith?['data']?['source']?.toString() ?? 'Muslim';
    final grade  = _hadith?['data']?['grade']?.toString() ?? 'Sahih Muslim';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: kCyan.withOpacity(0.18)),
                  child: const Center(child: Icon(Icons.menu_book_rounded, color: kCyan, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('HADITH OF THE DAY',
                        style: TextStyle(
                          color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                          fontFamily: 'Orbitron', letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('$grade · Tap card to read full',
                        style: const TextStyle(color: kWhite54, fontSize: 11)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _showHadithFullDialog(arabic, indo, source, number, grade),
              child: Column(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF1A1F2E),
                      border: Border.all(color: kBorder.withOpacity(0.3)),
                    ),
                    child: Text(arabic,
                        textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                        style: const TextStyle(color: kWhite, fontSize: 17, height: 2.0)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14), color: const Color(0xFF141824)),
                    child: Text(indo,
                        style: const TextStyle(
                          color: kWhite54, fontSize: 12, fontStyle: FontStyle.italic, height: 1.7),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kCyan.withOpacity(0.45)),
                    color: kCyan.withOpacity(0.07),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long_rounded, color: kCyan, size: 13),
                    const SizedBox(width: 5),
                    Text('${source.isNotEmpty ? source : "Muslim"} #$number',
                        style: const TextStyle(
                            color: kCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _fetchRandomHadith,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kWhite54.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_rounded, color: kWhite54, size: 14),
                      SizedBox(width: 4),
                      Text('Tap card', style: TextStyle(color: kWhite54, fontSize: 11)),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isMenu = _navIndex == 4;
    return Scaffold(
      backgroundColor: isMenu ? const Color(0xFF05080F) : kBg,
      extendBodyBehindAppBar: false,
      appBar: isMenu ? null : _buildAppBar(),
      drawer: isMenu ? null : _buildDrawer(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_navIndex),
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBackgroundGrid() {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPatternPainter(
        gridColor: kCyan.withOpacity(0.04),
        lineColor: kPink.withOpacity(0.02),
        spacing: 35,
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF070B14),
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3255)),
            ),
            child: const Icon(Icons.menu_rounded, color: Color(0xFF00E5FF), size: 20),
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E3255)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 22, height: 22, fit: BoxFit.cover,
                errorBuilder: (_,__,___) => const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF00E5FF))),
            ),
            const SizedBox(width: 8),
            const Text(
              'NDIKA BASE',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00E5FF),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3255)),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF00E5FF), size: 20),
          ),
          onPressed: () => Navigator.push(
            context,
            _slideRoute(ProfilePage(
              username: username, password: password,
              role: role, expiredDate: expiredDate, sessionKey: sessionKey,
            )),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.grid_view_rounded, 'label': 'Home', 'index': 0},
      {'icon': FontAwesomeIcons.whatsapp, 'label': 'WA', 'index': 1},
      {'icon': Icons.build_rounded, 'label': 'Arsenal', 'index': 3},
      {'icon': Icons.notifications_none_rounded, 'label': 'Info', 'index': 2},
      {'icon': Icons.apps_rounded, 'label': 'Menu', 'index': 4},
    ];

    final bool isMenuPage = _navIndex == 4;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        border: Border(top: BorderSide(color: const Color(0xFF1E3255).withOpacity(0.8), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1527),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1E3255)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final targetIndex = item['index'] as int;
              final bool active = _navIndex == targetIndex;

              return GestureDetector(
                onTap: () => _onNavTap(targetIndex),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: active
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.35),
                              blurRadius: 8,
                            ),
                          ],
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: active
                            ? const Color(0xFF070B14)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      if (active) ...[
                        const SizedBox(height: 2),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            color: Color(0xFF070B14),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kBg,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          Container(
            height: 240,
            color: Colors.black,
            child: Stack(
              children: [
                if (_menuVideoCtrl != null && _menuVideoCtrl!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _menuVideoCtrl!.value.size.width,
                        height: _menuVideoCtrl!.value.size.height,
                        child: VideoPlayer(_menuVideoCtrl!),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kCyan.withOpacity(0.6), width: 2.5),
                            boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 14, spreadRadius: 2)],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : Image.asset(
                                    'assets/images/reze.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(FontAwesomeIcons.userAstronaut, size: 38, color: kWhite),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(username,
                            style: const TextStyle(
                                color: kWhite, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                        Text(role.toUpperCase(),
                            style: const TextStyle(color: kCyan, fontSize: 12, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: kBg,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  if (role == 'reseller')
                    _buildDrawerItem(
                        icon: Icons.storefront_rounded,
                        label: 'Seller Page',
                        onTap: () => _onDrawerNav(1)),
                  if (role == 'admin')
                    _buildDrawerItem(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin Page',
                        onTap: () => _onDrawerNav(2)),
                  if (role == 'owner')
                    _buildDrawerItem(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Owner Page',
                        onTap: () => _onDrawerNav(3)),
                  _buildDrawerItem(
                    icon: FontAwesomeIcons.whatsapp,
                    label: 'Pairing Bot WA',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        _slideRoute(BugSenderPage(
                          sessionKey: sessionKey,
                          username: username,
                          role: role,
                        )),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Aktivitas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          _slideRoute(RiwayatPage(sessionKey: sessionKey, role: role))).then((_) {
                        if (mounted && _newsPageCtrl.hasClients) {
                          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
                          _newsPageCtrl.jumpToPage(0);
                        }
                      });
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Ganti Password',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        _slideRoute(ChangePasswordPage(username: username, sessionKey: sessionKey)),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isLogout ? Colors.red.withOpacity(0.08) : kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLogout ? Colors.red.withOpacity(0.3) : kBorder.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.redAccent : kCyan, size: 20),
        title: Text(label,
            style: TextStyle(
                color: isLogout ? Colors.redAccent : kWhite,
                fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: kWhite24, size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}

// ─── Quick Action Data ─────────────────────────────────────────────────────────
class _QuickActionData {
  final IconData icon;
  final IconData bgIcon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _QuickActionData({
    required this.icon,
    required this.bgIcon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Slide Route ──────────────────────────────────────────────────────────────
PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 350),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
);

// ─── NewsMedia ────────────────────────────────────────────────────────────────
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});
  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _ctrl;
  bool _isVideo(String url) =>
      url.endsWith('.mp4') || url.endsWith('.webm') ||
      url.endsWith('.mov') || url.endsWith('.mkv');
  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _ctrl?.setLooping(true);
          _ctrl?.setVolume(0.0);
          _ctrl?.play();
        });
    }
  }
  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_ctrl != null && _ctrl!.value.isInitialized) {
        return AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!));
      }
      return const Center(child: CircularProgressIndicator(color: kCyan, strokeWidth: 2));
    }
    return Image.network(
      widget.url, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: kCard, child: const Icon(Icons.error_rounded, color: kWhite24)),
    );
  }
}
