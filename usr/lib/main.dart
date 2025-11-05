import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const TSFPApp());
}

class TSFPApp extends StatefulWidget {
  const TSFPApp({super.key});

  @override
  State<TSFPApp> createState() => _TSFPAppState();
}

class _TSFPAppState extends State<TSFPApp> {
  String _themeKey = 'bright';

  void _changeTheme(String newTheme) {
    setState(() {
      _themeKey = newTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getTheme(_themeKey);

    return MaterialApp(
      title: 'TSFP Count App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: theme['background'],
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme['accent'],
          brightness: _themeKey == 'dark' ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomePage(themeKey: _themeKey, onThemeChange: _changeTheme),
    );
  }

  Map<String, Color> _getTheme(String key) {
    switch (key) {
      case 'warm':
        return {
          'background': const Color(0xFFFFF8F0),
          'card': const Color(0xFFFFF4EB),
          'text': const Color(0xFF40210F),
          'accent': const Color(0xFFF59E0B),
          'secondary': const Color(0xFFBCF87),
        };
      case 'dark':
        return {
          'background': const Color(0xFF0B1220),
          'card': const Color(0xFF0F1724),
          'text': const Color(0xFFE6EEF8),
          'accent': const Color(0xFF7C3AED),
          'secondary': const Color(0xFF94A3FF),
        };
      default: // bright
        return {
          'background': const Color(0xFFF7F9FC),
          'card': const Color(0xFFFFFFFF),
          'text': const Color(0xFF0B2545),
          'accent': const Color(0xFF2B8AEF),
          'secondary': const Color(0xFF7AA9E9),
        };
    }
  }
}

class HomePage extends StatefulWidget {
  final String themeKey;
  final Function(String) onThemeChange;

  const HomePage({super.key, required this.themeKey, required this.onThemeChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _ageGroups = [
    {'key': '6-11', 'label': '6 – 11 months'},
    {'key': '12-23', 'label': '12 – 23 months'},
    {'key': '24-59', 'label': '24 – 59 months'},
  ];

  List<Map<String, dynamic>> _entries = [];
  String _selectedAgeGroup = '6-11';
  String _sex = 'Male';
  final TextEditingController _countController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString('tsfp_entries_v1');
    final themeKey = prefs.getString('tsfp_theme_v1');

    if (entriesJson != null) {
      setState(() {
        _entries = List<Map<String, dynamic>>.from(json.decode(entriesJson));
      });
    }

    if (themeKey != null && ['bright', 'warm', 'dark'].contains(themeKey)) {
      widget.onThemeChange(themeKey);
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tsfp_entries_v1', json.encode(_entries));
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tsfp_theme_v1', theme);
  }

  void _addEntry() {
    final count = int.tryParse(_countController.text);
    if (count == null || count <= 0) {
      _showAlert('Invalid count', 'Please enter a positive whole number.');
      return;
    }

    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'ageGroupKey': _selectedAgeGroup,
      'sex': _sex,
      'count': count,
    };

    setState(() {
      _entries.insert(0, entry);
      _countController.clear();
    });
    _saveEntries();
  }

  Map<String, int> _computeTotals() {
    final totals = <String, int>{};
    for (var group in _ageGroups) {
      totals[group['key']] = 0;
    }
    totals['total'] = 0;

    for (var entry in _entries) {
      final key = entry['ageGroupKey'];
      totals[key] = (totals[key] ?? 0) + (entry['count'] as int);
      totals['total'] = (totals['total'] ?? 0) + (entry['count'] as int);
    }

    return totals;
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all'),
        content: const Text('This will remove all saved entries. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _entries.clear();
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tsfp_entries_v1');
            },
            child: const Text('Yes, clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCSV() async {
    if (_entries.isEmpty) {
      _showAlert('Nothing to export', 'There are no entries to export.');
      return;
    }

    final header = 'age_group,sex,count,timestamp';
    final rows = _entries.map((e) {
      return '${e['ageGroupKey']},${e['sex']},${e['count']},${e['id']}';
    }).join('\n');
    final csv = '$header\n$rows';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'TSFP_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'TSFP Data Export',
      );
    } catch (e) {
      _showAlert('Export failed', 'Could not create or share the CSV.');
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleTheme() {
    final next = widget.themeKey == 'bright'
        ? 'warm'
        : widget.themeKey == 'warm'
            ? 'dark'
            : 'bright';
    widget.onThemeChange(next);
    _saveTheme(next);
  }

  String _getThemeName(String key) {
    switch (key) {
      case 'warm':
        return 'Warm';
      case 'dark':
        return 'Midnight';
      default:
        return 'Bright';
    }
  }

  Map<String, Color> _getTheme() {
    switch (widget.themeKey) {
      case 'warm':
        return {
          'background': const Color(0xFFFFF8F0),
          'card': const Color(0xFFFFF4EB),
          'text': const Color(0xFF40210F),
          'accent': const Color(0xFFF59E0B),
          'secondary': const Color(0xFFFBCF87),
        };
      case 'dark':
        return {
          'background': const Color(0xFF0B1220),
          'card': const Color(0xFF0F1724),
          'text': const Color(0xFFE6EEF8),
          'accent': const Color(0xFF7C3AED),
          'secondary': const Color(0xFF94A3FF),
        };
      default:
        return {
          'background': const Color(0xFFF7F9FC),
          'card': const Color(0xFFFFFFFF),
          'text': const Color(0xFF0B2545),
          'accent': const Color(0xFF2B8AEF),
          'secondary': const Color(0xFF7AA9E9),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getTheme();
    final totals = _computeTotals();

    return Scaffold(
      backgroundColor: theme['background'],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              Text(
                'TSFP Count App',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme['text'],
                ),
              ),
              Text(
                'Quick data entry — age groups & sex',
                style: TextStyle(
                  fontSize: 13,
                  color: theme['secondary'],
                ),
              ),
              const SizedBox(height: 12),
              // Data Entry Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme['card'],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Age group',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme['text'],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ageGroups.map((g) {
                        final isSelected = _selectedAgeGroup == g['key'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAgeGroup = g['key']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? theme['accent']! : const Color(0xFFDDDDDD),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              g['label'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme['text'],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sex',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme['text'],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Male', 'Female'].map((s) {
                        final isSelected = _sex == s;
                        return GestureDetector(
                          onTap: () => setState(() => _sex = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? theme['accent']! : const Color(0xFFDDDDDD),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme['text'],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme['text'],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme['text']),
                      decoration: InputDecoration(
                        hintText: 'Enter number (e.g. 3)',
                        hintStyle: TextStyle(color: theme['secondary']),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme['secondary']!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme['secondary']!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme['accent']!, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme['accent'],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _exportCSV,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme['accent'],
                              side: BorderSide(color: theme['accent']!),
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Export CSV',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Totals Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme['card'],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Totals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme['text'],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleTheme,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDDDDDD)),
                                ),
                                child: Text(
                                  _getThemeName(widget.themeKey),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme['text'],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _clearAll,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDDDDDD)),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme['text'],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ..._ageGroups.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFFE6E6E6).withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              g['label'],
                              style: TextStyle(fontSize: 15, color: theme['text']),
                            ),
                            Text(
                              '${totals[g['key']] ?? 0}',
                              style: TextStyle(fontSize: 15, color: theme['text']),
                            ),
                          ],
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overall total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme['text'],
                            ),
                          ),
                          Text(
                            '${totals['total'] ?? 0}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme['text'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Recent Entries
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent entries',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme['text'],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _entries.isEmpty
                          ? Center(
                              child: Text(
                                'No entries yet.',
                                style: TextStyle(color: theme['secondary']),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme['card'],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${entry['ageGroupKey']} • ${entry['sex']}',
                                            style: TextStyle(
                                              color: theme['text'],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${entry['count']} person(s)',
                                            style: TextStyle(color: theme['secondary']),
                                          ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _entries.removeAt(index);
                                          });
                                          _saveEntries();
                                        },
                                        child: Text(
                                          'Remove',
                                          style: TextStyle(color: theme['accent']),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }
}
