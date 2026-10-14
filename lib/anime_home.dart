import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeAnimePage extends StatefulWidget {
  const HomeAnimePage({super.key});

  @override
  State<HomeAnimePage> createState() => _HomeAnimePageState();
}

class _HomeAnimePageState extends State<HomeAnimePage> {
  Map<String, dynamic>? animeData;
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
    fetchAnimeData();
    _loadWatchHistory();
  }

  // Callback function to refresh history when updated from other pages
  void refreshHistory() {
    _loadWatchHistory();
  }

  Future<void> _loadWatchHistory() async {
    setState(() {
      _isHistoryLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('watch_history') ?? [];
      setState(() {
        _watchHistory = historyJson
            .map((item) => Map<String, dynamic>.from(json.decode(item)))
            .toList();
        _isHistoryLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading watch history: $e');
      setState(() {
        _isHistoryLoading = false;
      });
    }
  }

  Future<void> fetchAnimeData() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/home'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          animeData = jsonData['data'];
          isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data anime');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => isLoading = false);
    }
  }

Future<void> searchAnime(String query) async {
  if (query.isEmpty) {
    setState(() {
      isSearching = false;
      searchResults.clear();
    });
    return;
  }

  setState(() {
    isSearching = true;
    isLoading = false;
  });

  try {
    debugPrint('🔍 Searching for: $query');
    
    final response = await http.get(
      Uri.parse('https://www.sankavollerei.com/anime/search/$query'),
    );

    debugPrint('📡 Search status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      debugPrint('📦 Search response keys: ${jsonData.keys}');
      
      // ✅ PERBAIKAN: Gunakan 'animeList' bukan 'search_results'
      if (jsonData['data'] != null && jsonData['data']['animeList'] != null) {
        setState(() {
          searchResults = jsonData['data']['animeList'] ?? [];
        });
        debugPrint('✅ Found ${searchResults.length} results');
      } else {
        setState(() {
          searchResults = [];
        });
      }
    } else {
      setState(() {
        searchResults = [];
      });
    }
  } catch (e) {
    debugPrint('❌ Search Error: $e');
    setState(() {
      searchResults = [];
    });
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
      backgroundColor: const Color(0xFF141414),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search anime...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              final query = _searchController.text.trim();
                              if (query.isNotEmpty) {
                                _searchFocusNode.unfocus();
                                searchAnime(query);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: _clearSearch,
                          ),
                        ],
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isNotEmpty) {
                  _searchFocusNode.unfocus();
                  searchAnime(query);
                }
              },
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? _buildLoadingShimmer()
                : isSearching
                    ? _buildSearchResults()
                    : animeData == null
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
        await Future.wait([
          fetchAnimeData(),
          _loadWatchHistory(),
        ]);
      },
      color: const Color(0xFFE50914),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Watch History Section
            _buildSectionHeader(Icons.history, "Watch History"),
            const SizedBox(height: 12),

            // Show loading shimmer for history
            if (_isHistoryLoading)
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Shimmer.fromColors(
                        baseColor: const Color(0xFF1F1F1F),
                        highlightColor: const Color(0xFF2A2A2A),
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (_watchHistory.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: const Text(
                  "No watch history yet. Start watching an anime!",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _watchHistory.length,
                  itemBuilder: (context, index) {
                    final anime = _watchHistory[index];
                    return _buildHistoryCard(anime);
                  },
                ),
              ),

// Quick Access Section
_buildSectionHeader(Icons.dashboard, "Quick Access"),
const SizedBox(height: 12),

// Row 1: Genre & Schedule
Row(
  children: [
    Expanded(
      child: _buildQuickAccessCard(
        "Genre",
        Icons.category,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnimeGenreListPage()),
          ).then((_) => refreshHistory());
        },
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildQuickAccessCard(
        "Schedule",
        Icons.schedule,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnimeSchedulePage()),
          ).then((_) => refreshHistory());
        },
      ),
    ),
  ],
),

const SizedBox(height: 12),

// Row 2: All Anime & Ongoing
Row(
  children: [
    Expanded(
      child: _buildQuickAccessCard(
        "All Anime",
        Icons.video_library,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllAnimePage()),
          ).then((_) => refreshHistory());
        },
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildQuickAccessCard(
        "Ongoing",
        Icons.live_tv,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OngoingAnimePage()),
          ).then((_) => refreshHistory());
        },
      ),
    ),
  ],
),

const SizedBox(height: 12),

// Row 3: Complete
Row(
  children: [
    Expanded(
      child: _buildQuickAccessCard(
        "Complete",
        Icons.check_circle,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CompleteAnimePage()),
          ).then((_) => refreshHistory());
        },
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildQuickAccessCard(
        "Search",
        Icons.search,
        () {
          // Fokus ke search bar
          _searchFocusNode.requestFocus();
        },
      ),
    ),
  ],
),

const SizedBox(height: 24),

            // Ongoing Anime Section
            _buildSectionHeader(Icons.live_tv, "Currently Airing"),
            const SizedBox(height: 12),
            _buildAnimeGrid(animeData!['ongoing']?['animeList'] ?? []),
            const SizedBox(height: 24),

            // Complete Anime Section
            _buildSectionHeader(Icons.check_circle, "Completed Series"),
            const SizedBox(height: 12),
            _buildAnimeGrid(animeData!['completed']?['animeList'] ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE50914), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> anime) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          if (anime['last_watched_episode_slug'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeEpisodePage(
                  episodeSlug: anime['last_watched_episode_slug'],
                  animeSlug: anime['slug'],
                  animeTitle: anime['title'],
                  animePoster: anime['poster'],
                  onHistoryUpdate: refreshHistory,
                ),
              ),
            ).then((_) => refreshHistory());
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailPage(
                  slug: anime['slug'],
                  onHistoryUpdate: refreshHistory,
                ),
              ),
            ).then((_) => refreshHistory());
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    anime['poster'],
                    height: 160,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      width: 120,
                      color: const Color(0xFF1F1F1F),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                    child: Text(
                      anime['last_watched_episode'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anime['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              "No results found",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try with different keywords",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final anime = searchResults[index];
        return _buildSearchResultCard(anime);
      },
    );
  }

