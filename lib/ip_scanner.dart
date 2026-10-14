// ip_scanner.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

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

// ─── Model IP Scanner Result ──────────────────────────────────────────────
class IpScannerResult {
  final String ip;
  final String country;
  final String countryCode;
  final String region;
  final String regionName;
  final String city;
  final String zip;
  final double lat;
  final double lon;
  final String timezone;
  final String isp;
  final String org;
  final String as;
  final String query;
  final bool isValid;
  final Map<String, dynamic> rawData;

  IpScannerResult({
    required this.ip,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.regionName,
    required this.city,
    required this.zip,
    required this.lat,
    required this.lon,
    required this.timezone,
    required this.isp,
    required this.org,
    required this.as,
    required this.query,
    required this.isValid,
    required this.rawData,
  });

  factory IpScannerResult.fromJson(Map<String, dynamic> json, String queryIp) {
    return IpScannerResult(
      ip: json['ip'] ?? queryIp,
      country: json['country'] ?? 'Unknown',
      countryCode: json['countryCode'] ?? 'Unknown',
      region: json['region'] ?? 'Unknown',
      regionName: json['regionName'] ?? 'Unknown',
      city: json['city'] ?? 'Unknown',
      zip: json['zip'] ?? 'Unknown',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      timezone: json['timezone'] ?? 'Unknown',
      isp: json['isp'] ?? 'Unknown',
      org: json['org'] ?? 'Unknown',
      as: json['as'] ?? 'Unknown',
      query: json['query'] ?? queryIp,
      isValid: json['ip'] != null,
      rawData: json,
    );
  }

  // Factory untuk IP lokal (127.0.0.1, 192.168.x.x, dll)
  factory IpScannerResult.local(String ip) {
    return IpScannerResult(
      ip: ip,
      country: 'Local Network',
      countryCode: 'LOCAL',
      region: 'Local',
      regionName: 'Local Network',
      city: 'Local',
      zip: 'N/A',
      lat: 0,
      lon: 0,
      timezone: 'Local',
      isp: 'Local Network',
      org: 'Local',
      as: 'N/A',
      query: ip,
      isValid: true,
      rawData: {},
    );
  }

  // Factory untuk IP invalid
  factory IpScannerResult.invalid(String ip) {
    return IpScannerResult(
      ip: ip,
      country: 'Invalid',
      countryCode: 'INVALID',
      region: 'Invalid',
      regionName: 'Invalid',
      city: 'Invalid',
      zip: 'N/A',
      lat: 0,
      lon: 0,
      timezone: 'Unknown',
      isp: 'Unknown',
      org: 'Unknown',
      as: 'Unknown',
      query: ip,
      isValid: false,
      rawData: {},
    );
  }
}

// ─── IP Validator ─────────────────────────────────────────────────────────
class IpValidator {
  static bool isValidIPv4(String ip) {
    final RegExp ipv4Regex = RegExp(
      r'^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipv4Regex.hasMatch(ip);
  }

  static bool isPrivateIP(String ip) {
    // Private IP ranges
    final RegExp privateRegex = RegExp(
      r'^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)',
    );
    return privateRegex.hasMatch(ip);
  }

  static bool isLoopback(String ip) {
    return ip.startsWith('127.') || ip == 'localhost';
  }

  static String getIPClass(String ip) {
    if (!isValidIPv4(ip)) return 'Invalid';
    
    final firstOctet = int.parse(ip.split('.')[0]);
    
    if (firstOctet >= 1 && firstOctet <= 126) return 'Class A';
    if (firstOctet >= 128 && firstOctet <= 191) return 'Class B';
    if (firstOctet >= 192 && firstOctet <= 223) return 'Class C';
    if (firstOctet >= 224 && firstOctet <= 239) return 'Class D (Multicast)';
    if (firstOctet >= 240 && firstOctet <= 255) return 'Class E (Reserved)';
    
    return 'Unknown';
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────
class IpScannerPage extends StatefulWidget {
  const IpScannerPage({super.key});

  @override
  State<IpScannerPage> createState() => _IpScannerPageState();
}

class _IpScannerPageState extends State<IpScannerPage> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  final TextEditingController _ipController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  IpScannerResult? _result;
  String? _errorMessage;

  // API gratis tanpa API key (ip-api.com)
  static const String _apiUrl = 'http://ip-api.com/json/';
  // Fallback API (freegeoip)
  static const String _fallbackUrl = 'https://ipinfo.io/';

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
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _scanIp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });
    
    final ip = _ipController.text.trim();
    
    // Cek IP lokal
    if (IpValidator.isPrivateIP(ip)) {
      setState(() {
        _result = IpScannerResult.local(ip);
        _isLoading = false;
      });
      return;
    }
    
    // Cek IP loopback
    if (IpValidator.isLoopback(ip)) {
      setState(() {
        _result = IpScannerResult.local(ip);
        _isLoading = false;
      });
      return;
    }
    
    // Validasi format IP
    if (!IpValidator.isValidIPv4(ip)) {
      setState(() {
        _result = IpScannerResult.invalid(ip);
        _isLoading = false;
        _errorMessage = 'Format IP tidak valid';
      });
      return;
    }
    
