import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'qr_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QrStorage.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class QrCodeData {
  QrCodeData(this.data, {int segmentLength = 300}) : segments = [] {
    var offset = 0;
    while (offset < data.length) {
      final end = math.min(offset + segmentLength, data.length);
      segments.add(data.substring(offset, end));
      offset = end;
    }
    if (segments.isEmpty) {
      segments.add('');
    }
  }

  final String data;

  final List<String> segments;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _dataController = TextEditingController();
  final _durationController = TextEditingController(text: '600');
  final _segmentLengthController = TextEditingController(text: '200');

  var _index = 0;
  QrCodeData _data = QrCodeData('');
  Timer? _timer;

  // 0 = history, 1 = favorites
  int _sidebarTab = 0;
  List<QrHistoryItem> _historyItems = [];
  List<QrHistoryItem> _favoriteItems = [];

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _dataController.addListener(_onDataChanged);
    _durationController.addListener(_onDataChanged);
    _segmentLengthController.addListener(_onDataChanged);
    _dataController.text = 'Hello World!';
    _refreshSidebar();
  }

  void _onDataChanged() {
    final segmentLength =
        int.tryParse(_segmentLengthController.text.trim()) ?? 200;
    final duration = int.tryParse(_durationController.text.trim()) ?? 600;
    _data =
        QrCodeData(_dataController.text.trim(), segmentLength: segmentLength);
    _performAnimation(duration: duration);

    // debounce save
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      _saveCurrentToHistory();
    });
  }

  Future<void> _saveCurrentToHistory() async {
    final text = _dataController.text.trim();
    if (text.isEmpty) return;
    final segmentLength =
        int.tryParse(_segmentLengthController.text.trim()) ?? 200;
    final duration = int.tryParse(_durationController.text.trim()) ?? 600;

    final item = QrHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: text,
      segmentLength: segmentLength,
      duration: duration,
      createdAt: DateTime.now(),
    );
    await QrStorage.instance.saveToHistory(item);
    _refreshSidebar();
  }

  void _refreshSidebar() {
    setState(() {
      _historyItems = QrStorage.instance.getHistory();
      _favoriteItems = QrStorage.instance.getFavorites();
    });
  }

  void _performAnimation({required int duration}) {
    _timer?.cancel();
    _index = 0;
    _timer = Timer.periodic(Duration(milliseconds: duration), (timer) {
      setState(() {
        _index = (_index + 1) % _data.segments.length;
      });
    });
  }

  void _loadHistoryItem(QrHistoryItem item) {
    _dataController.removeListener(_onDataChanged);
    _durationController.removeListener(_onDataChanged);
    _segmentLengthController.removeListener(_onDataChanged);

    _dataController.text = item.data;
    _durationController.text = item.duration.toString();
    _segmentLengthController.text = item.segmentLength.toString();

    _dataController.addListener(_onDataChanged);
    _durationController.addListener(_onDataChanged);
    _segmentLengthController.addListener(_onDataChanged);

    _onDataChanged();
  }

  Future<void> _toggleFavorite(QrHistoryItem item) async {
    await QrStorage.instance.toggleFavorite(item.id);
    _refreshSidebar();
  }

  Future<void> _deleteItem(QrHistoryItem item) async {
    await QrStorage.instance.deleteItem(item.id);
    _refreshSidebar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveDebounce?.cancel();
    _dataController.removeListener(_onDataChanged);
    _durationController.removeListener(_onDataChanged);
    _segmentLengthController.removeListener(_onDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Generator'),
        centerTitle: true,
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: _buildGenerator()),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _buildSidebar()),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: _buildGenerator()),
                const Divider(height: 1),
                Expanded(flex: 2, child: _buildSidebar()),
              ],
            ),
    );
  }

  Widget _buildGenerator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data:
                    '${_index + 1}/${_data.segments.length}|${_data.segments[_index]}',
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_index + 1}/${_data.segments.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 400,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration(ms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _segmentLengthController,
                      decoration: const InputDecoration(
                        labelText: 'Segment Length',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minHeight: 0,
              ),
              child: TextField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                ),
                maxLines: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final items = _sidebarTab == 0 ? _historyItems : _favoriteItems;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: 'History',
                  icon: Icons.history,
                  isSelected: _sidebarTab == 0,
                  onTap: () => setState(() => _sidebarTab = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabButton(
                  label: 'Favorites',
                  icon: Icons.star,
                  isSelected: _sidebarTab == 1,
                  onTap: () => setState(() => _sidebarTab = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sidebarTab == 0
                            ? Icons.history_toggle_off
                            : Icons.star_border,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sidebarTab == 0 ? 'No history yet' : 'No favorites',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _HistoryCard(
                      item: item,
                      onTap: () => _loadHistoryItem(item),
                      onToggleFavorite: () => _toggleFavorite(item),
                      onDelete: () => _deleteItem(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final QrHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.duration}ms · ${item.segmentLength} chars',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.star : Icons.star_border,
                  color: item.isFavorite
                      ? Colors.amber
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: onToggleFavorite,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: item.isFavorite ? 'Unfavorite' : 'Favorite',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: onDelete,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
