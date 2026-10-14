import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class ManageServerPage extends StatefulWidget {
  final String keyToken;
  const ManageServerPage({super.key, required this.keyToken});

  @override
  State<ManageServerPage> createState() => _ManageServerPageState();
}

class _ManageServerPageState extends State<ManageServerPage> {
  List<Map<String, dynamic>> vpsList = [];
  bool isLoading = false;

  final _hostController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  // --- Warna Tema Hitam Cyan ---
  final Color primaryDark = const Color(0xFF0B1A1A);
  final Color primaryWhite = Colors.white;
  final Color accentCyan = const Color(0xFF00ACC1);
  final Color cardDark = const Color(0xFF1A2A2A);

  @override
  void initState() {
    super.initState();
    _fetchVpsList();
  }

  Future<void> _fetchVpsList() async {
    setState(() => isLoading = true);
    final uri = Uri.parse('$baseUrl/myServer?key=${widget.keyToken}');
    try {
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      setState(() {
        vpsList = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      _showError("Gagal mengambil data VPS.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _addVps() async {
    final host = _hostController.text.trim();
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (host.isEmpty || user.isEmpty || pass.isEmpty) {
      _showError("Isi semua field terlebih dahulu.");
      return;
    }

    final uri = Uri.parse('$baseUrl/addServer');
    try {
      final res = await http.post(uri, body: {
        'key': widget.keyToken,
        'host': host,
        'username': user,
        'password': pass,
      });
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _hostController.clear();
        _userController.clear();
        _passController.clear();
        _fetchVpsList();
      } else {
        _showError(data['error'] ?? 'Gagal menambah VPS');
      }
    } catch (_) {
      _showError("Gagal terhubung ke server.");
    }
  }

  Future<void> _deleteVps(String host) async {
    final uri = Uri.parse('$baseUrl/delServer');
    try {
      final res = await http.post(uri, body: {
        'key': widget.keyToken,
        'host': host,
      });
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _fetchVpsList();
      } else {
        _showError("Gagal menghapus VPS.");
      }
    } catch (_) {
      _showError("Gagal menghubungi server.");
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentCyan.withOpacity(0.3)),
        ),
        title: const Text("Error", style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentCyan.withOpacity(0.3)),
        ),
        title: const Text("Tambah VPS", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInput("IP VPS", _hostController),
            _buildInput("Username", _userController),
            _buildInput("Password", _passController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addVps();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan,
            ),
            child: const Text("TAMBAH", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accentCyan),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: accentCyan.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: accentCyan),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: primaryDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: primaryDark,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("My VPS List",
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'Orbitron')),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF00ACC1)),
                    onPressed: _showAddDialog,
                  )
                ],
              ),
              Divider(color: accentCyan),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00ACC1)))
                    : ListView.builder(
                  itemCount: vpsList.length,
                  itemBuilder: (context, index) {
                    final vps = vpsList[index];
                    return Card(
                      color: cardDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: accentCyan.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        title: Text("${vps['host']}", style: const TextStyle(color: Colors.white)),
                        subtitle: Text("User: ${vps['username']}", style: const TextStyle(color: Colors.white70)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFF00ACC1)),
                          onPressed: () => _deleteVps(vps['host']),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}