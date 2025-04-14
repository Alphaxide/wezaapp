// TODO Implement this library.
// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SMSService _smsService = SMSService();
  bool _autoRefresh = false;
  bool _darkMode = false;
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _autoRefresh = prefs.getBool('autoRefresh') ?? false;
        _darkMode = prefs.getBool('darkMode') ?? false;
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('autoRefresh', _autoRefresh);
      await prefs.setBool('darkMode', _darkMode);
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: ${e.toString()}')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Permissions'),
                _buildPermissionTile(),
                
                _buildSectionHeader('App Settings'),
                _buildSettingSwitch(
                  'Auto-refresh messages',
                  'Automatically fetch new messages when app opens',
                  _autoRefresh,
                  (value) {
                    setState(() {
                      _autoRefresh = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSettingSwitch(
                  'Dark mode',
                  'Use dark theme for the app',
                  _darkMode,
                  (value) {
                    setState(() {
                      _darkMode = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSettingSwitch(
                  'Notifications',
                  'Get notified when new M-Pesa messages arrive',
                  _notificationsEnabled,
                  (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                
                _buildSectionHeader('About'),
                ListTile(
                  title: const Text('M-Pesa SMS Analyzer'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.info_outline),
                  onTap: () {
                    // Show about dialog
                    showAboutDialog(
                      context: context,
                      applicationName: 'M-Pesa SMS Analyzer',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 M-Pesa SMS Analyzer',
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'This app helps you track and categorize your M-Pesa transactions by analyzing your SMS messages.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
  
  Widget _buildPermissionTile() {
    return FutureBuilder<bool>(
      future: _smsService.requestSmsPermission(),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        
        return ListTile(
          title: const Text('SMS Permission'),
          subtitle: Text(
            hasPermission 
                ? 'Permission granted'
                : 'Permission required to read SMS messages',
          ),
          trailing: hasPermission
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.warning, color: Colors.orange),
          onTap: () async {
            if (!hasPermission) {
              final status = await Permission.sms.request();
              setState(() {});
            }
          },
        );
      },
    );
  }
  
  Widget _buildSettingSwitch(
    String title, 
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}