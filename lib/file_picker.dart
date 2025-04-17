// lib/screens/import_messages_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'message_importer.dart';

class ImportMessagesScreen extends StatefulWidget {
  const ImportMessagesScreen({Key? key}) : super(key: key);
  
  @override
  _ImportMessagesScreenState createState() => _ImportMessagesScreenState();
}

class _ImportMessagesScreenState extends State<ImportMessagesScreen> {
  final MpesaImporter _importer = MpesaImporter();
  bool _isLoading = false;
  String _statusMessage = '';
  
  @override
  void initState() {
    super.initState();
    _initializeImporter();
  }
  
  Future<void> _initializeImporter() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing...';
    });
    
    try {
      await _importer.initialize();
      setState(() {
        _statusMessage = kIsWeb 
            ? 'Ready to import. Select a JSON file from your computer.' 
            : 'Ready to import';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _importFromBrowser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening file browser...';
    });
    
    try {
      // This uses the importFromJsonFile method which is already configured to handle web
      final importedCount = await _importer.importFromJsonFile();
      setState(() {
        if (importedCount > 0) {
          _statusMessage = 'Successfully imported $importedCount messages';
        } else {
          _statusMessage = 'No files imported. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error importing: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _importFromSampleData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Importing sample data...';
    });
    
    try {
      final importedCount = await _importer.importFromAsset('assets/mpesa.json');
      setState(() {
        _statusMessage = 'Successfully imported $importedCount sample messages';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error importing sample data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _importer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import M-Pesa Messages'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Import your M-Pesa transaction data',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Upload a JSON file containing your M-Pesa transactions. '
                          'The file must be in the correct format with transaction details.',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload JSON File', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _isLoading ? null : _importFromBrowser,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Not ready with your data? Try our sample data to see how the app works.',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.dataset),
                          label: const Text('Import Sample Data', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _isLoading ? null : _importFromSampleData,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoading
                      ? Column(
                          key: const ValueKey('loading'),
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : _statusMessage.isNotEmpty
                          ? Container(
                              key: const ValueKey('status'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _statusMessage.contains('Successfully') 
                                    ? Colors.green.withOpacity(0.1) 
                                    : _statusMessage.contains('Error')
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _statusMessage.contains('Successfully') 
                                      ? Colors.green.withOpacity(0.3) 
                                      : _statusMessage.contains('Error')
                                          ? Colors.red.withOpacity(0.3)
                                          : Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _statusMessage.contains('Successfully') 
                                        ? Icons.check_circle 
                                        : _statusMessage.contains('Error')
                                            ? Icons.error
                                            : Icons.info,
                                    color: _statusMessage.contains('Successfully') 
                                        ? Colors.green 
                                        : _statusMessage.contains('Error')
                                            ? Colors.red
                                            : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _statusMessage,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _statusMessage.contains('Successfully') 
                                            ? Colors.green.shade700 
                                            : _statusMessage.contains('Error')
                                                ? Colors.red.shade700
                                                : Colors.blue.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}