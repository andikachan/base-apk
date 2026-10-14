import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFFA78BFA);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class DomainOsintPage extends StatefulWidget {
  const DomainOsintPage({super.key});

  @override
  State<DomainOsintPage> createState() => _DomainOsintPageState();
}

class _DomainOsintPageState extends State<DomainOsintPage>
    with TickerProviderStateMixin {
  final _domainCtrl = TextEditingController();
  bool _isLoading   = false;
  Map<String, dynamic>? _dnsData;
  List<dynamic>?  _subdomainsData;
  String? _error;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _resultCtrl;

  late Animation<double> _resultFade;
  late Animation<Offset>  _resultSlide;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _scanCtrl.dispose();
    _resultCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _checkDomain() async {
    final domain = _domainCtrl.text.trim();
    if (domain.isEmpty) {
      setState(() { _error = 'Domain tidak boleh kosong.'; _dnsData = null; _subdomainsData = null; });
      return;
    }
    setState(() { _isLoading = true; _error = null; _dnsData = null; _subdomainsData = null; });
    _resultCtrl.reset();

    try {
      final dns    = await _fetchDns(domain);
      final subdos = await _fetchSubdomains(domain);
      if (dns != null || subdos != null) {
        setState(() { _dnsData = dns; _subdomainsData = subdos; });
        _resultCtrl.forward();
      } else {
        setState(() => _error = 'Gagal mengambil data domain.');
      }
    } catch (e) {
      setState(() => _error = 'Koneksi error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchDns(String domain) async {
    final res = await http.get(
        Uri.parse('https://api.siputzx.my.id/api/tools/dns?domain=$domain'));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['status'] == true ? j['data'] : null;
    }
    return null;
  }

  Future<List<dynamic>?> _fetchSubdomains(String domain) async {
    final res = await http.get(
        Uri.parse('https://api.siputzx.my.id/api/tools/subdomains?domain=$domain'));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['status'] == true ? j['data'] : null;
    }
    return null;
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('$label disalin', style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
      backgroundColor: _C.blueMid,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Build helpers ────────────────────────────────────────────────────────
  List<_RecordEntry> _parseRecords() {
    final entries = <_RecordEntry>[];
    if (_dnsData == null) return entries;

    final domain = _dnsData!['unicodeDomain']?.toString();
    if (domain != null) entries.add(_RecordEntry('Domain', domain, copyable: true));
    final pun = _dnsData!['punycodeDomain']?.toString();
    if (pun != null && pun != domain)
      entries.add(_RecordEntry('Punycode', pun, copyable: true));

    final records = _dnsData!['records'] as Map<String, dynamic>?;
    if (records == null) return entries;

    // NS
    final nsAnswer = records['ns']?['response']?['answer'] as List?;
    if (nsAnswer != null) {
      for (final r in nsAnswer) {
        final v = r['record']?['target']?.toString();
        if (v != null) entries.add(_RecordEntry('NS', v, tag: 'NS', copyable: true));
      }
    }

    // A records
    final aAnswer = records['a']?['response']?['answer'] as List?;
    if (aAnswer != null) {
      for (final r in aAnswer) {
        final v = r['record']?['data']?.toString();
        if (v != null) entries.add(_RecordEntry('A Record', v, tag: 'A', copyable: true));
      }
    }

    // SOA
    final soaAnswer = records['soa']?['response']?['answer'] as List?;
    if (soaAnswer != null && soaAnswer.isNotEmpty) {
      final soa = soaAnswer.first['record'];
      if (soa != null) {
        final soaFields = {
          'Primary NS': soa['host'],
          'Admin Email': soa['admin'],
          'Serial': soa['serial'],
          'Refresh': soa['refresh'],
          'Retry': soa['retry'],
          'Expire': soa['expire'],
          'Min TTL': soa['minimum'],
        };
        soaFields.forEach((k, v) {
          if (v != null)
            entries.add(_RecordEntry(k, v.toString(),
                tag: 'SOA', copyable: k == 'Primary NS' || k == 'Admin Email'));
        });
      }
    }

    // Server info
    final serverIp = records['a']?['query']?['server']?['ip']?.toString();
    if (serverIp != null)
      entries.add(_RecordEntry('DNS Server IP', serverIp, tag: 'SRV', copyable: true));

    final loc = records['a']?['query']?['server']?['location'];
    if (loc != null) {
      entries.add(_RecordEntry('Lokasi Server',
          'Lat: ${loc['lat']}, Lon: ${loc['lon']}', tag: 'GEO'));
    }

    return entries;
  }

  List<String> _parseSubdomains() {
    if (_subdomainsData == null) return [];
    return _subdomainsData!
        .map((e) => e.toString().split('\n').last.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('*'))
        .toSet()
        .toList()
      ..sort();
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
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildSearchCard(),
                if (_error != null) _buildErrorBanner(),
                if (_isLoading) _buildScanningIndicator(),
                if ((_dnsData != null || _subdomainsData != null) && !_isLoading)
                  Expanded(child: _buildResults()),
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
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.travel_explore_rounded,
              color: _C.blueLight, size: 16),
        ),
        const SizedBox(width: 10),
        const Text('Domain OSINT',
            style: TextStyle(color: _C.text, fontSize: 17,
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ]),
      centerTitle: true,
    );
  }

  Widget _buildSearchCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(color: _C.blue.withOpacity(0.08),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(children: [
          // Input
          _DomainInput(
            controller: _domainCtrl,
            isLoading: _isLoading,
            onSubmit: _checkDomain,
          ),
          const SizedBox(height: 14),
          // Search button
          _SearchButton(isLoading: _isLoading, onTap: _checkDomain),
        ]),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.red.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: _C.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!,
              style: const TextStyle(color: _C.textSub, fontSize: 13))),
        ]),
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, __) => SizedBox(
                width: 100, height: 100,
                child: CustomPaint(
                  painter: _ScanPainter(_scanCtrl.value),
                  child: Center(
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.blue.withOpacity(0.15),
                        border: Border.all(color: _C.blueMid.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.search_rounded,
                          color: _C.blueLight, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Memindai domain...',
                style: TextStyle(color: _C.textSub, fontSize: 13)),
            const SizedBox(height: 6),
            Text(_domainCtrl.text.trim(),
                style: const TextStyle(color: _C.blueLight, fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final records    = _parseRecords();
    final subdomains = _parseSubdomains();

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Stats row
            _ResultsStatsRow(
              recordCount: records.length,
              subdomainCount: subdomains.length,
              domain: _domainCtrl.text.trim(),
            ),
            const SizedBox(height: 16),

            // DNS Records card
            if (records.isNotEmpty)
              _ResultCard(
                icon: Icons.dns_rounded,
                title: 'DNS Records',
                subtitle: '${records.length} entri ditemukan',
                accentColor: _C.blueMid,
                child: Column(
                  children: records.asMap().entries.map((e) =>
                    _StaggerItem(
                      index: e.key,
                      child: _RecordRow(
                        entry: e.value,
                        onCopy: (v, l) => _copy(v, l),
                      ),
                    )).toList(),
                ),
              ),

            if (records.isNotEmpty) const SizedBox(height: 14),

            // Subdomains card
            if (subdomains.isNotEmpty)
              _ResultCard(
                icon: Icons.account_tree_rounded,
                title: 'Subdomains',
                subtitle: '${subdomains.length} subdomain ditemukan',
                accentColor: _C.purple,
                child: Column(
                  children: subdomains.asMap().entries.map((e) =>
                    _StaggerItem(
                      index: e.key,
                      child: _SubdomainRow(
                        subdomain: e.value,
                        onCopy: (v) => _copy(v, 'Subdomain'),
                      ),
                    )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Domain Input ─────────────────────────────────────────────────────────────
class _DomainInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _DomainInput({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<_DomainInput> createState() => _DomainInputState();
}

class _DomainInputState extends State<_DomainInput> {
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
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _C.blueMid : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _C.blueMid.withOpacity(0.1),
                blurRadius: 14, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: !widget.isLoading,
        style: const TextStyle(color: _C.text, fontSize: 14,
            fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        onSubmitted: (_) => widget.onSubmit(),
        decoration: InputDecoration(
          hintText: 'contoh: nullxteam.fun',
          hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
          labelText: 'Domain Target',
          labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: _C.blueMid, fontSize: 11),
          prefixIcon: const Icon(Icons.language_rounded,
              color: _C.textSub, size: 18),
          suffixIcon: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.blueMid),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _C.textSub, size: 16),
                      onPressed: () => widget.controller.clear(),
                    )
                  : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Search Button ────────────────────────────────────────────────────────────
class _SearchButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _SearchButton({required this.isLoading, required this.onTap});

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); if (!widget.isLoading) widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _down || widget.isLoading ? [] : [
              BoxShadow(color: _C.blueMid.withOpacity(0.35),
                  blurRadius: 18, offset: const Offset(0, 5)),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: widget.isLoading
                  ? const Row(
                      key: ValueKey('loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Memindai...',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    )
                  : const Row(
                      key: ValueKey('idle'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.travel_explore_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Cek Domain',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14,
                                letterSpacing: 0.3)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Results Stats Row ────────────────────────────────────────────────────────
class _ResultsStatsRow extends StatelessWidget {
  final int recordCount;
  final int subdomainCount;
  final String domain;

  const _ResultsStatsRow({
    required this.recordCount,
    required this.subdomainCount,
    required this.domain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: _C.green, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(domain,
              style: const TextStyle(color: _C.blueLight, fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        _StatPill(label: '$recordCount DNS', color: _C.blueMid),
        const SizedBox(width: 6),
        _StatPill(label: '$subdomainCount Sub', color: _C.purple),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Result Card ──────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _ResultCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.06),
              blurRadius: 24, offset: const Offset(0, 8)),
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
                Text(title, style: const TextStyle(color: _C.text,
                    fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(
                    color: _C.textSub, fontSize: 11)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Record Row ───────────────────────────────────────────────────────────────
class _RecordRow extends StatelessWidget {
  final _RecordEntry entry;
  final void Function(String value, String label) onCopy;

  const _RecordRow({required this.entry, required this.onCopy});

  Color get _tagColor {
    switch (entry.tag) {
      case 'NS':  return _C.amber;
      case 'A':   return _C.green;
      case 'SOA': return _C.blueLight;
      case 'SRV': return _C.purple;
      case 'GEO': return const Color(0xFF34D399);
      default:    return _C.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(entry.label,
                    style: const TextStyle(color: _C.textSub, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                if (entry.tag != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _tagColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _tagColor.withOpacity(0.3)),
                    ),
                    child: Text(entry.tag!,
                        style: TextStyle(color: _tagColor, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(entry.value,
                  style: const TextStyle(color: _C.text, fontSize: 13,
                      fontWeight: FontWeight.w500, height: 1.4)),
            ]),
          ),
          if (entry.copyable)
            _CopyIconBtn(onTap: () => onCopy(entry.value, entry.label)),
        ],
      ),
    );
  }
}

// ─── Subdomain Row ────────────────────────────────────────────────────────────
class _SubdomainRow extends StatelessWidget {
  final String subdomain;
  final void Function(String) onCopy;

  const _SubdomainRow({required this.subdomain, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.purple.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(subdomain,
              style: const TextStyle(color: _C.blueLight, fontSize: 12,
                  fontWeight: FontWeight.w500, fontFamily: 'monospace')),
        ),
        _CopyIconBtn(onTap: () => onCopy(subdomain)),
      ]),
    );
  }
}

// ─── Copy Icon Button ─────────────────────────────────────────────────────────
class _CopyIconBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CopyIconBtn({required this.onTap});

  @override
  State<_CopyIconBtn> createState() => _CopyIconBtnState();
}

class _CopyIconBtnState extends State<_CopyIconBtn> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        widget.onTap();
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _copied
              ? _C.green.withOpacity(0.12)
              : _C.border.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _copied
                ? _C.green.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _copied ? Icons.check_rounded : Icons.copy_rounded,
            key: ValueKey(_copied),
            color: _copied ? _C.green : _C.textDim,
            size: 14,
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
      duration: Duration(milliseconds: 350 + (index * 40).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Scan Painter ─────────────────────────────────────────────────────────────
class _ScanPainter extends CustomPainter {
  final double t;
  _ScanPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 3,
          Paint()
            ..color = _C.blueMid.withOpacity(0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    final angle = t * math.pi * 2;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 1.2,
        endAngle: angle,
        colors: [Colors.transparent, _C.blueMid.withOpacity(0.45)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle - 1.2, 1.2, true, sweepPaint);

    canvas.drawLine(Offset(cx, cy),
        Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r),
        Paint()
          ..color = _C.blueMid.withOpacity(0.8)
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t;
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
        _C.blue.withOpacity(0.08 + math.sin(t * math.pi * 2) * 0.02),
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

// ─── Back Button ──────────────────────────────────────────────────────────────
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

// ─── Data model ───────────────────────────────────────────────────────────────
class _RecordEntry {
  final String label;
  final String value;
  final String? tag;
  final bool copyable;

  const _RecordEntry(this.label, this.value,
      {this.tag, this.copyable = false});
}
