import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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

  // Instagram gradient accent
  static const igPink    = Color(0xFFE1306C);
  static const igOrange  = Color(0xFFF77737);
  static const igPurple  = Color(0xFF833AB4);

  static const green     = Color(0xFF22C55E);
  static const red       = Color(0xFFEF4444);
  static const amber     = Color(0xFFF59E0B);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient igGrad = LinearGradient(
    colors: [igPurple, igPink, igOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class InstagramDownloaderPage extends StatefulWidget {
  const InstagramDownloaderPage({super.key});

  @override
  State<InstagramDownloaderPage> createState() =>
      _InstagramDownloaderPageState();
}

class _InstagramDownloaderPageState extends State<InstagramDownloaderPage>
    with TickerProviderStateMixin {
  final _urlCtrl = TextEditingController();
  bool _isLoading = false;
  List<dynamic>? _mediaData;
  String? _error;
  bool _isSharing = false;

  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _btnCtrl;

  late Animation<double> _entrance;
  late Animation<double> _logoSpin;
  late Animation<double> _logoPulse;
  late Animation<double> _resultFade;
  late Animation<Offset>  _resultSlide;
  late Animation<double>  _btnGlow;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _entranceCtrl.forward();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _logoSpin  = Tween<double>(begin: 0, end: 1.0).animate(_logoCtrl);
    _logoPulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _btnGlow = Tween<double>(begin: 0.25, end: 0.6)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _logoCtrl.dispose();
    _resultCtrl.dispose();
    _btnCtrl.dispose();
    _urlCtrl.dispose();
    _videoCtrl?.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _download() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() { _error = 'URL tidak boleh kosong.'; _mediaData = null; });
      return;
    }

    _videoCtrl?.dispose();
    _chewieCtrl?.dispose();
    setState(() {
      _isLoading = true;
      _error = null;
      _mediaData = null;
      _videoCtrl = null;
      _chewieCtrl = null;
    });
    _resultCtrl.reset();

    try {
      final res = await http.get(
          Uri.parse('https://api.siputzx.my.id/api/d/igdl?url=${Uri.encodeComponent(url)}'));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == true && json['data'] != null) {
          setState(() => _mediaData = json['data']);
          _initVideo();
          _resultCtrl.forward();
        } else {
          setState(() => _error = 'Gagal mengambil data Instagram.');
        }
      } else {
        setState(() => _error = 'Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Koneksi gagal. Periksa jaringan.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initVideo([String? overrideUrl]) {
    if (_mediaData == null || _mediaData!.isEmpty) return;
    final url = overrideUrl ?? _mediaData![0]['url'];

    _videoCtrl?.dispose();
    _chewieCtrl?.dispose();

    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _chewieCtrl = ChewieController(
            videoPlayerController: _videoCtrl!,
            autoPlay: true,
            looping: false,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: _C.blueMid,
              handleColor: _C.blueLight,
              backgroundColor: _C.border,
              bufferedColor: _C.borderLit,
            ),
          );
        });
      });
  }

  Future<void> _shareVideo() async {
    if (_mediaData == null || _mediaData!.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      final res  = await http.get(Uri.parse(_mediaData![0]['url']));
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/ig_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(res.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Video Instagram');
    } catch (e) {
      _toast('Gagal berbagi: $e', error: true);
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? _C.red : _C.blueMid,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
            child: FadeTransition(
              opacity: _entrance,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          _buildHeroLogo(),
                          const SizedBox(height: 20),
                          _buildInputCard(),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _buildErrorBanner(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Results
                  if (_mediaData != null || _chewieCtrl != null)
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _resultFade,
                        child: SlideTransition(
                          position: _resultSlide,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Column(
                              children: [
                                // Video player
                                if (_chewieCtrl != null) ...[
                                  _buildVideoPlayer(),
                                  const SizedBox(height: 14),
                                ],
                                // Media gallery
                                if (_mediaData != null &&
                                    _mediaData!.length > 1) ...[
                                  _buildGalleryHeader(),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Media grid
                  if (_mediaData != null)
                    FadeTransition(
                      opacity: _resultFade,
                      child: SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _StaggerItem(
                              index: i,
                              child: _MediaCard(
                                media: Map<String, dynamic>.from(
                                    _mediaData![i]),
                                onPlay: (url) => _initVideo(url),
                              ),
                            ),
                            childCount: _mediaData!.length,
                          ),
                        ),
                      ),
                    ),

                  // Empty state
                  if (_mediaData == null && !_isLoading && _error == null)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    ),
                ],
              ),
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
        ShaderMask(
          shaderCallback: (b) => _C.igGrad.createShader(b),
          child: const Icon(Icons.camera_alt_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 9),
        const Text('Instagram Downloader',
            style: TextStyle(color: _C.text, fontSize: 16,
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ]),
      centerTitle: true,
    );
  }

  // ─── Hero Logo ────────────────────────────────────────────────────────────
  Widget _buildHeroLogo() {
    return AnimatedBuilder(
      animation: _logoCtrl,
      builder: (_, __) => Column(
        children: [
          Transform.scale(
            scale: _logoPulse.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating gradient ring
                Transform.rotate(
                  angle: _logoSpin.value * math.pi * 2,
                  child: Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          _C.igPurple, _C.igPink, _C.igOrange,
                          Colors.transparent, _C.igPurple,
                        ],
                      ),
                    ),
                  ),
                ),
                // Core
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.card,
                    border: Border.all(color: _C.border, width: 2),
                  ),
                  child: ShaderMask(
                    shaderCallback: (b) => _C.igGrad.createShader(b),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Instagram Media Downloader',
              style: TextStyle(color: _C.text, fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Reel · Post · Story · Carousel',
              style: TextStyle(color: _C.textSub, fontSize: 11,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ─── Input Card ───────────────────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _C.blue.withOpacity(0.07),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        _UrlInput(
          controller: _urlCtrl,
          isLoading: _isLoading,
          onSubmit: _download,
        ),
        const SizedBox(height: 14),
        _DownloadButton(
          isLoading: _isLoading,
          glowAnim: _btnGlow,
          onTap: _download,
        ),
      ]),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
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
    );
  }

  // ─── Video Player ─────────────────────────────────────────────────────────
  Widget _buildVideoPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.borderLit),
        boxShadow: [
          BoxShadow(color: _C.blue.withOpacity(0.1),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _C.border)),
              ),
              child: Row(children: [
                ShaderMask(
                  shaderCallback: (b) => _C.igGrad.createShader(b),
                  child: const Icon(Icons.play_circle_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Video Player',
                    style: TextStyle(color: _C.text, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // Share button
                _ShareBtn(isSharing: _isSharing, onTap: _shareVideo),
              ]),
            ),
            // Video
            AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio,
              child: Chewie(controller: _chewieCtrl!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryHeader() {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: _C.igGrad,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text('${_mediaData!.length} media ditemukan',
          style: const TextStyle(color: _C.text, fontSize: 14,
              fontWeight: FontWeight.w700)),
      const Spacer(),
      ShaderMask(
        shaderCallback: (b) => _C.igGrad.createShader(b),
        child: const Icon(Icons.photo_library_rounded,
            color: Colors.white, size: 18),
      ),
    ]);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _logoPulse,
              builder: (_, child) => Transform.scale(
                  scale: _logoPulse.value, child: child),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.card,
                  border: Border.all(color: _C.border),
                ),
                child: ShaderMask(
                  shaderCallback: (b) => _C.igGrad
                      .createShader(Rect.fromLTWH(0, 0, 80, 80)),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Siap untuk Download',
                style: TextStyle(color: _C.text, fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Paste URL Instagram Reel, Post,\natau Story di atas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSub, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── URL Input ────────────────────────────────────────────────────────────────
class _UrlInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _UrlInput({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<_UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<_UrlInput> {
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
          color: _focused ? _C.igPink.withOpacity(0.6) : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _C.igPink.withOpacity(0.08),
                blurRadius: 14, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: !widget.isLoading,
        keyboardType: TextInputType.url,
        style: const TextStyle(color: _C.text, fontSize: 13,
            fontWeight: FontWeight.w500),
        cursorColor: _C.igPink,
        onSubmitted: (_) => widget.onSubmit(),
        decoration: InputDecoration(
          hintText: 'https://www.instagram.com/reel/...',
          hintStyle: const TextStyle(color: _C.textDim, fontSize: 12),
          labelText: 'URL Instagram',
          labelStyle: const TextStyle(color: _C.textSub, fontSize: 12),
          floatingLabelStyle:
              const TextStyle(color: _C.igPink, fontSize: 11),
          prefixIcon: ShaderMask(
            shaderCallback: (b) => _C.igGrad.createShader(b),
            child: const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 18),
          ),
          suffixIcon: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.igPink),
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

// ─── Download Button ──────────────────────────────────────────────────────────
class _DownloadButton extends StatefulWidget {
  final bool isLoading;
  final Animation<double> glowAnim;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.isLoading,
    required this.glowAnim,
    required this.onTap,
  });

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: widget.glowAnim,
          builder: (_, __) => Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _C.igGrad,
              borderRadius: BorderRadius.circular(15),
              boxShadow: _down || widget.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: _C.igPink.withOpacity(
                            widget.glowAnim.value * 0.5),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
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
                          Text('Mengambil Media...',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Download Media',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 14,
                                  letterSpacing: 0.3)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Share Button ─────────────────────────────────────────────────────────────
class _ShareBtn extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onTap;
  const _ShareBtn({required this.isSharing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSharing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: _C.igGrad,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: _C.igPink.withOpacity(0.3), blurRadius: 10),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          isSharing
              ? const SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.share_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          const Text('Share', style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─── Media Card ───────────────────────────────────────────────────────────────
class _MediaCard extends StatefulWidget {
  final Map<String, dynamic> media;
  final void Function(String url) onPlay;

  const _MediaCard({required this.media, required this.onPlay});

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.media['type'] == 'video';
    final mediaUrl = widget.media['url'] as String? ?? '';
    final thumbUrl = widget.media['thumbnail'] as String? ?? mediaUrl;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (isVideo) widget.onPlay(mediaUrl);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? (isVideo ? _C.igPink : _C.blueLight).withOpacity(0.5)
                  : _C.border,
              width: _pressed ? 1.5 : 1.0,
            ),
            boxShadow: _pressed
                ? [BoxShadow(
                    color: (isVideo ? _C.igPink : _C.blueLight)
                        .withOpacity(0.15),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      isVideo ? thumbUrl : mediaUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) =>
                          prog == null ? child : Container(
                            color: _C.surface,
                            child: const Center(child: _DotsLoader()),
                          ),
                      errorBuilder: (_, __, ___) => Container(
                        color: _C.surface,
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                          color: _C.textDim, size: 32,
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x80060B14), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                    ),
                    // Play icon for video
                    if (isVideo)
                      Positioned(
                        bottom: 10, right: 10,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _C.igGrad,
                            boxShadow: [
                              BoxShadow(color: _C.igPink.withOpacity(0.4),
                                  blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    // Type badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isVideo ? _C.igPink : _C.blueLight)
                                .withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          isVideo ? 'VIDEO' : 'PHOTO',
                          style: TextStyle(
                            color: isVideo ? _C.igPink : _C.blueLight,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                color: _C.surface,
                child: Row(children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                    color: isVideo ? _C.igPink : _C.blueLight,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'Tap to play' : 'Photo',
                    style: const TextStyle(color: _C.textSub, fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ]),
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
      duration: Duration(milliseconds: 350 + (index * 60).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Dots Loader ──────────────────────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final s = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.scale(
              scale: 0.4 + s * 0.6,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blueMid.withOpacity(0.4 + s * 0.6),
                ),
              ),
            ),
          );
        }),
      ),
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
      ..color = _C.border.withOpacity(0.25)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Instagram-tinted glow
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFE1306C)
            .withOpacity(0.05 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.8).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.22),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.22), size.width * 0.65, glow);
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
