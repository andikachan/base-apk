import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'manage_server.dart';
import 'wifi_internal.dart';
import 'wifi_external.dart';
import 'ddos_panel.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';
import 'phone_lookup.dart';
import 'email_osint.dart';
import 'ip_scanner.dart';
import 'port_scanner.dart';
import 'dracin_page.dart';
import 'device_dashboard.dart';
import 'anime_home.dart';
import 'hentai.dart';

// ─── Palette: Biru ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF0A0F1A);
  static const surface   = Color(0xFF0D1525);
  static const card      = Color(0xFF111C30);
  static const cardInner = Color(0xFF162035);
  static const border    = Color(0xFF1C2E48);
  static const borderLit = Color(0xFF1E3A5F);

  static const steel     = Color(0xFF1A4F8A);
  static const blueMid   = Color(0xFF2370BE);
  static const blueLight = Color(0xFF4A94E8);
  static const chrome    = Color(0xFF7AB4E8);
  static const frost     = Color(0xFFADD4F5);

  // accent per kategori
  static const red       = Color(0xFFEF4444);
  static const amber     = Color(0xFFF59E0B);
  static const green     = Color(0xFF22C55E);
  static const purple    = Color(0xFFA78BFA);
  static const pink      = Color(0xFFEC4899);
  static const teal      = Color(0xFF14B8A6);
  static const blue      = Color(0xFF3B82F6);

  static const text      = Color(0xFFDEEEFB);
  static const textSub   = Color(0xFF6A92B8);
  static const textDim   = Color(0xFF2E4E6E);

  static const LinearGradient metalGrad = LinearGradient(
    colors: [steel, blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Tool Category Data ───────────────────────────────────────────────────────
class _ToolCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ToolCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

// 6 kategori mirip gambar (Panel, Network, OSINT, Downloader, Utilities, Quick)
const _categories = [
  _ToolCategory(
    id: 'panel',
    title: 'Manage Server',
    subtitle: 'Server Control',
    icon: Icons.cloud_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
    id: 'ddos',
    title: 'DDoS',
    subtitle: 'Take Down',
    icon: Icons.bolt_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
    id: 'network',
    title: 'Network',
    subtitle: 'WiFi Arsenal',
    icon: Icons.wifi_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
    id: 'osint',
    title: 'OSiNT',
    subtitle: 'Deep Search',
    icon: Icons.search_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
    id: 'downloader',
    title: 'Downloader',
    subtitle: 'Media Saver',
    icon: Icons.download_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
    id: 'utilities',
    title: 'Utilities',
    subtitle: 'Extra Tools',
    icon: Icons.construction_rounded,
    accent: _C.blue,
  ),
  _ToolCategory(
  id: 'watchs',
  title: 'Watch Video',
  subtitle: 'Stream & Watch',
  icon: Icons.play_circle_rounded,
  accent: _C.blue,
  ),
  _ToolCategory(
  id: 'ratcontrol',
  title: 'RAT NDIKA CONTROL',
  subtitle: 'Remote Access',
  icon: Icons.devices_rounded,
  accent: _C.blue,
  ),
  _ToolCategory(
  id: 'adulthub',
  title: 'Adult Hub',
  subtitle: '18+ Only',
  icon: Icons.lock_rounded,
  accent: _C.blue,
  ),
];

// ─── Page ─────────────────────────────────────────────────────────────────────
class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.push(context, _slideRoute(page));

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Coming Soon!',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _C.blueMid,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _onCategoryTap(String id) {
    switch (id) {
      case 'panel':
        _showSheet(_panelItems());
        break;
      case 'ddos':
        _showSheet(_ddosItems());
        break;
      case 'network':
        _showSheet(_networkItems());
        break;
      case 'osint':
        _showSheet(_osintItems());
        break;
      case 'downloader':
        _showSheet(_downloaderItems());
        break;
      case 'utilities':
        _showSheet(_utilityItems());
        break;
      case 'watchs':
        _showSheet(_watchsItems());
        break;
      case 'ratcontrol':
        _showSheet(_ratcontrolItems());
        break;
      case 'adulthub':
        _showSheet(_adulthubItems());
        break;
    }
  }

  List<_ToolItem> _panelItems() => [
        _ToolItem(
            icon: Icons.dns_rounded,
            label: 'Manage Server',
            accent: _C.blue,
            onTap: () => _push(
                ManageServerPage(keyToken: widget.sessionKey))),
      ];

  List<_ToolItem> _ddosItems() => [
        _ToolItem(
            icon: Icons.bolt_rounded,
            label: 'Attack Panel',
            accent: _C.blue,
            onTap: () => _push(AttackPanel(
                sessionKey: widget.sessionKey,
                listDoos: widget.listDoos))),
      ];

  List<_ToolItem> _networkItems() => [
        _ToolItem(
            icon: Icons.newspaper_outlined,
            label: 'Spam NGL',
            accent: _C.blue,
            onTap: () => _push(NglPage())),
        _ToolItem(
            icon: Icons.wifi_off_rounded,
            label: 'WiFi Killer (Internal)',
            accent: _C.blue,
            onTap: () => _push(WifiKillerPage())),
        if (widget.userRole == 'vip' || widget.userRole == 'owner')
          _ToolItem(
              icon: Icons.router_rounded,
              label: 'WiFi Killer (External)',
              accent: _C.blue,
              onTap: () => _push(
                  WifiInternalPage(sessionKey: widget.sessionKey))),
      ];

  List<_ToolItem> _osintItems() => [
        _ToolItem(
            icon: Icons.badge_outlined,
            label: 'NIK Detail',
            accent: _C.blue,
            onTap: () => _push(const NikCheckerPage())),
        _ToolItem(
            icon: Icons.travel_explore_rounded,
            label: 'Domain OSINT',
            accent: _C.blue,
            onTap: () => _push(const DomainOsintPage())),
        _ToolItem(
            icon: Icons.person_search_rounded,
            label: 'Phone Lookup',
            accent: _C.blue,
            onTap: () => _push(const PhoneLookupPage())),
        _ToolItem(
            icon: Icons.alternate_email_rounded,
            label: 'Email OSINT',
            accent: _C.blue,
            onTap: () => _push(const EmailOsintPage())),
      ];

  List<_ToolItem> _downloaderItems() => [
        _ToolItem(
            icon: Icons.video_library_rounded,
            label: 'TikTok Downloader',
            accent: _C.blue,
            onTap: () => _push(const TiktokDownloaderPage())),
        _ToolItem(
            icon: Icons.camera_alt_rounded,
            label: 'Instagram Downloader',
            accent: _C.blue,
            onTap: () => _push(const InstagramDownloaderPage())),
      ];

  List<_ToolItem> _utilityItems() => [
        _ToolItem(
            icon: Icons.qr_code_2_rounded,
            label: 'QR Generator',
            accent: _C.blue,
            onTap: () => _push(const QrGeneratorPage())),
        _ToolItem(
            icon: Icons.security_rounded,
            label: 'IP Scanner',
            accent: _C.blue,
            onTap: () => _push(const IpScannerPage())),
        _ToolItem(
            icon: Icons.network_check_rounded,
            label: 'Port Scanner',
            accent: _C.blue,
            onTap: () => _push(const PortScannerPage())),
      ];
      
  List<_ToolItem> _watchsItems() => [
        _ToolItem(
            icon: Icons.animation_rounded,
            label: 'Anime',
            accent: _C.blue,
            onTap: () => _push(const HomeAnimePage())),
        _ToolItem(
            icon: Icons.play_circle_rounded,
            label: 'Dracin',
            accent: _C.blue,
            onTap: () => _push(const DracinPage())),
      ];
      
  List<_ToolItem> _ratcontrolItems() => [
        _ToolItem(
            icon: Icons.devices_rounded,
            label: 'RAT Panel',
            accent: _C.blue,
            onTap: () => _push(const DeviceDashboardPage())),
      ];
      
  List<_ToolItem> _adulthubItems() => [
        _ToolItem(
            icon: Icons.favorite_rounded,
            label: 'Hentai',
            accent: _C.blue,
            onTap: () => _push(const HomeHentaiPage())),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Headersk ──
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildAppHeader(),
                  ),
                ),

                // ── Section label ──
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    children: [
                      // Garis merah kiri (sama kayak di gambar)
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _C.blueMid,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Tools NDIKA',
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_categories.length} item',
                        style: const TextStyle(
                            color: _C.textSub, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // ── Grid 3 kolom ──
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) => _StaggerItem(
                      index: i,
                      child: _CategoryCard(
                        category: _categories[i],
                        onTap: () =>
                            _onCategoryTap(_categories[i].id),
                      ),
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

  // ── App bar: logo kiri, nama + subtitle tengah, badge kanan ──────────────
  Widget _buildAppHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Logo icon (kotak merah bundar)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A4F8A), Color(0xFF2370BE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _C.blueMid.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'NDIKA GATEWAY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Gateway Tools',
                style:
                    TextStyle(color: _C.textSub, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _C.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('USER',
                    style: TextStyle(
                        color: _C.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

 void _showSheet(List<_ToolItem> items) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,           // ← tambah ini
    builder: (_) => _ToolSheet(items: items),
  );
 }
}

// ─── Category Card ─────────────────────────────────────────────────────────────
// Layout mirip gambar: icon lingkaran besar DI TENGAH atas, judul di bawah, subtitle
class _CategoryCard extends StatefulWidget {
  final _ToolCategory category;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.category, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.15, end: 0.45).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: AnimatedBuilder(
          animation: _glow,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              color: _pressed
                  ? const Color(0xFF162035)
                  : _C.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _pressed
                    ? cat.accent.withOpacity(0.4)
                    : _C.border,
                width: _pressed ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: cat.accent.withOpacity(
                      _pressed ? 0.18 : _glow.value * 0.06),
                  blurRadius: _pressed ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // ── Layout: CENTER ICON ATAS, NAMA, SUBTITLE ──
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lingkaran icon — mirip gambar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cat.accent.withOpacity(
                        _pressed ? 0.2 : 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cat.accent
                          .withOpacity(_pressed ? 0.5 : 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cat.accent.withOpacity(0.15),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(cat.icon,
                      color: cat.accent,
                      size: 26),
                ),

                const SizedBox(height: 10),

                // Nama kategori
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    cat.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                // Subtitle
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    cat.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.textSub,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tool Sheet ───────────────────────────────────────────────────────────────
class _ToolSheet extends StatelessWidget {
  final List<_ToolItem> items;
  const _ToolSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _C.borderLit),
          left: BorderSide(color: _C.border),
          right: BorderSide(color: _C.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle di DALAM container ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.borderLit,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // ── Garis gradient ──
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _C.blueMid,
                  Colors.transparent
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 32),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _StaggerItem(
                index: i,
                child: _ToolRow(
                  item: items[i],
                  onTap: () {
                    Navigator.pop(ctx);
                    items[i].onTap();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tool Row ─────────────────────────────────────────────────────────────────
class _ToolRow extends StatefulWidget {
  final _ToolItem item;
  final VoidCallback onTap;
  const _ToolRow({required this.item, required this.onTap});

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? item.accent.withOpacity(0.08)
              : _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? item.accent.withOpacity(0.35)
                : _C.border,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                      color: item.accent.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accent
                  .withOpacity(_pressed ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: item.accent
                      .withOpacity(_pressed ? 0.4 : 0.2)),
            ),
            child:
                Icon(item.icon, color: item.accent, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                if (item.comingSoon)
                  const Text('Coming Soon',
                      style: TextStyle(
                          color: _C.textSub,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          item.comingSoon
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: _C.amber.withOpacity(0.25)),
                  ),
                  child: const Text('SOON',
                      style: TextStyle(
                          color: _C.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _pressed
                        ? item.accent.withOpacity(0.15)
                        : _C.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _pressed
                          ? item.accent.withOpacity(0.3)
                          : _C.border,
                    ),
                  ),
                  child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color:
                          _pressed ? item.accent : _C.textSub,
                      size: 13),
                ),
        ]),
      ),
    );
  }
}

// ─── Stagger Item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem(
      {required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
          milliseconds:
              350 + (index * 70).clamp(0, 450)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)), child: ch),
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
    final grid = Paint()
      ..color = _C.border.withOpacity(0.22)
      ..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), grid);
    }

    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.steel.withOpacity(
            0.10 + math.sin(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.9)
          .createShader(Rect.fromCircle(
              center: Offset(size.width / 2, 0),
              radius: size.width));
    canvas.drawCircle(
        Offset(size.width / 2, 0), size.width, glow);

    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        _C.blueMid.withOpacity(
            0.05 + math.cos(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.5)
          .createShader(Rect.fromCircle(
              center: Offset(
                  size.width * 0.85, size.height * 0.75),
              radius: size.width * 0.4));
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.75),
        size.width * 0.4,
        glow2);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Page transition ──────────────────────────────────────────────────────────
PageRoute _slideRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, anim, __, child) =>
          SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
            parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );

// ─── Data model ───────────────────────────────────────────────────────────────
class _ToolItem {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool comingSoon;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.comingSoon = false,
  });
}
