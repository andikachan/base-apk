import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Palette (sama dengan Tools Page) ---
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
  static const white     = Color(0xFFFFFFFF);
}

// Constants yang dipakai di file
const Color kPrimaryColor = _C.blueLight;
const Color kAccentColor = _C.pink;
const Color kBackgroundColor = _C.bg;
const Color kCardColor = _C.card;
const Color kHighlightColor = _C.cardInner;

class HomeHentaiPage extends StatefulWidget {
  const HomeHentaiPage({super.key});

  @override
  State<HomeHentaiPage> createState() => _HomeHentaiPageState();
}

class _HomeHentaiPageState extends State<HomeHentaiPage> {
  Map<String, dynamic>? contentData;
  bool isLoading = true;
  bool isSearching = false;
  List<dynamic> searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _watchHistory = [];
  bool _isHistoryLoading = true;

  @override
  void initState() {
    super.initState();
    fetchContentData();
    _loadWatchHistory();
  }

  void refreshHistory() {
    _loadWatchHistory();
  }

  Future<void> _loadWatchHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('hentai_watch_history') ?? [];
      setState(() {
        _watchHistory = historyJson.map((item) => Map<String, dynamic>.from(json.decode(item))).toList();
        _isHistoryLoading = false;
      });
    } catch (e) {
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> fetchContentData() async {
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/home'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          contentData = jsonData['data'];
          isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> searchContent(String query) async {
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        searchResults.clear();
      });
      return;
    }
    setState(() => isSearching = true);
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/search/$query'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() => searchResults = jsonData['data']['animeList'] ?? []);
      } else {
        setState(() => searchResults = []);
      }
    } catch (e) {
      setState(() => searchResults = []);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      isSearching = false;
      searchResults.clear();
    });
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: kPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 3, height: 18,
              decoration: BoxDecoration(
                color: kAccentColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: kAccentColor.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ADULT HUB',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _C.text,
                fontSize: 16,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.steel, _C.blueMid]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("18+", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: _C.text),
                decoration: InputDecoration(
                  hintText: "Search content...",
                  hintStyle: TextStyle(color: _C.textSub),
                  prefixIcon: Icon(Icons.search, color: kPrimaryColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: Icon(Icons.clear, color: kPrimaryColor), onPressed: _clearSearch)
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) searchContent(value);
                  else setState(() { isSearching = false; searchResults.clear(); });
                },
              ),
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? _buildLoadingShimmer()
                : isSearching
                    ? _buildSearchResults()
                    : contentData == null
                        ? _buildErrorWidget()
                        : _buildHomeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([fetchContentData(), _loadWatchHistory()]);
      },
      color: kPrimaryColor,
      backgroundColor: kCardColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Watch History Section
            _buildSectionHeader(Icons.history_rounded, "WATCH HISTORY"),
            const SizedBox(height: 12),

            if (_isHistoryLoading)
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) => Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Shimmer.fromColors(
                      baseColor: kCardColor,
                      highlightColor: kHighlightColor,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              )
            else if (_watchHistory.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Text("No watch history yet.", style: TextStyle(color: _C.textSub)),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _watchHistory.length,
                  itemBuilder: (context, index) => _buildHistoryCard(_watchHistory[index]),
                ),
              ),

            const SizedBox(height: 24),

            // Quick Access Section
            _buildSectionHeader(Icons.dashboard_rounded, "QUICK ACCESS"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildQuickAccessCard("Genres", Icons.local_offer_rounded, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HentaiGenreListPage())).then((_) => refreshHistory());
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildQuickAccessCard("Schedule", Icons.schedule_rounded, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HentaiSchedulePage())).then((_) => refreshHistory());
                })),
              ],
            ),
            const SizedBox(height: 24),

            // Ongoing Section
            _buildSectionHeader(Icons.live_tv_rounded, "CURRENTLY AIRING"),
            const SizedBox(height: 12),
            _buildContentGrid(contentData!['ongoing']['animeList'] ?? []),
            const SizedBox(height: 24),

            // Complete Section
            _buildSectionHeader(Icons.check_circle_rounded, "COMPLETED SERIES"),
            const SizedBox(height: 12),
            _buildContentGrid(contentData!['completed']['animeList'] ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.text, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> content) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          if (content['last_watched_episode_slug'] != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => HentaiEpisodePage(
              episodeSlug: content['last_watched_episode_slug'],
              contentSlug: content['slug'],
              contentTitle: content['title'],
              contentPoster: content['poster'],
              onHistoryUpdate: refreshHistory,
            ))).then((_) => refreshHistory());
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => HentaiDetailPage(
              slug: content['slug'],
              onHistoryUpdate: refreshHistory,
            ))).then((_) => refreshHistory());
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(content['poster'], height: 160, width: 120, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 160, width: 120, color: kCardColor, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: kAccentColor, width: 1)),
                    child: Icon(Icons.play_arrow, color: kAccentColor, size: 14),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.9)]),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Text(content['last_watched_episode'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(content['title'], style: const TextStyle(color: _C.text, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, color: _C.textSub, size: 48),
        SizedBox(height: 12),
        Text("No results found", style: TextStyle(color: _C.textSub)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) => _buildSearchResultCard(searchResults[index]),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => HentaiDetailPage(
            slug: content['animeId'],
            onHistoryUpdate: refreshHistory,
          ))).then((_) => refreshHistory());
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(content['poster'], width: 50, height: 70, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 50, height: 70, color: kHighlightColor, child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24)),
          ),
        ),
        title: Text(content['title'], style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Row(children: [
          if (content['score'] != null) ...[
            Icon(Icons.star, color: Colors.amber, size: 12),
            const SizedBox(width: 4),
            Text(content['score'], style: const TextStyle(color: _C.textSub, fontSize: 11)),
          ],
        ]),
        trailing: Icon(Icons.play_circle_filled_rounded, color: kAccentColor, size: 28),
      ),
    );
  }

  Widget _buildContentGrid(List<dynamic> list) {
    return GridView.builder(
      itemCount: list.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final content = list[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => HentaiDetailPage(
              slug: content['animeId'],
              onHistoryUpdate: refreshHistory,
            ))).then((_) => refreshHistory());
          },
          child: Container(
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(content['poster'], height: 150, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 150, color: kHighlightColor, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(content['title'], style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("EP ${content['episodes'] ?? '-'}", style: TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      Icon(Icons.play_circle_filled_rounded, color: kPrimaryColor, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: kCardColor,
        highlightColor: kHighlightColor,
        child: Container(decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: _C.textSub, size: 48),
          const SizedBox(height: 12),
          Text("Failed to load data", style: TextStyle(color: _C.textSub)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async { await Future.wait([fetchContentData(), _loadWatchHistory()]); },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("Try Again", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Page ─────────────────────────────────────────────────────────────
class HentaiDetailPage extends StatefulWidget {
  final String slug;
  final Function()? onHistoryUpdate;
  const HentaiDetailPage({super.key, required this.slug, this.onHistoryUpdate});

  @override
  State<HentaiDetailPage> createState() => _HentaiDetailPageState();
}

class _HentaiDetailPageState extends State<HentaiDetailPage> {
  Map<String, dynamic>? detail;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/anime/${widget.slug}'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() { detail = jsonData['data']; isLoading = false; });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: kPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("DETAILS", style: TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : detail == null
              ? const Center(child: Text("Failed to load", style: TextStyle(color: _C.textSub)))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final content = detail!;
    final episodes = content['episodeList'] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(content['poster'], height: 200, width: 140, fit: BoxFit.cover)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(content['title'], style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [Icon(Icons.star, color: Colors.amber, size: 14), const SizedBox(width: 4), Text(content['score'] ?? '-', style: const TextStyle(color: _C.text))]),
              const SizedBox(height: 8),
              _buildInfoChip("Status", content['status']),
              _buildInfoChip("Episodes", content['episodes']?.toString()),
              _buildInfoChip("Duration", content['duration']),
            ])),
          ]),
          const SizedBox(height: 20),
          const Text("SYNOPSIS", style: TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
            child: Text(content['synopsis']?['paragraphs']?.join('\n\n') ?? '-', style: TextStyle(color: _C.textSub, height: 1.5)),
          ),
          const SizedBox(height: 20),
          if (episodes.isNotEmpty) ...[
            const Text("EPISODES", style: TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
                  child: ListTile(
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(ep['eps'].toString(), style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)))),
                    title: Text(ep['title'], style: const TextStyle(color: _C.text, fontSize: 13)),
                    trailing: Icon(Icons.play_circle_filled_rounded, color: kAccentColor, size: 28),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => HentaiEpisodePage(
                        episodeSlug: ep['episodeId'],
                        contentSlug: widget.slug,
                        contentTitle: content['title'],
                        contentPoster: content['poster'],
                        onHistoryUpdate: widget.onHistoryUpdate,
                      ))).then((_) { if (widget.onHistoryUpdate != null) widget.onHistoryUpdate!(); });
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(color: _C.textSub, fontSize: 11)),
        TextSpan(text: value ?? '-', style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w500)),
      ])),
    );
  }
}

