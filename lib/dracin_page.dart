// dracin_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:ui';

// ─── Palette (sama dengan Tools Page) ─────────────────────────────────────
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

class DracinPage extends StatefulWidget {
  const DracinPage({super.key});

  @override
  State<DracinPage> createState() => _DracinPageState();
}

class _DracinPageState extends State<DracinPage> with TickerProviderStateMixin {
  // API Configuration - TVMaze
  static const String baseUrl = "https://api.tvmaze.com";
  
  // Data State
  List<dynamic> _dramas = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = "";
  int _currentPage = 0;
  bool _hasMore = true;
  String _errorMessage = "";
  
  // Detail State
  Map<String, dynamic>? _selectedDrama;
  List<dynamic> _episodes = [];
  bool _isLoadingDetail = false;
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;
  
  // Video Controller
  VideoPlayerController? _videoController;
  
  // YouTube Mapping
  final Map<String, List<String>> _youtubeMapping = {
    "Hidden Love": [
      "njdsTooO8Cs", "O2picCb-xos", "YwYNtUL6Yb4", "X08uqhxWtDw", "os-ACoJoqNE",
      "LmtOllEwxt0", "uhH98kd_BpQ", "XqjVAhsefKk", "7qpxeiDciUA", "zGGKxwomZ_4",
      "hPc8WmvSB4g", "vRfou8f4ldc", "3NFAO9jOC3w", "oah1P0QF62k", "k05z7EQbENM",
    ],
    "The Untamed": ["BfKhREVFLkQ", "b6vMPr_9VIs", "L10Xv_87U18"],
  };

