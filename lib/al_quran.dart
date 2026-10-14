import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Ayat {
  final int nomor;
  final String arab;
  final String arti;

  Ayat({
    required this.nomor,
    required this.arab,
    required this.arti,
  });
}

class Surat {
  final int nomor;
  final String nama;
  final String latin;
  final List<Ayat> ayat;
  final int juz;

  Surat({
    required this.nomor,
    required this.nama,
    required this.latin,
    required this.ayat,
    required this.juz,
  });
}

class Juz {
  final int nomor;
  final List<Surat> suratList;
  final int suratMulai;
  final int suratAkhir;
  final int ayatMulai;
  final int ayatAkhir;

  Juz({
    required this.nomor,
    required this.suratList,
    required this.suratMulai,
    required this.suratAkhir,
    required this.ayatMulai,
    required this.ayatAkhir,
  });
}

class AlQuranPage extends StatefulWidget {
  const AlQuranPage({super.key});

  @override
  State<AlQuranPage> createState() => _AlQuranPageState();
}

class _AlQuranPageState extends State<AlQuranPage>
    with TickerProviderStateMixin {
  bool loading = true;
  List<Surat> allSuratList = [];
  List<Juz> juzList = [];
  List<Juz> filteredJuzList = [];
  TextEditingController searchController = TextEditingController();
  bool showJuzList = true;
  Juz? selectedJuz;

  late AnimationController _pageController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnim;
  late Animation<double> _loadingRotation;

  // Color palette — sama, sedikit lebih terang
  final Color primaryBlue = const Color(0xFF4D94FF);
  final Color secondaryBlue = const Color(0xFF7AB4FF);
  final Color darkBlue = const Color(0xFF1E3A8A);
  final Color deepBlue = const Color(0xFF0F172A);
  final Color cardDark = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFF0F172A);
  final Color textPrimary = const Color(0xFFF1F5F9);
  final Color textSecondary = const Color(0xFFADBDD1);
  final Color dividerColor = const Color(0xFF2A3A50);

  final List<Map<String, int>> juzBatas = [
    {'juz': 1, 'surat': 1, 'ayat': 1, 'suratAkhir': 2, 'ayatAkhir': 141},
    {'juz': 2, 'surat': 2, 'ayat': 142, 'suratAkhir': 2, 'ayatAkhir': 252},
    {'juz': 3, 'surat': 2, 'ayat': 253, 'suratAkhir': 3, 'ayatAkhir': 92},
    {'juz': 4, 'surat': 3, 'ayat': 93, 'suratAkhir': 4, 'ayatAkhir': 23},
    {'juz': 5, 'surat': 4, 'ayat': 24, 'suratAkhir': 4, 'ayatAkhir': 147},
    {'juz': 6, 'surat': 4, 'ayat': 148, 'suratAkhir': 5, 'ayatAkhir': 81},
    {'juz': 7, 'surat': 5, 'ayat': 82, 'suratAkhir': 6, 'ayatAkhir': 110},
    {'juz': 8, 'surat': 6, 'ayat': 111, 'suratAkhir': 7, 'ayatAkhir': 87},
    {'juz': 9, 'surat': 7, 'ayat': 88, 'suratAkhir': 8, 'ayatAkhir': 40},
    {'juz': 10, 'surat': 8, 'ayat': 41, 'suratAkhir': 9, 'ayatAkhir': 92},
    {'juz': 11, 'surat': 9, 'ayat': 93, 'suratAkhir': 11, 'ayatAkhir': 5},
    {'juz': 12, 'surat': 11, 'ayat': 6, 'suratAkhir': 12, 'ayatAkhir': 52},
    {'juz': 13, 'surat': 12, 'ayat': 53, 'suratAkhir': 14, 'ayatAkhir': 52},
    {'juz': 14, 'surat': 15, 'ayat': 1, 'suratAkhir': 16, 'ayatAkhir': 128},
    {'juz': 15, 'surat': 17, 'ayat': 1, 'suratAkhir': 18, 'ayatAkhir': 74},
    {'juz': 16, 'surat': 18, 'ayat': 75, 'suratAkhir': 20, 'ayatAkhir': 135},
    {'juz': 17, 'surat': 21, 'ayat': 1, 'suratAkhir': 22, 'ayatAkhir': 78},
    {'juz': 18, 'surat': 23, 'ayat': 1, 'suratAkhir': 25, 'ayatAkhir': 20},
    {'juz': 19, 'surat': 25, 'ayat': 21, 'suratAkhir': 27, 'ayatAkhir': 55},
    {'juz': 20, 'surat': 27, 'ayat': 56, 'suratAkhir': 29, 'ayatAkhir': 45},
    {'juz': 21, 'surat': 29, 'ayat': 46, 'suratAkhir': 33, 'ayatAkhir': 30},
    {'juz': 22, 'surat': 33, 'ayat': 31, 'suratAkhir': 36, 'ayatAkhir': 27},
    {'juz': 23, 'surat': 36, 'ayat': 28, 'suratAkhir': 39, 'ayatAkhir': 31},
    {'juz': 24, 'surat': 39, 'ayat': 32, 'suratAkhir': 41, 'ayatAkhir': 46},
    {'juz': 25, 'surat': 41, 'ayat': 47, 'suratAkhir': 45, 'ayatAkhir': 37},
    {'juz': 26, 'surat': 46, 'ayat': 1, 'suratAkhir': 51, 'ayatAkhir': 30},
    {'juz': 27, 'surat': 51, 'ayat': 31, 'suratAkhir': 57, 'ayatAkhir': 29},
    {'juz': 28, 'surat': 58, 'ayat': 1, 'suratAkhir': 66, 'ayatAkhir': 12},
    {'juz': 29, 'surat': 67, 'ayat': 1, 'suratAkhir': 77, 'ayatAkhir': 50},
    {'juz': 30, 'surat': 78, 'ayat': 1, 'suratAkhir': 114, 'ayatAkhir': 6},
  ];

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _fadeAnim = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _loadingRotation = CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    );

    _pageController.forward();
    _loadQuran();
    searchController.addListener(_filterJuz);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loadingController.dispose();
    searchController.removeListener(_filterJuz);
    searchController.dispose();
    super.dispose();
  }

  void _filterJuz() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredJuzList = List.from(juzList);
      } else {
        filteredJuzList = juzList.where((juz) {
          return juz.nomor.toString().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadQuran() async {
    try {
      final arabRes = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/quran/quran-uthmani'),
      );
      final indoRes = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/quran/id.indonesian'),
      );

      if (arabRes.statusCode != 200 || indoRes.statusCode != 200) {
        throw Exception('Failed to load data');
      }

      final arabData = jsonDecode(arabRes.body) as Map<String, dynamic>;
      final indoData = jsonDecode(indoRes.body) as Map<String, dynamic>;

      final arabSurah =
          (arabData['data'] as Map<String, dynamic>)['surahs'] as List;
      final indoSurah =
          (indoData['data'] as Map<String, dynamic>)['surahs'] as List;

      List<Surat> result = [];

      for (int i = 0; i < arabSurah.length; i++) {
        final arabSurahData = arabSurah[i] as Map<String, dynamic>;
        final indoSurahData = indoSurah[i] as Map<String, dynamic>;

        final arabAyat = arabSurahData['ayahs'] as List;
        final indoAyat = indoSurahData['ayahs'] as List;

        List<Ayat> ayatList = [];

        for (int j = 0; j < arabAyat.length; j++) {
          final arabAyatData = arabAyat[j] as Map<String, dynamic>;
          final indoAyatData = indoAyat[j] as Map<String, dynamic>;

          ayatList.add(
            Ayat(
              nomor: arabAyatData['numberInSurah'] as int,
              arab: arabAyatData['text'] as String? ?? '',
              arti: indoAyatData['text'] as String? ?? '',
            ),
          );
        }

        result.add(
          Surat(
            nomor: arabSurahData['number'] as int,
            nama: arabSurahData['name'] as String? ?? '',
            latin: arabSurahData['englishName'] as String? ?? '',
            ayat: ayatList,
            juz: _getJuzNumber(arabSurahData['number'] as int, 1),
          ),
        );
      }

      setState(() {
        allSuratList = result;
        _buildJuzList();
        loading = false;
        _pageController.reset();
        _pageController.forward();
      });
    } catch (e) {
      debugPrint('Error loading Quran: $e');
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  int _getJuzNumber(int suratNumber, int ayatNumber) {
    for (var batas in juzBatas) {
      if (suratNumber > batas['surat']! ||
          (suratNumber == batas['surat']! && ayatNumber >= batas['ayat']!)) {
        if (suratNumber < batas['suratAkhir']! ||
            (suratNumber == batas['suratAkhir']! &&
                ayatNumber <= batas['ayatAkhir']!)) {
          return batas['juz']!;
        }
      }
    }
    return 30;
  }

  void _buildJuzList() {
    juzList = [];
    for (int i = 1; i <= 30; i++) {
      List<Surat> suratInJuz = [];
      for (var surat in allSuratList) {
        bool isInJuz = false;
        for (var batas in juzBatas) {
          if (batas['juz'] == i) {
            if (surat.nomor >= batas['surat']! &&
                surat.nomor <= batas['suratAkhir']!) {
              isInJuz = true;
              break;
            }
          }
        }
        if (isInJuz) suratInJuz.add(surat);
      }

      var batas = juzBatas.firstWhere((b) => b['juz'] == i);
      juzList.add(
        Juz(
          nomor: i,
          suratList: suratInJuz,
          suratMulai: batas['surat']!,
          suratAkhir: batas['suratAkhir']!,
          ayatMulai: batas['ayat']!,
          ayatAkhir: batas['ayatAkhir']!,
        ),
      );
    }
    filteredJuzList = List.from(juzList);
  }

  void _navigateToJuz(Juz juz) {
    setState(() {
      selectedJuz = juz;
      showJuzList = false;
    });
    _pageController.reset();
    _pageController.forward();
  }

  void _navigateBack() {
    setState(() {
      showJuzList = true;
      selectedJuz = null;
    });
    _pageController.reset();
    _pageController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: loading ? _buildLoadingView() : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: deepBlue.withOpacity(0.92),
          border: Border(
            bottom: BorderSide(color: dividerColor, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                // Back button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-0.3, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: (!showJuzList && selectedJuz != null)
                      ? IconButton(
                          key: const ValueKey('back'),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: primaryBlue,
                            size: 20,
                          ),
                          onPressed: _navigateBack,
                        )
                      : const SizedBox(width: 48, key: ValueKey('empty')),
                ),
                // Title
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(showJuzList),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          showJuzList
                              ? 'AL-QUR\'AN'
                              : 'JUZ ${selectedJuz?.nomor ?? ""}',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            letterSpacing: 3,
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (!showJuzList && selectedJuz != null)
                          Text(
                            'Surat ${selectedJuz!.suratMulai} — ${selectedJuz!.suratAkhir}',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Right side spacer / icon
                SizedBox(
                  width: 48,
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: primaryBlue.withOpacity(0.3),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(showJuzList ? -0.04 : 0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: showJuzList
            ? _buildJuzListView(key: const ValueKey('juz'))
            : _buildSuratInJuzView(key: const ValueKey('surat')),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _loadingRotation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryBlue.withOpacity(0.15),
                  width: 3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Memuat Al-Qur\'an',
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: textSecondary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── JUZ LIST VIEW ────────────────────────────────────────────────────────

  Widget _buildJuzListView({Key? key}) {
    return Column(
      key: key,
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 64),
        _buildSearchBar(),
        if (searchController.text.isNotEmpty) _buildSearchInfo(),
        Expanded(
          child: filteredJuzList.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: filteredJuzList.length,
                  itemBuilder: (context, index) {
                    return _juzCard(filteredJuzList[index], index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dividerColor, width: 1),
        ),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cari nomor juz...',
            hintStyle:
                TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.search_rounded, color: primaryBlue, size: 20),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: searchController.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('clear'),
                      icon: Icon(Icons.close_rounded,
                          color: textSecondary, size: 18),
                      onPressed: () => searchController.clear(),
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryBlue.withOpacity(0.6), width: 1),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          Text(
            '${filteredJuzList.length} juz ditemukan',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => searchController.clear(),
            child: Text(
              'Bersihkan',
              style: TextStyle(
                  color: primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 52, color: textSecondary.withOpacity(0.3)),
          const SizedBox(height: 14),
          Text('Juz tidak ditemukan',
              style: TextStyle(color: textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => searchController.clear(),
            child: Text('Coba kata kunci lain',
                style: TextStyle(
                    color: primaryBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _juzCard(Juz juz, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index % 6) * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => _navigateToJuz(juz),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryBlue.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Number badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryBlue.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${juz.nomor}',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Juz ${juz.nomor}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline_rounded,
                      size: 11, color: textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    'S${juz.suratMulai} – S${juz.suratAkhir}',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SURAT IN JUZ VIEW ────────────────────────────────────────────────────

  Widget _buildSuratInJuzView({Key? key}) {
    if (selectedJuz == null) return const SizedBox.shrink();

    return Column(
      key: key,
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 64),
        _buildJuzInfoCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            itemCount: selectedJuz!.suratList.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 250 + index * 40),
                curve: Curves.easeOutCubic,
                builder: (ctx, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                ),
                child: _suratCard(selectedJuz!.suratList[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryBlue.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: primaryBlue.withOpacity(0.35), width: 1.5),
            ),
            child: Center(
              child: Text(
                '${selectedJuz!.nomor}',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Juz ${selectedJuz!.nomor}',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _infoChip(
                    icon: Icons.chrome_reader_mode_outlined,
                    label:
                        'Surat ${selectedJuz!.suratMulai}–${selectedJuz!.suratAkhir}',
                  ),
                  const SizedBox(width: 8),
                  _infoChip(
                    icon: Icons.format_list_numbered_rounded,
                    label:
                        'Ayat ${selectedJuz!.ayatMulai}–${selectedJuz!.ayatAkhir}',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryBlue.withOpacity(0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: secondaryBlue),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: secondaryBlue)),
        ],
      ),
    );
  }

  Widget _suratCard(Surat surat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: primaryBlue,
          collapsedIconColor: textSecondary,
          collapsedTextColor: textPrimary,
          textColor: primaryBlue,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: primaryBlue.withOpacity(0.25), width: 0.8),
            ),
            child: Center(
              child: Text(
                '${surat.nomor}',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ),
          ),
          title: Text(
            surat.latin,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              surat.nama,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          children: surat.ayat.map(_ayatTile).toList(),
        ),
      ),
    );
  }

  Widget _ayatTile(Ayat ayat) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: deepBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ayat header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: primaryBlue.withOpacity(0.25), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag_rounded,
                            size: 11, color: secondaryBlue),
                        const SizedBox(width: 3),
                        Text(
                          '${ayat.nomor}',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: secondaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Arab text
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Text(
                ayat.arab,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.85,
                  color: textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Divider(height: 1, color: dividerColor),
            ),
            // Translation
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.translate_rounded,
                      size: 13,
                      color: textSecondary.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ayat.arti,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.6,
                      ),
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
}