// ─── Episode Page ────────────────────────────────────────────────────────────
class HentaiEpisodePage extends StatefulWidget {
  final String episodeSlug;
  final String? contentSlug, contentTitle, contentPoster;
  final Function()? onHistoryUpdate;
  const HentaiEpisodePage({super.key, required this.episodeSlug, this.contentSlug, this.contentTitle, this.contentPoster, this.onHistoryUpdate});

  @override
  State<HentaiEpisodePage> createState() => _HentaiEpisodePageState();
}

class _HentaiEpisodePageState extends State<HentaiEpisodePage> {
  Map<String, dynamic>? episodeData;
  bool isLoading = true;
  late WebViewController _webViewController;
  bool _isWebViewLoading = true;
  String? _streamUrl;

  @override
  void initState() {
    super.initState();
    fetchEpisodeData();
  }

  Future<void> fetchEpisodeData() async {
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/episode/${widget.episodeSlug}'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() { episodeData = jsonData['data']; });
        await _fetchStreamUrl();
        _initializeWebView();
        _addToWatchHistory();
        setState(() => isLoading = false);
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchStreamUrl() async {
    final qualities = episodeData?['server']?['qualities'] ?? [];
    if (qualities.isEmpty) return;
    final serverId = qualities[0]['serverList'][0]['serverId'];
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/server/$serverId'));
      if (response.statusCode == 200) setState(() => _streamUrl = json.decode(response.body)['data']['url']);
    } catch (e) {}
  }

