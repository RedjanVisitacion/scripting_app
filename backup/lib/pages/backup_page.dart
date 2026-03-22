import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<BackupInfo> _backups = [];
  DateTime? _lastRefreshed;
  String _connectionStatus = 'Checking...';

  Timer? _autoRefreshTimer;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _initialize() async {
    await BackupService.initialize();
    _checkConnection();
    await _loadBackups();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _silentRefresh();
    });
  }

  void _silentRefresh() {
    if (!_isRefreshing) _loadBackups(showLoading: false);
  }

  Future<void> _checkConnection() async {
    setState(() => _connectionStatus = 'Connected to ${BackupService.baseUrl}');
  }

  Future<void> _loadBackups({bool showLoading = true}) async {
    if (showLoading) setState(() => _isRefreshing = true);

    try {
      final backupFiles = await BackupService.listBackups();
      final List<BackupInfo> backupInfoList = [];

      for (final filename in backupFiles) {
        final info = _parseBackupInfo(filename);
        backupInfoList.add(info);
      }

      backupInfoList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _backups = backupInfoList;
          _lastRefreshed = DateTime.now();
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  BackupInfo _parseBackupInfo(String filename) {
    DateTime timestamp = DateTime.now();
    try {
      final match = RegExp(r'(\d{8})_(\d{6})').firstMatch(filename);
      if (match != null) {
        final dateStr = match.group(1)!;
        final timeStr = match.group(2)!;
        timestamp = DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
          int.parse(timeStr.substring(0, 2)),
          int.parse(timeStr.substring(2, 4)),
          int.parse(timeStr.substring(4, 6)),
        );
      }
    } catch (e) {}

    return BackupInfo(filename: filename, timestamp: timestamp);
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);
    final result = await BackupService.backupDatabase();

    if (mounted) {
      setState(() => _isLoading = false);
      _showResultSnackbar(
        message: result['message'] ?? 'Operation completed',
        isSuccess: result['success'] == true,
      );
      if (result['success'] == true) await _loadBackups();
    }
  }

  void _showResultSnackbar({required String message, required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ],
      ),
      backgroundColor: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: BackupService.savedUrl ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_outlined, color: Color(0xFF667eea), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text('Server Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_tethering, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Current: ${BackupService.baseUrl}', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.100:8000',
                      prefixIcon: const Icon(Icons.link, color: Color(0xFF667eea)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (!value.startsWith('http://') && !value.startsWith('https://')) return 'Must start with http:// or https://';
                      if (!value.contains(':')) return 'Must include port (e.g., :8000)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Leave empty to auto-detect server on your network', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await BackupService.clearUrl();
                          if (mounted) {
                            Navigator.of(context).pop();
                            _showResultSnackbar(message: 'Auto-detecting server...', isSuccess: true);
                            await _loadBackups();
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Auto'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF667eea)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final url = controller.text.trim();
                            if (url.isNotEmpty) await BackupService.setManualUrl(url);
                            else await BackupService.clearUrl();
                            if (mounted) {
                              Navigator.of(context).pop();
                              _showResultSnackbar(message: url.isNotEmpty ? 'Server set to: $url' : 'Auto-detecting server...', isSuccess: true);
                              await _loadBackups();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadBackups(showLoading: true);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF667eea),
        centerTitle: true,
        title: const Text('Database Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: _showServerSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF667eea),
        backgroundColor: Colors.white,
        displacement: 60,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildMainCard()),
            if (_lastRefreshed != null) SliverToBoxAdapter(child: _buildLastRefreshedBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Previous Backups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
                    if (_isRefreshing)
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF667eea)))),
                  ],
                ),
              ),
            ),
            _backups.isEmpty ? _buildEmptyState() : _buildBackupList(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF667eea).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(right: -50, top: -50, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
            Positioned(left: -30, bottom: -30, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15 + 0.05 * _pulseController!.value), shape: BoxShape.circle),
                      child: const Icon(Icons.cloud_upload_rounded, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Backup Database', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_connectionStatus, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _performBackup,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading)
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF667eea))))
                              else
                                const Icon(Icons.backup_rounded, color: Color(0xFF667eea), size: 20),
                              const SizedBox(width: 12),
                              Text(_isLoading ? 'Backing up...' : 'Backup Database', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF667eea))),
                            ],
                          ),
                        ),
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

  Widget _buildLastRefreshedBar() {
    final timeString = DateFormat('HH:mm:ss').format(_lastRefreshed!);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('Last refreshed: $timeString', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text('No backups yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Create your first backup by tapping the button above', style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final backup = _backups[index];
            final isLatest = index == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isLatest ? Border.all(color: const Color(0xFF667eea).withOpacity(0.3), width: 2) : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: isLatest ? const Color(0xFF667eea).withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: Icon(isLatest ? Icons.cloud_done : Icons.insert_drive_file_outlined, color: isLatest ? const Color(0xFF667eea) : Colors.grey[500], size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isLatest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: const Color(0xFF667eea), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('LATEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    Expanded(
                                      child: Text(backup.filename, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1a1a2e)), overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(DateFormat('MMM d, yyyy • HH:mm').format(backup.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _backups.length,
        ),
      ),
    );
  }
}

class BackupInfo {
  final String filename;
  final DateTime timestamp;

  BackupInfo({required this.filename, required this.timestamp});
}
