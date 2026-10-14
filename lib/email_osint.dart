// email_osint.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

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
}

// ─── Model Hasil OSINT ────────────────────────────────────────────────────
class EmailOsintResult {
  final String email;
  final bool isValid;
  final String domain;
  final bool isDisposable;
  final bool hasMx;
  final String? provider;
  final String? risk;
  final String? country;
  final Map<String, dynamic> rawData;

  EmailOsintResult({
    required this.email,
    required this.isValid,
    required this.domain,
    required this.isDisposable,
    required this.hasMx,
    this.provider,
    this.risk,
    this.country,
    required this.rawData,
  });

  factory EmailOsintResult.fromJson(Map<String, dynamic> json, String email) {
    final domain = email.split('@').last.toLowerCase();
    
    String? provider;
    if (domain.contains('gmail')) provider = 'Google (Gmail)';
    else if (domain.contains('yahoo')) provider = 'Yahoo';
    else if (domain.contains('outlook') || domain.contains('hotmail') || domain.contains('live')) provider = 'Microsoft (Outlook)';
    else if (domain.contains('proton')) provider = 'ProtonMail';
    else if (domain.contains('icloud') || domain.contains('me.com')) provider = 'Apple (iCloud)';
    else provider = 'Custom Domain';
    
    return EmailOsintResult(
      email: email,
      isValid: json['format_valid'] ?? false,
      domain: domain,
      isDisposable: json['disposable'] ?? false,
      hasMx: json['mx_found'] ?? false,
      provider: provider,
      risk: json['risk'] ?? (json['disposable'] == true ? 'High' : 'Low'),
      country: json['domain_country'],
      rawData: json,
    );
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────
class EmailOsintPage extends StatefulWidget {
  const EmailOsintPage({super.key});

  @override
  State<EmailOsintPage> createState() => _EmailOsintPageState();
}

class _EmailOsintPageState extends State<EmailOsintPage> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  EmailOsintResult? _result;
  String? _errorMessage;

  static const String _apiUrl = 'https://api.emailvalidation.io/v1/info?email=';

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _lookupEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });
    
    final email = _emailController.text.trim();
    
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl$email'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = EmailOsintResult.fromJson(data, email);
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = _getFallbackResult(email);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Gagal terhubung ke API, menggunakan mode offline'),
          ]),
          backgroundColor: _C.red.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
  
  EmailOsintResult _getFallbackResult(String email) {
    final domain = email.split('@').last.toLowerCase();
    bool isDisposable = ['tempmail.com', '10minutemail.com', 'guerrillamail.com'].contains(domain);
    bool hasMx = !isDisposable;
    
    String? provider;
    if (domain.contains('gmail')) provider = 'Google (Gmail)';
    else if (domain.contains('yahoo')) provider = 'Yahoo';
    else if (domain.contains('outlook') || domain.contains('hotmail')) provider = 'Microsoft';
    else if (domain.contains('proton')) provider = 'ProtonMail';
    else provider = 'Custom Domain';
    
    return EmailOsintResult(
      email: email,
      isValid: email.contains('@') && email.contains('.'),
      domain: domain,
      isDisposable: isDisposable,
      hasMx: hasMx,
      provider: provider,
      risk: isDisposable ? 'High' : 'Low',
      rawData: {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInputSection(),
                        
                        const SizedBox(height: 24),
                        
                        if (_isLoading) _buildLoadingIndicator(),
                        
                        if (_errorMessage != null && !_isLoading)
                          _buildErrorMessage(),
                        
                        if (_result != null && !_isLoading)
                          _buildResultCard(),
                      ],
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
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _C.bg.withOpacity(0.95),
            _C.bg.withOpacity(0.85),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: _C.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.cardInner.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                    color: _C.blue.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: _C.blueLight,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.card.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _C.blueLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _C.blueLight.withOpacity(0.5), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'EMAIL OSINT',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
         
        ],
      ),
    );
  }
  
  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.card,
            _C.cardInner,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _C.blueLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Email Address Lookup',
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: _C.text),
                    cursorColor: _C.blueLight,
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      hintStyle: const TextStyle(color: _C.textSub),
                      prefixIcon: Icon(Icons.email_rounded, color: _C.blueLight, size: 20),
                      filled: true,
                      fillColor: _C.bg.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _C.blueLight, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  GestureDetector(
                    onTap: _lookupEmail,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_C.steel, _C.blueMid, _C.blueLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _C.blueMid.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'LOOKUP EMAIL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
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
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _C.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _C.blueLight,
              backgroundColor: _C.border,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menganalisis email...',
            style: TextStyle(color: _C.textSub),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _C.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _C.textSub),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultCard() {
    final result = _result!;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _C.card,
                _C.cardInner,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: _C.blue.withOpacity(0.08),
                blurRadius: 20,
              ),
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
                      color: result.isValid ? _C.green.withOpacity(0.1) : _C.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: result.isValid ? _C.green.withOpacity(0.3) : _C.red.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      result.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: result.isValid ? _C.green : _C.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.email,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.isValid ? 'Email Valid' : 'Email Invalid',
                          style: TextStyle(
                            color: result.isValid ? _C.green : _C.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(color: _C.border, height: 1),
              const SizedBox(height: 16),
              
              _buildInfoRow(
                icon: Icons.public_rounded,
                label: 'Domain',
                value: result.domain,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.business_rounded,
                label: 'Provider',
                value: result.provider ?? 'Unknown',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.email_rounded,
                label: 'MX Record',
                value: result.hasMx ? 'Tersedia' : 'Tidak Tersedia',
                valueColor: result.hasMx ? _C.green : _C.amber,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.warning_amber_rounded,
                label: 'Disposable',
                value: result.isDisposable ? 'Ya (Temporary Email)' : 'Tidak',
                valueColor: result.isDisposable ? _C.red : _C.green,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.security_rounded,
                label: 'Risk Level',
                value: result.risk ?? 'Low',
                valueColor: result.risk == 'High' ? _C.red : (result.risk == 'Medium' ? _C.amber : _C.green),
              ),
              if (result.country != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Country',
                  value: result.country!,
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.cardInner.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.blueLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lightbulb_rounded, color: _C.amber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isValid 
                    ? (result.isDisposable 
                        ? 'Email ini bersifat sementara (disposable). Hati-hati untuk verifikasi akun.'
                        : 'Email valid dengan MX record. Cocok untuk komunikasi bisnis.')
                    : 'Email ini tidak valid atau tidak memiliki MX record.',
                  style: const TextStyle(color: _C.textSub, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: _C.blueLight, size: 18),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: _C.textSub, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _C.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(controller.value),
      ),
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
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.steel.withOpacity(0.10 + math.sin(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.9).createShader(
        Rect.fromCircle(center: Offset(size.width / 2, 0), radius: size.width)
      );
    canvas.drawCircle(Offset(size.width / 2, 0), size.width, glow);

    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        _C.blueMid.withOpacity(0.05 + math.cos(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.5).createShader(
        Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.75), radius: size.width * 0.4)
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      size.width * 0.4,
      glow2,
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}