  Future<void> _addToWatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('hentai_watch_history') ?? [];
      List<Map<String, dynamic>> watchHistory = historyJson.map((item) => Map<String, dynamic>.from(json.decode(item))).toList();
      watchHistory.removeWhere((item) => item['slug'] == widget.contentSlug);
      watchHistory.insert(0, {
        'slug': widget.contentSlug, 'title': widget.contentTitle, 'poster': widget.contentPoster,
        'last_watched_episode': episodeData?['title'], 'last_watched_episode_slug': widget.episodeSlug,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (watchHistory.length > 20) watchHistory = watchHistory.sublist(0, 20);
      await prefs.setStringList('hentai_watch_history', watchHistory.map((item) => json.encode(item)).toList());
      if (widget.onHistoryUpdate != null) widget.onHistoryUpdate!();
    } catch (e) {}
  }

  void _initializeWebView() {
    if (_streamUrl == null) return;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (url) => setState(() => _isWebViewLoading = false)))
      ..loadRequest(Uri.parse(_streamUrl!), headers: {'Referer': 'https://www.sankavollerei.com/'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_rounded, color: kPrimaryColor, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(episodeData?['title'] ?? "Streaming", style: const TextStyle(color: _C.text, fontSize: 13)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Column(children: [
              Container(height: MediaQuery.of(context).size.height * 0.4, width: double.infinity, color: Colors.black,
                child: Stack(children: [
                  if (_streamUrl != null) WebViewWidget(controller: _webViewController),
                  if (_isWebViewLoading) const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                ]),
              ),
              Expanded(child: Center(child: Text("Enjoy the content.", style: TextStyle(color: _C.textSub)))),
            ]),
    );
  }
}

// ─── Genre List Page ─────────────────────────────────────────────────────────
class HentaiGenreListPage extends StatefulWidget {
  const HentaiGenreListPage({super.key});
  @override State<HentaiGenreListPage> createState() => _HentaiGenreListPageState();
}

class _HentaiGenreListPageState extends State<HentaiGenreListPage> {
  List<dynamic> genreList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGenreList();
  }

  Future<void> _fetchGenreList() async {
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/genre/'));
      if (response.statusCode == 200) {
        setState(() { genreList = json.decode(response.body)['data']['genreList']; isLoading = false; });
      } else { setState(() => isLoading = false); }
    } catch (_) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_rounded, color: kPrimaryColor, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("GENRES", style: TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: genreList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
                alignment: Alignment.center,
                child: Text(genreList[index]['title'], style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600)),
              ),
            ),
    );
  }
}

// ─── Schedule Page ───────────────────────────────────────────────────────────
class HentaiSchedulePage extends StatefulWidget {
  const HentaiSchedulePage({super.key});
  @override State<HentaiSchedulePage> createState() => _HentaiSchedulePageState();
}

class _HentaiSchedulePageState extends State<HentaiSchedulePage> {
  List<dynamic> scheduleData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    try {
      final response = await http.get(Uri.parse('https://www.sankavollerei.com/anime/schedule'));
      if (response.statusCode == 200) {
        setState(() { scheduleData = json.decode(response.body)['data']; isLoading = false; });
      } else { setState(() => isLoading = false); }
    } catch (_) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_rounded, color: kPrimaryColor, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("SCHEDULE", style: TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduleData.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(scheduleData[index]['day'], style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                  Text("${scheduleData[index]['anime_list'].length} updates", style: TextStyle(color: _C.textSub, fontSize: 12)),
                ]),
              ),
            ),
    );
  }
}

// Komponen Reusable
Widget _buildQuickAccessCard(String title, IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: Column(children: [
        Icon(icon, color: kAccentColor, size: 24),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ),
  );
}