    try {
      // Panggil API ip-api.com
      final response = await http.get(
        Uri.parse('$_apiUrl$ip?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success') {
          setState(() {
            _result = IpScannerResult.fromJson(data, ip);
            _isLoading = false;
          });
        } else {
          // Coba API fallback
          await _tryFallbackAPI(ip);
        }
      } else {
        await _tryFallbackAPI(ip);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal terhubung ke server';
        _isLoading = false;
        _result = IpScannerResult.local(ip);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Gagal mengambil data, menampilkan info lokal'),
          ]),
          backgroundColor: _C.amber.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _tryFallbackAPI(String ip) async {
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/$ip/json/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == null) {
          setState(() {
            _result = IpScannerResult(
              ip: data['ip'] ?? ip,
              country: data['country_name'] ?? 'Unknown',
              countryCode: data['country_code'] ?? 'Unknown',
              region: data['region'] ?? 'Unknown',
              regionName: data['region'] ?? 'Unknown',
              city: data['city'] ?? 'Unknown',
              zip: data['postal'] ?? 'Unknown',
              lat: (data['latitude'] ?? 0).toDouble(),
              lon: (data['longitude'] ?? 0).toDouble(),
              timezone: data['timezone'] ?? 'Unknown',
              isp: data['org'] ?? 'Unknown',
              org: data['org'] ?? 'Unknown',
              as: data['asn'] ?? 'Unknown',
              query: ip,
              isValid: true,
              rawData: data,
            );
            _isLoading = false;
          });
        } else {
          setState(() {
            _result = IpScannerResult.local(ip);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _result = IpScannerResult.local(ip);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = IpScannerResult.local(ip);
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin', style: const TextStyle(color: Colors.white)),
        backgroundColor: _C.blueMid,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
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
                  'IP SCANNER',
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
                        'IP Address Scanner',
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
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _C.text),
                    cursorColor: _C.blueLight,
                    decoration: InputDecoration(
                      hintText: '8.8.8.8 atau 192.168.1.1',
                      hintStyle: const TextStyle(color: _C.textSub),
                      prefixIcon: Icon(Icons.dns_rounded, color: _C.blueLight, size: 20),
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
                        return 'IP Address tidak boleh kosong';
                      }
                      if (!IpValidator.isValidIPv4(value) && 
                          !IpValidator.isPrivateIP(value) && 
                          value != 'localhost') {
                        return 'Format IP Address tidak valid';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info contoh IP
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildExampleChip('8.8.8.8', 'Google DNS'),
                      _buildExampleChip('1.1.1.1', 'Cloudflare'),
                      _buildExampleChip('192.168.1.1', 'Local'),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  GestureDetector(
                    onTap: _scanIp,
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
                            'SCAN IP',
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

  Widget _buildExampleChip(String ip, String label) {
    return GestureDetector(
      onTap: () {
        _ipController.text = ip;
        _scanIp();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _C.cardInner,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, color: _C.blueLight, size: 12),
            const SizedBox(width: 4),
            Text(
              ip,
              style: const TextStyle(color: _C.text, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: _C.textSub, fontSize: 9),
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
            'Mendapatkan informasi IP...',
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
    final bool isLocal = result.countryCode == 'LOCAL' || result.country == 'Local Network';
    
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
                          result.ip,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.isValid ? 'IP Address Valid' : 'IP Address Invalid',
                          style: TextStyle(
                            color: result.isValid ? _C.green : _C.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _copyToClipboard(result.ip, 'IP Address'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _C.cardInner,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.border),
                      ),
                      child: Icon(Icons.copy_rounded, color: _C.blueLight, size: 18),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(color: _C.border, height: 1),
              const SizedBox(height: 16),
              
              if (!isLocal) ...[
                _buildInfoRow(
                  icon: Icons.public_rounded,
                  label: 'Country',
                  value: '${result.country} (${result.countryCode})',
                  onCopy: () => _copyToClipboard(result.country, 'Country'),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: result.city,
                  onCopy: () => _copyToClipboard(result.city, 'City'),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow(
                  icon: Icons.map_rounded,
                  label: 'Region',
                  value: result.regionName,
                ),
                const SizedBox(height: 12),
                
                if (result.zip != 'Unknown') ...[
                  _buildInfoRow(
                    icon: Icons.local_post_office_rounded,
                    label: 'Postal Code',
                    value: result.zip,
                  ),
                  const SizedBox(height: 12),
                ],
                
                _buildInfoRow(
                  icon: Icons.business_rounded,
                  label: 'ISP',
                  value: result.isp,
                  onCopy: () => _copyToClipboard(result.isp, 'ISP'),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow(
                  icon: Icons.apartment_rounded,
                  label: 'Organization',
                  value: result.org,
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow(
                  icon: Icons.link_rounded,
                  label: 'AS Number',
                  value: result.as,
                ),
                const SizedBox(height: 12),
              ],
              
              _buildInfoRow(
                icon: Icons.timeline_rounded,
                label: 'IP Class',
                value: IpValidator.getIPClass(result.ip),
              ),
              const SizedBox(height: 12),
              
              _buildInfoRow(
                icon: Icons.security_rounded,
                label: 'IP Type',
                value: IpValidator.isPrivateIP(result.ip) 
                    ? 'Private IP' 
                    : (IpValidator.isLoopback(result.ip) ? 'Loopback' : 'Public IP'),
              ),
              
              if (!isLocal && result.lat != 0) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Coordinates',
                  value: '${result.lat}, ${result.lon}',
                  onCopy: () => _copyToClipboard('${result.lat}, ${result.lon}', 'Coordinates'),
                ),
              ],
              
              if (!isLocal && result.timezone != 'Unknown') ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Timezone',
                  value: result.timezone,
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
                child: Icon(Icons.info_outline_rounded, color: _C.blueLight, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLocal
                      ? 'IP ini adalah alamat lokal/private. Informasi geolokasi tidak tersedia.'
                      : 'Informasi IP diperoleh dari database real-time. Lokasi mungkin tidak 100% akurat.',
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
    VoidCallback? onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _C.blueLight, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: _C.textSub, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _C.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.cardInner,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Icon(Icons.copy_rounded, color: _C.textSub, size: 14),
              ),
            ),
        ],
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