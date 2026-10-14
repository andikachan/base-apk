import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'manage_server.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';
import 'phone_lookup.dart';
import 'email_osint.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF070B14);
  static const surface   = Color(0xFF0D1527);
  static const card      = Color(0xFF111D35);
  static const cardInner = Color(0xFF162544);
  static const border    = Color(0xFF1E3255);
  static const borderLit = Color(0xFF2E4E85);

  static const cyan      = Color(0xFF00E5FF);
  static const blueMid   = Color(0xFF0284C7);
  static const purple    = Color(0xFF9D4EDD);
  static const green     = Color(0xFF10B981);
  static const amber     = Color(0xFFF59E0B);
  static const text      = Color(0xFFF1F5F9);
  static const textSub   = Color(0xFF94A3B8);
  static const textDim   = Color(0xFF475569);
}

// ─── Tool Item Model ──────────────────────────────────────────────────────────
class _ToolItem {
  final IconData icon;
  final String label;
  final String desc;
  final Color accent;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.accent,
    required this.onTap,
  });
}

// ─── Tool Category Model ──────────────────────────────────────────────────────
class _ToolCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;

  const _ToolCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.gradient,
  });
}

// ─── Main Tools Page ──────────────────────────────────────────────────────────
class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>>? listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<_ToolCategory> _categories = const [
    _ToolCategory(
      id: 'osint',
      title: 'OSINT Suite',
      subtitle: 'Intelligence & Lookups',
      icon: Icons.fingerprint_rounded,
      accent: _C.cyan,
      gradient: [Color(0xFF00E5FF), Color(0xFF0284C7)],
    ),
    _ToolCategory(
      id: 'panel',
      title: 'Server Admin',
      subtitle: 'Node & API Control',
      icon: Icons.dns_rounded,
      accent: _C.purple,
      gradient: [Color(0xFF9D4EDD), Color(0xFF6200EA)],
    ),
    _ToolCategory(
      id: 'downloader',
      title: 'Media Downloader',
      subtitle: 'TikTok & Instagram',
      icon: Icons.download_for_offline_rounded,
      accent: _C.green,
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    _ToolCategory(
      id: 'utilities',
      title: 'Utilities Arsenal',
      subtitle: 'QR Tools & NGL Flooder',
      icon: Icons.handyman_rounded,
      accent: _C.amber,
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _push(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  List<_ToolItem> _panelItems() => [
    _ToolItem(
      icon: Icons.cloud_sync_rounded,
      label: 'Manage Server',
      desc: 'Restart, logs & status panel server Pterodactyl',
      accent: _C.purple,
      onTap: () => _push(ManageServerPage(keyToken: widget.sessionKey)),
    ),
  ];

  List<_ToolItem> _osintItems() => [
    _ToolItem(
      icon: Icons.badge_rounded,
      label: 'NIK Checker',
      desc: 'Validasi dan identifikasi data NIK KTP',
      accent: _C.cyan,
      onTap: () => _push(const NikCheckerPage()),
    ),
    _ToolItem(
      icon: Icons.travel_explore_rounded,
      label: 'Domain OSINT',
      desc: 'WHOIS, DNS records & reverse IP lookup',
      accent: _C.cyan,
      onTap: () => _push(const DomainOsintPage()),
    ),
    _ToolItem(
      icon: Icons.phone_android_rounded,
      label: 'Phone Lookup',
      desc: 'Pelacak operator, HLR & provider seluler',
      accent: _C.cyan,
      onTap: () => _push(const PhoneLookupPage()),
    ),
    _ToolItem(
      icon: Icons.alternate_email_rounded,
      label: 'Email OSINT',
      desc: 'Verifikasi status email & domain mailbox',
      accent: _C.cyan,
      onTap: () => _push(const EmailOsintPage()),
    ),
  ];

  List<_ToolItem> _downloaderItems() => [
    _ToolItem(
      icon: Icons.video_collection_rounded,
      label: 'TikTok Downloader',
      desc: 'Download video TikTok tanpa watermark HD',
      accent: _C.green,
      onTap: () => _push(const TiktokDownloaderPage()),
    ),
    _ToolItem(
      icon: Icons.camera_alt_rounded,
      label: 'Instagram Downloader',
      desc: 'Download Reels, Post & Story Instagram',
      accent: _C.green,
      onTap: () => _push(const InstagramDownloaderPage()),
    ),
  ];

  List<_ToolItem> _utilityItems() => [
    _ToolItem(
      icon: Icons.qr_code_2_rounded,
      label: 'QR Code Generator',
      desc: 'Buat barcode QR kustom dengan cepat',
      accent: _C.amber,
      onTap: () => _push(const QrGeneratorPage()),
    ),
    _ToolItem(
      icon: Icons.send_and_archive_rounded,
      label: 'Spam NGL',
      desc: 'Automasi pengiriman pesan NGL anonim',
      accent: _C.amber,
      onTap: () => _push(NglPage()),
    ),
  ];

  void _openCategorySheet(_ToolCategory cat) {
    List<_ToolItem> items;
    switch (cat.id) {
      case 'osint':
        items = _osintItems();
        break;
      case 'panel':
        items = _panelItems();
        break;
      case 'downloader':
        items = _downloaderItems();
        break;
      case 'utilities':
        items = _utilityItems();
        break;
      default:
        items = [];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _C.borderLit.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: cat.accent.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _C.borderLit,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: cat.gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.text,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${items.length} Modules Available',
                      style: const TextStyle(fontSize: 12, color: _C.textSub),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: _C.border, height: 1),
            const SizedBox(height: 14),
            ...items.map((it) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.border.withOpacity(0.8)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: it.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: it.accent.withOpacity(0.3)),
                      ),
                      child: Icon(it.icon, color: it.accent, size: 20),
                    ),
                    title: Text(
                      it.label,
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.text,
                      ),
                    ),
                    subtitle: Text(
                      it.desc,
                      style: const TextStyle(fontSize: 11, color: _C.textSub),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.textDim),
                    onTap: () {
                      Navigator.pop(ctx);
                      it.onTap();
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return cat.title.toLowerCase().contains(q) || cat.subtitle.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header HUD ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.cyan.withOpacity(0.35)),
                      boxShadow: [
                        BoxShadow(
                          color: _C.cyan.withOpacity(0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.terminal_rounded, color: _C.cyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NDIKA ARSENAL',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _C.text,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cyber Intelligence & Cloud Suite',
                          style: TextStyle(fontSize: 11, color: _C.textSub, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _C.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.cyan.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, color: _C.cyan, size: 12),
                        SizedBox(width: 4),
                        Text('v6.0', style: TextStyle(color: _C.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.borderLit.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: _C.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari modul atau arsenal tools...',
                    hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: _C.cyan, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: _C.textSub, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Grid of Categories ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final cat = filteredCategories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _C.borderLit.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _openCategorySheet(cat),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: cat.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: cat.accent.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(cat.icon, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.title,
                                    style: const TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _C.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    cat.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _C.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: cat.accent.withOpacity(0.25)),
                              ),
                              child: Icon(Icons.arrow_forward_ios_rounded, color: cat.accent, size: 14),
                            ),
                          ],
                        ),
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
}
