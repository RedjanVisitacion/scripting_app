import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = false;
  List<String> _backups = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await BackupService.initialize();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService.listBackups();
    setState(() => _backups = backups);
  }

  Future<void> _backup() async {
    setState(() => _isLoading = true);
    final result = await BackupService.backupDatabase();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Done'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ));
      if (result['success'] == true) _loadBackups();
    }
  }

  void _showSettings() {
    final controller = TextEditingController(text: BackupService.savedUrl ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${BackupService.baseUrl}'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.101.11:8000',
              ),
            ),
            const Text('Run ipconfig to find your IP', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () async {
            await BackupService.clearUrl();
            if (mounted) Navigator.pop(context);
          }, child: const Text('Auto')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final url = controller.text.trim();
            if (url.isNotEmpty) await BackupService.setManualUrl(url);
            else await BackupService.clearUrl();
            if (mounted) Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Backup'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.backup, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text('Backup Database', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('Auto-detects your server', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _backup,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                      label: Text(_isLoading ? 'Backing up...' : 'Backup Database'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Previous Backups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _backups.isEmpty
                  ? const Center(child: Text('No backups yet', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _backups.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(_backups[i]),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