Widget _buildSearchResultCard(Map<String, dynamic> anime) {
  final String title = anime['title'] ?? 'Unknown';
  final String poster = anime['poster'] ?? '';
  final String? rating = anime['score'] ?? anime['rating']; // SCORE dari response
  final String? status = anime['status'];
  final List<dynamic> genres = anime['genreList'] ?? []; // genreList, BUKAN genres
  
  // ✅ PERBAIKAN: Pakai 'animeId' untuk slug
  String slug = anime['animeId'] ?? '';
  
  // Fallback ke href jika animeId tidak ada
  if (slug.isEmpty && anime['href'] != null) {
    slug = _extractSlugFromUrl(anime['href']);
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(8),
    ),
    child: InkWell(
      onTap: () {
        if (slug.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnimeDetailPage(
                slug: slug,
                onHistoryUpdate: refreshHistory,
              ),
            ),
          ).then((_) => refreshHistory());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open this anime')),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                poster,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 120,
                  color: const Color(0xFF2A2A2A),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Rating and Status
                  Row(
                    children: [
                      if (rating != null && rating.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (status != null && status.isNotEmpty)
                        Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Genres
                  if (genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genres.take(3).map<Widget>((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            genre['title'] ?? 'Unknown', // Pakai 'title' dari genreList
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _extractSlugFromUrl(String url) {
    try {
      final animeIndex = url.indexOf('/anime/');
      if (animeIndex != -1) {
        String slugPart = url.substring(animeIndex + 7);
        if (slugPart.endsWith('/')) {
          slugPart = slugPart.substring(0, slugPart.length - 1);
        }
        return slugPart;
      }
      return url;
    } catch (e) {
      debugPrint('Error extracting slug: $e');
      return url;
    }
  }

  Widget _buildAnimeGrid(List<dynamic> list) {
    return GridView.builder(
      itemCount: list.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final anime = list[index];
        final String title = anime['title'] ?? 'Unknown';
        final String poster = anime['poster'] ?? '';
        final String? episode = anime['episodes']?.toString() ?? '-';
        final String? date = anime['latestReleaseDate'] ?? anime['lastReleaseDate'] ?? '-';
        final String slug = anime['animeId'] ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailPage(
                  slug: slug,
                  onHistoryUpdate: refreshHistory,
                ),
              ),
            ).then((_) => refreshHistory());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  poster,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: const Color(0xFF1F1F1F),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  episode ?? "-",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  "Updated: $date",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFF1F1F1F),
        highlightColor: const Color(0xFF2A2A2A),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            "Failed to load data",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await Future.wait([
                fetchAnimeData(),
                _loadWatchHistory(),
              ]);
            },
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }
}

Widget _buildQuickAccessCard(String title, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFE50914), size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

class AnimeDetailPage extends StatefulWidget {
  final String slug;
  final Function()? onHistoryUpdate;

  const AnimeDetailPage({super.key, required this.slug, this.onHistoryUpdate});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  Map<String, dynamic>? animeDetail;
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    fetchAnimeDetail();
  }

  Future<void> fetchAnimeDetail() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/anime/${widget.slug}'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          animeDetail = jsonData;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Anime Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError || animeDetail == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load anime details",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchAnimeDetail,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : _buildAnimeDetail(),
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFF1F1F1F),
            highlightColor: const Color(0xFF2A2A2A),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: const Color(0xFF1F1F1F),
            highlightColor: const Color(0xFF2A2A2A),
            child: Container(
              height: 24,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: const Color(0xFF1F1F1F),
            highlightColor: const Color(0xFF2A2A2A),
            child: Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeDetail() {
    final anime = animeDetail!['data'];

    final List<dynamic> episodes = anime['episodeList'] ?? [];
    final List<dynamic> recommendations = anime['recommendedAnimeList'] ?? [];
    final List<dynamic> genres = anime['genreList'] ?? [];

    // Gabungin synopsis paragraphs jadi 1 string
    String synopsisText = '';
    if (anime['synopsis'] != null && anime['synopsis']['paragraphs'] != null) {
      synopsisText = (anime['synopsis']['paragraphs'] as List)
          .where((e) => e.toString().trim().isNotEmpty)
          .join('\n\n');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster dan Info Dasar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  anime['poster'],
                  height: 200,
                  width: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: 140,
                    color: const Color(0xFF1F1F1F),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime['title'] ?? '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      anime['japanese'] ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          anime['score']?.toString().isNotEmpty == true
                              ? anime['score']
                              : '-',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem('Type', anime['type']),
                    _buildInfoItem('Status', anime['status']),
                    _buildInfoItem(
                        'Episodes',
                        anime['episodes'] != null
                            ? anime['episodes'].toString()
                            : '-'),
                    _buildInfoItem('Duration', anime['duration']),
                    _buildInfoItem('Aired', anime['aired']),
                    _buildInfoItem('Studio', anime['studios']),
                    // Setelah studio info, sebelum genres
// ✅ TAMBAHKAN INI - Tombol Batch jika ada
if (anime['batch'] != null) ...[
  const SizedBox(height: 12),
  ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnimeBatchPage(
            batchSlug: anime['batch']['slug'] ?? widget.slug,
            animeTitle: anime['title'] ?? 'Anime',
          ),
        ),
      );
    },
    icon: const Icon(Icons.download),
    label: const Text("Download Batch"),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE50914),
      minimumSize: const Size(double.infinity, 45),
    ),
  ),
],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Genres
          if (genres.isNotEmpty) ...[
            const Text(
              "Genres",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map<Widget>((genre) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeGenrePage(
                          genreSlug: genre['genreId'],
                          genreName: genre['title'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      genre['title'],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Sinopsis
          if (synopsisText.isNotEmpty) ...[
            const Text(
              "Synopsis",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                synopsisText,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Episodes
          if (episodes.isNotEmpty) ...[
            const Text(
              "Episodes",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          episode['eps'].toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    title: Text(
                      episode['title'],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimeEpisodePage(
                            episodeSlug: episode['episodeId'],
                            animeSlug: widget.slug,
                            animeTitle: anime['title'],
                            animePoster: anime['poster'],
                            episodes: episodes,
                            recommendations: recommendations,
                            onHistoryUpdate: widget.onHistoryUpdate,
                          ),
                        ),
                      );
                    },
                    trailing: const Icon(Icons.play_arrow, color: Colors.white),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Recommendations
          if (recommendations.isNotEmpty) ...[
            const Text(
              "Recommendations",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimeDetailPage(
                            slug: recommendation['animeId'],
                            onHistoryUpdate: widget.onHistoryUpdate,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              recommendation['poster'],
                              height: 160,
                              width: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                width: 120,
                                color: const Color(0xFF1F1F1F),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recommendation['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value ?? '-',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeGenrePage extends StatefulWidget {
  final String genreSlug;
  final String genreName;

  const AnimeGenrePage({
    super.key,
    required this.genreSlug,
    required this.genreName,
  });

  @override
  State<AnimeGenrePage> createState() => _AnimeGenrePageState();
}

class _AnimeGenrePageState extends State<AnimeGenrePage> {
  List<dynamic> animeList = [];
  Map<String, dynamic>? pagination;
  bool isLoading = true;
  bool isError = false;
  int currentPage = 1;

  Future<void> fetchGenreAnime({int page = 1}) async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      debugPrint('🔍 Fetching genre: ${widget.genreSlug} page $page');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/genre/${widget.genreSlug}?page=$page'),
      );

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // 🔥 FIX 1: Ambil data anime dari animeList
        if (jsonData['data'] != null && jsonData['data']['animeList'] != null) {
          setState(() {
            animeList = jsonData['data']['animeList'];
            
            // 🔥 FIX 2: Ambil pagination dari root JSON
            pagination = jsonData['pagination'];
            
            isLoading = false;
            currentPage = page;
          });
          debugPrint('✅ Loaded ${animeList.length} anime');
        } else {
          throw Exception('Invalid response structure');
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching genre anime: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchGenreAnime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: Text(
          "Genre: ${widget.genreName}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load genre data",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => fetchGenreAnime(page: currentPage),
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : animeList.isEmpty
                  ? const Center(
                      child: Text(
                        "No anime found in this genre",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildGenreContent(),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1F1F1F),
          highlightColor: const Color(0xFF2A2A2A),
          child: Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenreContent() {
    return Column(
      children: [
        // Pagination Info
        if (pagination != null) _buildPaginationInfo(),

        // Anime List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: animeList.length,
            itemBuilder: (context, index) {
              final anime = animeList[index];
              return _buildAnimeCard(anime);
            },
          ),
        ),

        // Pagination Controls
        if (pagination != null && (pagination!['hasNextPage'] == true || pagination!['hasPrevPage'] == true))
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            // 🔥 FIX 3: Ganti nama key pagination sesuai JSON
            "Page $currentPage of ${pagination!['totalPages']}",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            "Total: ${animeList.length} anime",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    // 🔥 FIX 4: Ganti nama key untuk prev dan next
    final hasNext = pagination!['hasNextPage'] ?? false;
    final hasPrev = pagination!['hasPrevPage'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasPrev)
            ElevatedButton(
              onPressed: () => fetchGenreAnime(page: currentPage - 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 4),
                  Text("Previous"),
                ],
              ),
            ),

          const SizedBox(width: 16),

          if (hasNext)
            ElevatedButton(
              onPressed: () => fetchGenreAnime(page: currentPage + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Next"),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimeCard(Map<String, dynamic> anime) {
    final String title = anime['title']?.toString() ?? 'Unknown';
    final String poster = anime['poster']?.toString() ?? '';
    
    // Urus Score/Rating
    final String rating = (anime['score']?.toString().isNotEmpty == true) 
        ? anime['score'].toString() 
        : '-';
        
    final String episodeCount = anime['episodes']?.toString() ?? '?';
    final String slug = anime['animeId']?.toString() ?? '';
    final List<dynamic> genres = anime['genreList'] ?? [];

    // 🔥 FIX 5: Ekstrak sinopsis dari array "paragraphs"
    String synopsisText = '';
    if (anime['synopsis'] != null && anime['synopsis']['paragraphs'] != null) {
      synopsisText = (anime['synopsis']['paragraphs'] as List)
          .where((e) => e.toString().trim().isNotEmpty)
          .join('\n\n');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          if (slug.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailPage(slug: slug),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot open this anime')),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  poster,
                  width: 100,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 140,
                    color: const Color(0xFF2A2A2A),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Rating and Episode
                    Row(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          episodeCount == "null" ? "? Episodes" : "$episodeCount Episodes",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Genres
                    if (genres.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: genres.take(3).map<Widget>((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              genre['title'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Synopsis (short)
                    if (synopsisText.isNotEmpty) ...[
                      Text(
                        synopsisText,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AllAnimePage extends StatefulWidget {
  const AllAnimePage({super.key});

  @override
  State<AllAnimePage> createState() => _AllAnimePageState();
}

class _AllAnimePageState extends State<AllAnimePage> {
  List<dynamic> animeList = [];
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchAllAnime();
  }

Future<void> fetchAllAnime() async {
  setState(() {
    isLoading = true;
    isError = false;
    errorMessage = '';
  });

  try {
    debugPrint('🔍 Fetching all anime from /unlimited...');
    
    final response = await http.get(
      Uri.parse('https://www.sankavollerei.com/anime/unlimited'),
    );

    debugPrint('📡 Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      debugPrint('📦 Response keys: ${jsonData.keys}');
      
      // ✅ STRUKTUR YANG BENAR: jsonData['data']['list']
      if (jsonData['data'] != null && jsonData['data']['list'] != null) {
        
        List<dynamic> allAnime = [];
        final listByAbjad = jsonData['data']['list'] as List;
        
        // Loop setiap kelompok abjad (#, A, B, C, ...)
        for (var abjadGroup in listByAbjad) {
          if (abjadGroup['animeList'] != null) {
            final animeInGroup = abjadGroup['animeList'] as List;
            allAnime.addAll(animeInGroup);
          }
        }
        
        setState(() {
          animeList = allAnime;
          isLoading = false;
        });
        
        debugPrint('✅ Loaded ${animeList.length} anime from all abjad!');
        
      } 
      // Fallback untuk struktur lain (kalau berubah)
      else if (jsonData['data'] != null && jsonData['data']['anime'] != null) {
        setState(() {
          animeList = jsonData['data']['anime'];
          isLoading = false;
        });
        debugPrint('✅ Loaded ${animeList.length} anime (from data.anime)');
      }
      else if (jsonData['data'] is List) {
        setState(() {
          animeList = jsonData['data'];
          isLoading = false;
        });
        debugPrint('✅ Loaded ${animeList.length} anime (direct list)');
      }
      else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'Unexpected response format';
        });
      }
      
    } else {
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = 'Server error: ${response.statusCode}';
      });
    }
  } catch (e) {
    debugPrint('❌ Error fetching all anime: $e');
    setState(() {
      isLoading = false;
      isError = true;
      errorMessage = e.toString();
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "All Anime",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load all anime",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchAllAnime,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : animeList.isEmpty
                  ? const Center(
                      child: Text(
                        "No anime available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildAnimeList(),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFF1F1F1F),
        highlightColor: const Color(0xFF2A2A2A),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

// 🔥 PENGGANTI GRID JADI LIST BIASA KARENA API UNLIMITED GAK ADA POSTERNYA
  Widget _buildAnimeList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: animeList.length,
      itemBuilder: (context, index) {
        final anime = animeList[index];
        
        final String title = anime['title'] ?? anime['anime_name'] ?? 'Unknown';
        final String slug = anime['animeId'] ?? anime['slug'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
            onTap: () {
              if (slug.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimeDetailPage(slug: slug),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

class OngoingAnimePage extends StatefulWidget {
  const OngoingAnimePage({super.key});

  @override
  State<OngoingAnimePage> createState() => _OngoingAnimePageState();
}

class _OngoingAnimePageState extends State<OngoingAnimePage> {
  List<dynamic> animeList = [];
  Map<String, dynamic>? pagination;
  bool isLoading = true;
  bool isError = false;
  int currentPage = 1;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchOngoingAnime();
  }

  Future<void> fetchOngoingAnime({int page = 1}) async {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = '';
    });

    try {
      debugPrint('🔍 Fetching ongoing anime page $page...');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/ongoing-anime?page=$page'),
      );

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Response keys: ${jsonData.keys}');
        
        if (jsonData['data'] != null) {
          // Handle berbagai kemungkinan struktur
          if (jsonData['data'] is List) {
            setState(() {
              animeList = jsonData['data'];
              pagination = null;
              isLoading = false;
              currentPage = page;
            });
          } 
          else if (jsonData['data']['animeList'] != null) {
            setState(() {
              animeList = jsonData['data']['animeList'];
              pagination = jsonData['data']['pagination'];
              isLoading = false;
              currentPage = page;
            });
          }
          else if (jsonData['data']['anime'] != null) {
            setState(() {
              animeList = jsonData['data']['anime'];
              pagination = jsonData['data']['pagination'];
              isLoading = false;
              currentPage = page;
            });
          }
          else {
            setState(() {
              animeList = [];
              isLoading = false;
            });
          }
          
          debugPrint('✅ Loaded ${animeList.length} ongoing anime');
        } else {
          throw Exception('Invalid response structure');
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching ongoing anime: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Ongoing Anime",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load ongoing anime",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => fetchOngoingAnime(page: currentPage),
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : animeList.isEmpty
                  ? const Center(
                      child: Text(
                        "No ongoing anime available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildContent(),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFF1F1F1F),
        highlightColor: const Color(0xFF2A2A2A),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Pagination Info
        if (pagination != null) _buildPaginationInfo(),
        
        // Anime Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: animeList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 260,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final anime = animeList[index];
              
              final String title = anime['title'] ?? 'Unknown';
              final String poster = anime['poster'] ?? '';
              final String episode = anime['episodes']?.toString() ?? 
                                     anime['episode_count']?.toString() ?? '-';
              final String? score = anime['score'] ?? anime['rating'];
              final String slug = anime['animeId'] ?? anime['slug'] ?? '';

              return GestureDetector(
                onTap: () {
                  if (slug.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeDetailPage(slug: slug),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster with rating
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            poster,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 170,
                              color: const Color(0xFF1F1F1F),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        if (score != null && score.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    score,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Ongoing badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ONGOING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Episodes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "$episode Episodes",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Pagination Controls
        if (pagination != null && (pagination!['has_next_page'] == true || pagination!['has_previous_page'] == true))
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Page $currentPage of ${pagination!['last_visible_page']}",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            "Total: ${animeList.length} anime",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    final hasNext = pagination!['has_next_page'] ?? false;
    final hasPrev = pagination!['has_previous_page'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasPrev)
            ElevatedButton(
              onPressed: () => fetchOngoingAnime(page: currentPage - 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 4),
                  Text("Previous"),
                ],
              ),
            ),

          const SizedBox(width: 16),

          if (hasNext)
            ElevatedButton(
              onPressed: () => fetchOngoingAnime(page: currentPage + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Next"),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CompleteAnimePage extends StatefulWidget {
  const CompleteAnimePage({super.key});

  @override
  State<CompleteAnimePage> createState() => _CompleteAnimePageState();
}

class _CompleteAnimePageState extends State<CompleteAnimePage> {
  List<dynamic> animeList = [];
  Map<String, dynamic>? pagination;
  bool isLoading = true;
  bool isError = false;
  int currentPage = 1;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchCompleteAnime();
  }

  Future<void> fetchCompleteAnime({int page = 1}) async {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = '';
    });

    try {
      debugPrint('🔍 Fetching complete anime page $page...');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/complete-anime?page=$page'),
      );

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Response keys: ${jsonData.keys}');
        
        if (jsonData['data'] != null) {
          // Handle berbagai kemungkinan struktur
          if (jsonData['data'] is List) {
            setState(() {
              animeList = jsonData['data'];
              pagination = null;
              isLoading = false;
              currentPage = page;
            });
          } 
          else if (jsonData['data']['animeList'] != null) {
            setState(() {
              animeList = jsonData['data']['animeList'];
              pagination = jsonData['data']['pagination'];
              isLoading = false;
              currentPage = page;
            });
          }
          else if (jsonData['data']['anime'] != null) {
            setState(() {
              animeList = jsonData['data']['anime'];
              pagination = jsonData['data']['pagination'];
              isLoading = false;
              currentPage = page;
            });
          }
          else {
            setState(() {
              animeList = [];
              isLoading = false;
            });
          }
          
          debugPrint('✅ Loaded ${animeList.length} complete anime');
        } else {
          throw Exception('Invalid response structure');
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching complete anime: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Complete Anime",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load complete anime",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => fetchCompleteAnime(page: currentPage),
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : animeList.isEmpty
                  ? const Center(
                      child: Text(
                        "No complete anime available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildContent(),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFF1F1F1F),
        highlightColor: const Color(0xFF2A2A2A),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Pagination Info
        if (pagination != null) _buildPaginationInfo(),
        
        // Anime Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: animeList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 260,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final anime = animeList[index];
              
              final String title = anime['title'] ?? 'Unknown';
              final String poster = anime['poster'] ?? '';
              final String episode = anime['episodes']?.toString() ?? 
                                     anime['episode_count']?.toString() ?? '-';
              final String? score = anime['score'] ?? anime['rating'];
              final String slug = anime['animeId'] ?? anime['slug'] ?? '';

              return GestureDetector(
                onTap: () {
                  if (slug.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeDetailPage(slug: slug),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster with rating
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            poster,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 170,
                              color: const Color(0xFF1F1F1F),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        if (score != null && score.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    score,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Complete badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'COMPLETE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Episodes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "$episode Episodes",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Pagination Controls
        if (pagination != null && (pagination!['has_next_page'] == true || pagination!['has_previous_page'] == true))
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Page $currentPage of ${pagination!['last_visible_page']}",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            "Total: ${animeList.length} anime",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    final hasNext = pagination!['has_next_page'] ?? false;
    final hasPrev = pagination!['has_previous_page'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasPrev)
            ElevatedButton(
              onPressed: () => fetchCompleteAnime(page: currentPage - 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 4),
                  Text("Previous"),
                ],
              ),
            ),

          const SizedBox(width: 16),

          if (hasNext)
            ElevatedButton(
              onPressed: () => fetchCompleteAnime(page: currentPage + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Next"),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AnimeBatchPage extends StatefulWidget {
  final String batchSlug;
  final String animeTitle;

  const AnimeBatchPage({
    super.key,
    required this.batchSlug,
    required this.animeTitle,
  });

  @override
  State<AnimeBatchPage> createState() => _AnimeBatchPageState();
}

class _AnimeBatchPageState extends State<AnimeBatchPage> {
  Map<String, dynamic>? batchData;
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchBatchData();
  }

  Future<void> fetchBatchData() async {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = '';
    });

    try {
      debugPrint('🔍 Fetching batch: ${widget.batchSlug}');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/batch/${widget.batchSlug}'),
      );

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Response keys: ${jsonData.keys}');
        
        setState(() {
          batchData = jsonData['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching batch: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _getProviderIcon(String provider) {
    final prov = provider.toLowerCase();
    if (prov.contains('odfiles')) {
      return const Icon(Icons.storage, color: Colors.blue, size: 20);
    } else if (prov.contains('pdrain') || prov.contains('pixel')) {
      return const Icon(Icons.cloud_download, color: Colors.green, size: 20);
    } else if (prov.contains('acefile')) {
      return const Icon(Icons.folder, color: Colors.orange, size: 20);
    } else if (prov.contains('gofile')) {
      return const Icon(Icons.file_copy, color: Colors.purple, size: 20);
    } else if (prov.contains('mega')) {
      return const Icon(Icons.cloud, color: Colors.red, size: 20);
    } else if (prov.contains('kfiles') || prov.contains('kraken')) {
      return const Icon(Icons.archive, color: Colors.yellow, size: 20);
    }
    return const Icon(Icons.link, color: Colors.white, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: Text(
          "Batch: ${widget.animeTitle}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load batch data",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchBatchData,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : batchData == null
                  ? const Center(
                      child: Text(
                        "No batch data available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildBatchContent(),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1F1F1F),
          highlightColor: const Color(0xFF2A2A2A),
          child: Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchContent() {
    final List<dynamic> batchList = batchData?['batchList'] ?? [];
    
    if (batchList.isEmpty) {
      return const Center(
        child: Text(
          "No download links available",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: batchList.length,
      itemBuilder: (context, index) {
        final batch = batchList[index];
        final String resolution = batch['resolution'] ?? 'Unknown';
        final String size = batch['size'] ?? '?';
        final List<dynamic> urls = batch['urls'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                resolution,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              "$resolution • $size",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: urls.map<Widget>((urlData) {
              return ListTile(
                leading: _getProviderIcon(urlData['title'] ?? ''),
                title: Text(
                  urlData['title'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                onTap: () => _launchURL(urlData['url']),
                trailing: const Icon(Icons.cloud_download, color: Colors.white, size: 20),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class AnimeSchedulePage extends StatefulWidget {
  const AnimeSchedulePage({super.key});

  @override
  State<AnimeSchedulePage> createState() => _AnimeSchedulePageState();
}

class _AnimeSchedulePageState extends State<AnimeSchedulePage> {
  List<dynamic> scheduleData = [];
  bool isLoading = true;
  bool isError = false;

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      debugPrint('🔍 Fetching schedule...');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/schedule'),
      );

      debugPrint('📡 Schedule status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Schedule response keys: ${jsonData.keys}');
        
        // PERBAIKAN: Data mungkin di jsonData['data'] atau langsung array
        if (jsonData['data'] != null) {
          setState(() {
            scheduleData = jsonData['data'] as List;
            isLoading = false;
          });
        } else if (jsonData is List) {
          setState(() {
            scheduleData = jsonData;
            isLoading = false;
          });
        } else {
          throw Exception('Invalid schedule response structure');
        }
        
        debugPrint('✅ Loaded ${scheduleData.length} days');
      } else {
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching schedule: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Release Schedule",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load release schedule",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchSchedule,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : scheduleData.isEmpty
                  ? const Center(
                      child: Text(
                        "No schedule available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildScheduleContent(),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1F1F1F),
          highlightColor: const Color(0xFF2A2A2A),
          child: Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: scheduleData.length,
      itemBuilder: (context, index) {
        final daySchedule = scheduleData[index];
        final String day = daySchedule['day'] ?? 'Unknown';
        final List<dynamic> animeList = daySchedule['anime_list'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        day,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${animeList.length} Anime",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Anime List
                if (animeList.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: animeList.length,
                      itemBuilder: (context, animeIndex) {
                        final anime = animeList[animeIndex];
                        final String title = anime['anime_name'] ?? anime['title'] ?? 'Unknown';
                        final String poster = anime['poster'] ?? '';
                        final String slug = anime['slug'] ?? '';

                        return Container(
                          width: 120,
                          margin: EdgeInsets.only(
                            right: animeIndex == animeList.length - 1 ? 0 : 12,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              if (slug.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnimeDetailPage(slug: slug),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Poster
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    poster,
                                    width: 120,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 120,
                                      height: 160,
                                      color: const Color(0xFF1F1F1F),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Title
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Release time if available
                                if (anime['release_time'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      anime['release_time'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No anime scheduled for this day",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimeGenreListPage extends StatefulWidget {
  const AnimeGenreListPage({super.key});

  @override
  State<AnimeGenreListPage> createState() => _AnimeGenreListPageState();
}

class _AnimeGenreListPageState extends State<AnimeGenreListPage> {
  List<dynamic> genreList = [];
  bool isLoading = true;
  bool isError = false;

  Future<void> fetchGenreList() async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      debugPrint('🔍 Fetching genre list...');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/genre'),
      );

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Response structure: ${jsonData.keys}');
        
        // PERBAIKAN: Ambil dari data.genreList
        if (jsonData['data'] != null && jsonData['data']['genreList'] != null) {
          setState(() {
            genreList = jsonData['data']['genreList'];
            isLoading = false;
          });
          debugPrint('✅ Loaded ${genreList.length} genres');
        } else {
          debugPrint('❌ Unexpected response structure');
          setState(() {
            isLoading = false;
            isError = true;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching genre list: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchGenreList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Anime Genres",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load genre list",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchGenreList,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : genreList.isEmpty
                  ? const Center(
                      child: Text(
                        "No genres available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildGenreGrid(),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 20,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.0,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1F1F1F),
          highlightColor: const Color(0xFF2A2A2A),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenreGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: genreList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.0,
      ),
      itemBuilder: (context, index) {
        final genre = genreList[index];
        
        // Sesuai struktur JSON
        String name = genre['title'] ?? 'Unknown';
        String slug = genre['genreId'] ?? '';

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              if (slug.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimeGenrePage(
                      genreSlug: slug,
                      genreName: name,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimeEpisodePage extends StatefulWidget {
  final String episodeSlug;
  final String? animeSlug;
  final String? animeTitle;
  final String? animePoster;
  final List<dynamic>? episodes;
  final List<dynamic>? recommendations;
  final Function()? onHistoryUpdate;

  const AnimeEpisodePage({
    super.key,
    required this.episodeSlug,
    this.animeSlug,
    this.animeTitle,
    this.animePoster,
    this.episodes,
    this.recommendations,
    this.onHistoryUpdate,
  });

  @override
  State<AnimeEpisodePage> createState() => _AnimeEpisodePageState();
}

class _AnimeEpisodePageState extends State<AnimeEpisodePage> with WidgetsBindingObserver {
  Map<String, dynamic>? episodeData;
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';
  int _currentTabIndex = 0;

  // WebView Controller
  late WebViewController _webViewController;
  bool _isWebViewLoading = true;
  bool _isFullScreen = false;

  // Current episode index
  int _currentEpisodeIndex = 0;

  // Selected server
  String? _selectedQuality;
  Map<String, dynamic>? _selectedServer;
  List<Map<String, dynamic>> _availableServers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    debugPrint('🔍 EpisodeSlug: ${widget.episodeSlug}');
    
    fetchEpisodeData();
    _findCurrentEpisodeIndex();
  }

  void _findCurrentEpisodeIndex() {
    if (widget.episodes != null) {
      for (int i = 0; i < widget.episodes!.length; i++) {
        if (widget.episodes![i]['episodeId'] == widget.episodeSlug) {
          setState(() {
            _currentEpisodeIndex = i;
          });
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final physicalSize = WidgetsBinding.instance.window.physicalSize;
    final pixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
    final logicalSize = physicalSize / pixelRatio;

    final isNowFullScreen = logicalSize.width > logicalSize.height;

    if (isNowFullScreen != _isFullScreen) {
      setState(() {
        _isFullScreen = isNowFullScreen;
      });

      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> fetchEpisodeData() async {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = '';
    });

    try {
      final url = 'https://www.sankavollerei.com/anime/episode/${widget.episodeSlug}';
      debugPrint('🌐 Fetching from: $url');
      
      final response = await http.get(Uri.parse(url));

      debugPrint('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Response keys: ${jsonData.keys}');
        
        if (jsonData['data'] != null) {
          final data = jsonData['data'];
          
          setState(() {
            episodeData = data;
          });
          
          // Parse available servers dari data
          _parseServers(data);
          
          // Coba auto-select quality pertama
          if (_availableServers.isNotEmpty) {
            _selectServer(_availableServers.first['quality'], _availableServers.first['servers'].first);
          }
          
          _addToWatchHistory();
          
          setState(() {
            isLoading = false;
          });
        } else {
          throw Exception('Invalid response structure: missing data field');
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching episode: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = e.toString();
      });
    }
  }

  void _parseServers(Map<String, dynamic> data) {
    if (data['server'] != null && data['server']['qualities'] != null) {
      final qualities = data['server']['qualities'] as List;
      
      _availableServers = qualities.map((quality) {
        return {
          'quality': quality['title'],
          'servers': (quality['serverList'] as List).map((server) {
            return {
              'title': server['title'],
              'serverId': server['serverId'],
              'href': server['href'],
            };
          }).toList(),
        };
      }).toList();
      
      debugPrint('✅ Found ${_availableServers.length} quality options');
    }
  }

  Future<void> _selectServer(String quality, Map<String, dynamic> server) async {
    setState(() {
      _selectedQuality = quality;
      _selectedServer = server;
      _isWebViewLoading = true;
    });

    try {
      // Panggil endpoint server untuk dapetin URL streaming asli
      final serverId = server['serverId'];
      debugPrint('🌐 Fetching server URL for: $serverId');
      
      final response = await http.get(
        Uri.parse('https://www.sankavollerei.com/anime/server/$serverId'),
      );

      debugPrint('📡 Server response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('📦 Server response keys: ${jsonData.keys}');
        
        // Ambil stream URL dari response
        String streamUrl = '';
        
        if (jsonData['data'] != null && jsonData['data']['stream_url'] != null) {
          streamUrl = jsonData['data']['stream_url'];
        } else if (jsonData['stream_url'] != null) {
          streamUrl = jsonData['stream_url'];
        } else {
          // Fallback ke defaultStreamingUrl
          streamUrl = episodeData?['defaultStreamingUrl'] ?? '';
        }
        
        if (streamUrl.isNotEmpty) {
          _initializeWebView(streamUrl);
        } else {
          throw Exception('Stream URL not found');
        }
      } else {
        // Fallback ke defaultStreamingUrl jika gagal
        String streamUrl = episodeData?['defaultStreamingUrl'] ?? '';
        if (streamUrl.isNotEmpty) {
          _initializeWebView(streamUrl);
        } else {
          throw Exception('Failed to get stream URL');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting stream URL: $e');
      setState(() {
        _isWebViewLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load stream: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeWebView(String streamUrl) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FullScreen',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'enter') {
            _enterFullScreen();
          } else if (message.message == 'exit') {
            _exitFullScreen();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isWebViewLoading = false;
              });
              _injectFullScreenDetection();
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isWebViewLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isWebViewLoading = false;
            });
            _injectFullScreenDetection();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WebView error: $error');
            setState(() {
              _isWebViewLoading = false;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(streamUrl),
        headers: _getChromeHeaders(),
      );
  }

  void _injectFullScreenDetection() {
    _webViewController.runJavaScript('''
      function handleFullScreenChange() {
        if (document.fullscreenElement || document.webkitFullscreenElement || 
            document.mozFullScreenElement || document.msFullscreenElement) {
          FullScreen.postMessage('enter');
        } else {
          FullScreen.postMessage('exit');
        }
      }
      document.addEventListener('fullscreenchange', handleFullScreenChange);
      document.addEventListener('webkitfullscreenchange', handleFullScreenChange);
      document.addEventListener('mozfullscreenchange', handleFullScreenChange);
      document.addEventListener('MSFullscreenChange', handleFullScreenChange);
    ''');
  }

  void _enterFullScreen() {
    if (!_isFullScreen) {
      setState(() {
        _isFullScreen = true;
      });
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _exitFullScreen() {
    if (_isFullScreen) {
      setState(() {
        _isFullScreen = false;
      });
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Map<String, String> _getChromeHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': 'https://otakudesu.best/',
    };
  }

  Future<void> _addToWatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('watch_history') ?? [];
      List<Map<String, dynamic>> watchHistory = historyJson
          .map((item) => Map<String, dynamic>.from(json.decode(item)))
          .toList();

      String lastWatchedEpisode = episodeData?['title'] ?? 'Episode ${_currentEpisodeIndex + 1}';

      final historyItem = {
        'slug': widget.animeSlug,
        'title': widget.animeTitle,
        'poster': widget.animePoster,
        'last_watched_episode': lastWatchedEpisode,
        'last_watched_episode_slug': widget.episodeSlug,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      watchHistory.removeWhere((item) => item['slug'] == widget.animeSlug);
      watchHistory.insert(0, historyItem);

      if (watchHistory.length > 20) {
        watchHistory = watchHistory.sublist(0, 20);
      }

      final newHistoryJson = watchHistory.map((item) => json.encode(item)).toList();
      await prefs.setStringList('watch_history', newHistoryJson);

      if (widget.onHistoryUpdate != null) {
        widget.onHistoryUpdate!();
      }
    } catch (e) {
      debugPrint('Error saving to watch history: $e');
    }
  }

  void _refreshWebView() {
    if (_selectedServer != null && episodeData?['defaultStreamingUrl'] != null) {
      _webViewController.reload();
    }
  }

  void _openInExternalBrowser() {
    if (episodeData?['defaultStreamingUrl'] != null) {
      _launchURL(episodeData!['defaultStreamingUrl']);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showServerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Server",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _availableServers.length,
                      itemBuilder: (context, index) {
                        final quality = _availableServers[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                quality['quality'],
                                style: const TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...(quality['servers'] as List).map((server) {
                              return ListTile(
                                title: Text(
                                  server['title'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _selectServer(quality['quality'], server);
                                },
                              );
                            }).toList(),
                          ],
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

  void _showDownloadOptions() {
    if (episodeData == null || episodeData!['downloadUrl'] == null) return;

    final downloadUrls = episodeData!['downloadUrl'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Download Episode",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: downloadUrls['qualities']?.length ?? 0,
                      itemBuilder: (context, index) {
                        final quality = downloadUrls['qualities'][index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ExpansionTile(
                            leading: const Icon(Icons.download, color: Colors.white),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quality['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (quality['size'] != null)
                                  Text(
                                    quality['size'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            children: (quality['urls'] as List).map<Widget>((urlData) {
                              return ListTile(
                                leading: _getProviderIcon(urlData['title']),
                                title: Text(
                                  urlData['title'],
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                onTap: () => _launchURL(urlData['url']),
                                trailing: const Icon(Icons.cloud_download, color: Colors.white, size: 20),
                              );
                            }).toList(),
                          ),
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

  Widget _getProviderIcon(String provider) {
    final prov = provider.toLowerCase();
    if (prov.contains('odfiles')) {
      return const Icon(Icons.storage, color: Colors.blue, size: 20);
    } else if (prov.contains('pdrain') || prov.contains('pixel')) {
      return const Icon(Icons.cloud_download, color: Colors.green, size: 20);
    } else if (prov.contains('acefile')) {
      return const Icon(Icons.folder, color: Colors.orange, size: 20);
    } else if (prov.contains('gofile')) {
      return const Icon(Icons.file_copy, color: Colors.purple, size: 20);
    } else if (prov.contains('mega')) {
      return const Icon(Icons.cloud, color: Colors.red, size: 20);
    } else if (prov.contains('kfiles') || prov.contains('kraken')) {
      return const Icon(Icons.archive, color: Colors.yellow, size: 20);
    }
    return const Icon(Icons.link, color: Colors.white, size: 20);
  }

  void _goToNextEpisode() {
    if (widget.episodes != null && _currentEpisodeIndex < widget.episodes!.length - 1) {
      final nextEpisode = widget.episodes![_currentEpisodeIndex + 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AnimeEpisodePage(
            episodeSlug: nextEpisode['episodeId'],
            animeSlug: widget.animeSlug,
            animeTitle: widget.animeTitle,
            animePoster: widget.animePoster,
            episodes: widget.episodes,
            recommendations: widget.recommendations,
            onHistoryUpdate: widget.onHistoryUpdate,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: _isFullScreen ? null : AppBar(
        title: Text(
          episodeData?['title'] ?? "Streaming Anime",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (episodeData != null) ...[
            // Server selector button
            if (_availableServers.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.language, color: Colors.white),
                onPressed: _showServerSelector,
                tooltip: 'Change Server',
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshWebView,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              onPressed: _openInExternalBrowser,
              tooltip: 'Open in Browser',
            ),
            if (episodeData!['downloadUrl'] != null)
              IconButton(
                onPressed: _showDownloadOptions,
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Download',
              ),
          ],
        ],
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load episode",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchEpisodeData,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : episodeData == null
                  ? const Center(child: Text("No data", style: TextStyle(color: Colors.white)))
                  : _buildStreamingContent(),
    );
  }

  Widget _buildStreamingContent() {
    final List<dynamic> episodes = widget.episodes ?? [];
    final List<dynamic> recommendations = widget.recommendations ?? [];
    final List<dynamic> genres = episodeData?['info']?['genreList'] ?? [];

    return Column(
      children: [
        // Video Player Section
        Container(
          height: _isFullScreen
              ? MediaQuery.of(context).size.height
              : MediaQuery.of(context).size.height * 0.3,
          width: double.infinity,
          color: Colors.black,
          child: Stack(
            children: [
              // 1. WEBVIEW (Diumpetin pakai Opacity 0 selama loading biar ga abu-abu)
              if (_selectedServer != null && episodeData?['defaultStreamingUrl'] != null)
                Opacity(
                  opacity: _isWebViewLoading ? 0.0 : 1.0,
                  child: WebViewWidget(controller: _webViewController),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.grey, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Select a server to start watching",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showServerSelector,
                        child: const Text("Choose Server"),
                      ),
                    ],
                  ),
                ),
              
              // 2. LOADING MENYIAPKAN VIDEO (Hitam pekat kaya anime1)
              if (_isWebViewLoading && _selectedServer != null)
                Container(
                  color: Colors.black, // <-- Hitam pekat, bukan black87
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFE50914),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Menyiapkan Video...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. TOMBOL FULLSCREEN
              if (_isFullScreen && _selectedServer != null)
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 30),
                    ),
                    onPressed: _exitFullScreen,
                  ),
                ),
            ],
          ),
        ),

        // Server Info Bar (if not fullscreen)
        if (!_isFullScreen && _selectedServer != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedQuality ?? 'Auto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedServer?['title'] ?? 'Server',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _showServerSelector,
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Color(0xFFE50914)),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (!_isFullScreen) ...[
          // Tab Bar
          Container(
            height: 50,
            color: const Color(0xFF1F1F1F),
            child: Row(
              children: [
                _buildTabButton(0, Icons.playlist_play, 'Episodes'),
                _buildTabButton(1, Icons.recommend, 'Recommendations'),
                _buildTabButton(2, Icons.category, 'Info'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildEpisodeList(episodes),
                _buildRecommendations(recommendations),
                _buildInfoTab(genres),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: Material(
        color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentTabIndex = index;
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeList(List<dynamic> episodes) {
    if (episodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              color: Colors.grey,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "No episodes available",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_currentEpisodeIndex < episodes.length - 1)
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _goToNextEpisode,
              icon: const Icon(Icons.skip_next),
              label: const Text("Next Episode"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              final isCurrentEpisode = episode['episodeId'] == widget.episodeSlug;
              final episodeNumber = episode['eps']?.toString() ?? '?';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: isCurrentEpisode
                      ? const Color(0xFFE50914).withOpacity(0.2)
                      : const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrentEpisode
                      ? Border.all(color: const Color(0xFFE50914), width: 1)
                      : null,
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentEpisode
                          ? const Color(0xFFE50914)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        episodeNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    episode['title'] ?? 'Episode $episodeNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: episode['date'] != null && episode['date'].toString().isNotEmpty
                      ? Text(
                          episode['date'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  onTap: () {
                    if (!isCurrentEpisode) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimeEpisodePage(
                            episodeSlug: episode['episodeId'],
                            animeSlug: widget.animeSlug,
                            animeTitle: widget.animeTitle,
                            animePoster: widget.animePoster,
                            episodes: widget.episodes,
                            recommendations: widget.recommendations,
                            onHistoryUpdate: widget.onHistoryUpdate,
                          ),
                        ),
                      );
                    }
                  },
                  trailing: Icon(
                    isCurrentEpisode ? Icons.play_arrow : Icons.play_circle_outline,
                    color: isCurrentEpisode ? const Color(0xFFE50914) : Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(List<dynamic> recommendations) {
    if (recommendations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation,
              color: Colors.grey,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "No recommendations available",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = recommendations[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailPage(
                  slug: recommendation['animeId'],
                  onHistoryUpdate: widget.onHistoryUpdate,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recommendation['poster'],
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: const Color(0xFF1F1F1F),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recommendation['title'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(List<dynamic> genres) {
    final info = episodeData?['info'];
    
    if (info == null) {
      return const Center(
        child: Text(
          "No information available",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anime Info
          const Text(
            "Information",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildInfoRow("Duration", info['duration']),
                _buildInfoRow("Type", info['type']),
                _buildInfoRow("Credit", info['credit']),
                _buildInfoRow("Encoder", info['encoder']),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Genres
          if (genres.isNotEmpty) ...[
            const Text(
              "Genres",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map<Widget>((genre) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeGenrePage(
                          genreSlug: genre['genreId'],
                          genreName: genre['title'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      genre['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Anime Poster and Title
          if (widget.animeTitle != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.animePoster ?? '',
                      height: 80,
                      width: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        width: 60,
                        color: const Color(0xFF2A2A2A),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Now Playing",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.animeTitle ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildLoadingShimmer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE50914)),
          const SizedBox(height: 20),
          const Text(
            "Sedang Memuat Episode...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}