  String _getYoutubeId(String title, int episodeNumber) {
    String? matchKey = _youtubeMapping.keys.firstWhere(
      (key) => title.toLowerCase().contains(key.toLowerCase()),
      orElse: () => "",
    );
    if (matchKey.isNotEmpty) {
      List<String> ids = _youtubeMapping[matchKey]!;
      if (episodeNumber > 0 && episodeNumber <= ids.length) {
        return ids[episodeNumber - 1];
      }
      return ids[0];
    }
    return "njdsTooO8Cs";
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initVideoBackground();
    _fetchDramas();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore && !_isSearching) {
        _fetchDramas(page: _currentPage + 1);
      }
    }
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine));
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));
    _fadeController.forward();
  }
  
  Future<void> _initVideoBackground() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/background.mp4')
        ..initialize().then((_) {
          _videoController?.setLooping(true);
          _videoController?.setVolume(0.0);
          _videoController?.play();
          if (mounted) setState(() {});
        }).catchError((e) {});
    } catch (e) {}
  }
  
  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        if (_videoController != null && _videoController!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: Opacity(opacity: 0.06, child: VideoPlayer(_videoController!)),
              ),
            ),
          )
        else
          Container(color: _C.bg),
        
        // Grid lines
        CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
        
        // Rotating rings
        AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, _) {
            final size = MediaQuery.of(context).size;
            return Stack(
              children: [
                Positioned(
                  bottom: -size.height * 0.15,
                  right: -size.width * 0.2,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value * pi * 2,
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.blueLight.withOpacity(0.05), width: 1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -size.height * 0.08,
                  left: -size.width * 0.15,
                  child: Transform.rotate(
                    angle: -_rotateAnimation.value * pi,
                    child: Container(
                      width: size.width * 0.5,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.blueMid.withOpacity(0.06), width: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        
        // Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Colors.transparent, _C.bg.withOpacity(0.55)],
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _fetchDramas({int page = 0}) async {
    if (_isLoading && page != 0) return;
    setState(() { _isLoading = true; _errorMessage = ""; });
    
    try {
      final response = await http.get(Uri.parse("$baseUrl/shows?page=$page")).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final chineseDramas = data.where((show) {
          final network = show['network']?['country']?['code'] ?? '';
          final webChannel = show['webChannel']?['country']?['code'] ?? '';
          final name = show['name']?.toLowerCase() ?? '';
          return (network == 'CN' || webChannel == 'CN' || name.contains('chinese') || name.contains('china') ||
                  _youtubeMapping.keys.any((k) => name.contains(k.toLowerCase())) || show['genres']?.contains('Drama') == true);
        }).toList();
        
        setState(() {
          if (page == 0) _dramas = chineseDramas;
          else _dramas.addAll(chineseDramas);
          _currentPage = page;
          _hasMore = data.length == 250;
          _isLoading = false;
        });
      } else {
        setState(() { _errorMessage = "Failed to load dramas"; _isLoading = false; });
        _loadMockData();
      }
    } catch (e) {
      setState(() { _errorMessage = "Network error"; _isLoading = false; });
      _loadMockData();
    }
  }
  
  Future<void> _searchDramas(String query) async {
    if (query.isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() { _isSearching = true; _searchQuery = query; _isLoading = true; });
    
    try {
      final response = await http.get(Uri.parse("$baseUrl/search/shows?q=${Uri.encodeComponent(query)}")).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _searchResults = data.map((item) => item['show']).toList(); _isLoading = false; });
      } else {
        setState(() { _searchResults = []; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _searchResults = []; _isLoading = false; });
    }
  }
  
  void _loadMockData() {
    final mockDramas = [
      {"id": 1, "name": "Hidden Love", "language": "Chinese", "genres": ["Romance"], "summary": "<p>A young girl's secret crush blossoms over the years.</p>", "image": {"medium": ""}, "premiered": "2023-06-20", "rating": {"average": 9.2}, "network": {"name": "Youku", "country": {"code": "CN"}}},
    ];
    setState(() { if (_isSearching) _searchResults = mockDramas; else _dramas = mockDramas; _isLoading = false; });
  }
  
  void _clearSearch() {
    _searchController.clear();
    setState(() { _isSearching = false; _searchResults = []; });
    _searchFocusNode.unfocus();
  }
  
  Future<void> _fetchDramaDetail(int dramaId) async {
    setState(() { _isLoadingDetail = true; });
    try {
      final showResponse = await http.get(Uri.parse("$baseUrl/shows/$dramaId")).timeout(const Duration(seconds: 10));
      final episodesResponse = await http.get(Uri.parse("$baseUrl/shows/$dramaId/episodes")).timeout(const Duration(seconds: 10));
      if (showResponse.statusCode == 200) {
        setState(() {
          _selectedDrama = jsonDecode(showResponse.body);
          _episodes = episodesResponse.statusCode == 200 ? jsonDecode(episodesResponse.body) : [];
          _isLoadingDetail = false;
        });
      } else {
        setState(() { _isLoadingDetail = false; });
      }
    } catch (e) {
      setState(() { _isLoadingDetail = false; });
    }
  }
  
  void _showDramaDetail(Map<String, dynamic> drama) async {
    await _fetchDramaDetail(drama['id']);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDramaDetailSheet(),
    ).then((_) => setState(() { _selectedDrama = null; _episodes = []; }));
  }
  
  Widget _buildDramaDetailSheet() {
    if (_selectedDrama == null || _isLoadingDetail) {
      return Container(
        height: 400, margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(28)),
        child: const Center(child: CircularProgressIndicator(color: _C.blueLight)),
      );
    }
    
    final drama = _selectedDrama!;
    final genres = drama['genres'] ?? [];
    final imageUrl = drama['image']?['original'] ?? drama['image']?['medium'] ?? '';
    final rating = drama['rating']?['average']?.toString() ?? 'N/A';
    final year = drama['premiered']?.toString().split('-')[0] ?? 'Unknown';
    final network = drama['network']?['name'] ?? drama['webChannel']?['name'] ?? 'Unknown';
    final summary = drama['summary']?.replaceAll(RegExp(r'<[^>]*>'), '') ?? 'No synopsis available.';
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _C.surface.withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, _C.surface.withOpacity(0.95)],
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: _C.blueLight, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _C.amber.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.black),
                                const SizedBox(width: 4),
                                Text(rating, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drama['name'] ?? 'Unknown Title', style: const TextStyle(color: _C.text, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        if (drama['language'] != null)
                          Text(drama['language'], style: TextStyle(color: _C.textSub, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          children: [
                            _buildInfoChip(Icons.calendar_today, year),
                            _buildInfoChip(Icons.tv, network),
                            _buildInfoChip(Icons.public, "China"),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (genres.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: genres.map<Widget>((genre) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _C.blueMid.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _C.blueLight.withOpacity(0.2)),
                              ),
                              child: Text(genre, style: TextStyle(color: _C.blueLight, fontSize: 10)),
                            )).toList(),
                          ),
                        const SizedBox(height: 20),
                        Text("Synopsis", style: TextStyle(color: _C.blueLight, fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(summary, style: TextStyle(color: _C.textSub, fontSize: 12, height: 1.5)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(width: 3, height: 18, decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Text("EPISODES", style: TextStyle(color: _C.blueLight, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 3)),
                            const Spacer(),
                            Text("${_episodes.length} Available", style: TextStyle(color: _C.textSub, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_episodes.isEmpty)
                          Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: Text("No episodes available", style: TextStyle(color: _C.textSub)))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _episodes.length > 50 ? 50 : _episodes.length,
                            itemBuilder: (context, index) {
                              final episode = _episodes[index];
                              final season = episode['season'] ?? 1;
                              final number = episode['number'] ?? index + 1;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => DramaPlayerScreen(
                                      videoId: _getYoutubeId(drama['name'] ?? '', number),
                                      episodeTitle: "${drama['name']} - S${season}E$number",
                                    )));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _C.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _C.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 45, height: 45,
                                          decoration: BoxDecoration(color: _C.blueMid.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                          child: Center(child: Text("$number", style: TextStyle(color: _C.blueLight, fontSize: 16, fontWeight: FontWeight.w800))),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}", style: TextStyle(color: _C.textSub, fontSize: 11)),
                                              Text(episode['name'] ?? "Episode $number", style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: _C.blueMid.withOpacity(0.1), shape: BoxShape.circle),
                                          child: Icon(Icons.play_arrow, color: _C.blueLight, size: 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 30),
                      ],
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
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _C.textSub),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: _C.textSub, fontSize: 11)),
    ]);
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.blueLight.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: _C.blueLight.withOpacity(0.12 * _glowAnimation.value), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.blueMid.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.blueLight.withOpacity(0.2)),
                ),
                child: const Icon(Icons.live_tv, color: _C.blueLight, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(colors: [_C.blueLight, _C.chrome, _C.blueMid]).createShader(bounds),
                      child: const Text("C-DRAMA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    ),
                    const SizedBox(height: 4),
                    Text(_isSearching ? "Search Results" : "${_dramas.length} Dramas", style: TextStyle(color: _C.textSub, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () { if (!_isSearching) { setState(() { _currentPage = 0; _dramas = []; _fetchDramas(); }); } },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _C.blueMid.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: _C.blueLight.withOpacity(0.2))),
                  child: Icon(Icons.refresh, color: _C.blueLight, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(color: _C.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search Chinese dramas...",
            hintStyle: TextStyle(color: _C.textSub, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: _C.blueLight, size: 20),
            suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: _C.blueLight, size: 18), onPressed: _clearSearch) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) { if (value.isNotEmpty) _searchDramas(value); else _clearSearch(); },
        ),
      ),
    );
  }
  
  Widget _buildDramaGrid() {
    final displayList = _isSearching ? _searchResults : _dramas;
    if (displayList.isEmpty && !_isLoading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.movie, size: 64, color: _C.textSub.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(_errorMessage.isNotEmpty ? _errorMessage : "No dramas found", style: TextStyle(color: _C.textSub)),
          if (_errorMessage.isNotEmpty) TextButton.icon(onPressed: () => _fetchDramas(), icon: const Icon(Icons.refresh), label: const Text("Retry")),
        ]),
      );
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: displayList.length + (_hasMore && !_isSearching && !_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayList.length && _hasMore && !_isSearching) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _C.blueLight)));
        }
        return _buildDramaCard(displayList[index]);
      },
    );
  }
  
  Widget _buildDramaCard(Map<String, dynamic> drama) {
    final title = drama['name'] ?? 'Unknown';
    final imageUrl = drama['image']?['medium'] ?? drama['image']?['original'] ?? '';
    final rating = drama['rating']?['average']?.toString() ?? 'N/A';
    final year = drama['premiered']?.toString().split('-')[0] ?? '';
    return GestureDetector(
      onTap: () => _showDramaDetail(drama),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty ? Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _C.surface)) : Container(color: _C.surface),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)]))),
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _C.amber.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [const Icon(Icons.star, size: 10, color: Colors.black), const SizedBox(width: 2), Text(rating, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (year.isNotEmpty) Text(year, style: TextStyle(color: _C.textSub, fontSize: 10)),
        ],
      ),
    );
  }
  
  Widget _buildFooter() {
    return Column(
      children: [
        Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, _C.blueLight.withOpacity(0.1), Colors.transparent]))),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterDot(_C.green),
            const SizedBox(width: 8),
            _buildFooterText("STREAMING"),
            const SizedBox(width: 20),
            Container(width: 1, height: 10, color: _C.textSub.withOpacity(0.06)),
            const SizedBox(width: 20),
            Icon(Icons.fingerprint, color: _C.textSub.withOpacity(0.12), size: 12),
            const SizedBox(width: 20),
            _buildFooterDot(_C.blueLight),
            const SizedBox(width: 8),
            _buildFooterText("C-DRAMA"),
          ],
        ),
        const SizedBox(height: 8),
        Text("ASTRAL • CHINESE DRAMA STREAMING", style: TextStyle(color: _C.textSub.withOpacity(0.1), fontSize: 8, letterSpacing: 3, fontWeight: FontWeight.w600)),
      ],
    );
  }
  
  Widget _buildFooterDot(Color color) => Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 5)]));
  Widget _buildFooterText(String text) => Text(text, style: TextStyle(color: _C.textSub.withOpacity(0.25), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2.5));
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: _isLoading && _dramas.isEmpty && !_isSearching
                      ? const Center(child: CircularProgressIndicator(color: _C.blueLight, strokeWidth: 3))
                      : FadeTransition(opacity: _fadeAnimation, child: _buildDramaGrid()),
                ),
                _buildFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

// Grid Background Painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _C.border.withOpacity(0.22)..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}

// YouTube Player Screen dengan WebView
class DramaPlayerScreen extends StatefulWidget {
  final String videoId;
  final String episodeTitle;
  const DramaPlayerScreen({super.key, required this.videoId, required this.episodeTitle});

  @override
  State<DramaPlayerScreen> createState() => _DramaPlayerScreenState();
}

class _DramaPlayerScreenState extends State<DramaPlayerScreen> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(
        Uri.parse('https://www.youtube.com/embed/${widget.videoId}?autoplay=1&rel=0&modestbranding=1'),
        headers: {'Referer': 'https://www.youtube.com/'},
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _C.blueLight, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.episodeTitle,
          style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: _C.blueLight),
            ),
        ],
      ),
    );
  }
}