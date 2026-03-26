import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kHistoryKey = 'qr_history';

class QrHistoryItem {
  QrHistoryItem({
    required this.id,
    required this.data,
    required this.segmentLength,
    required this.duration,
    required this.createdAt,
    this.isFavorite = false,
  });

  factory QrHistoryItem.fromJson(Map<String, dynamic> json) {
    return QrHistoryItem(
      id: json['id'] as String,
      data: json['data'] as String,
      segmentLength: json['segmentLength'] as int,
      duration: json['duration'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  final String id;
  final String data;
  final int segmentLength;
  final int duration;
  final DateTime createdAt;
  bool isFavorite;

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'segmentLength': segmentLength,
        'duration': duration,
        'createdAt': createdAt.toIso8601String(),
        'isFavorite': isFavorite,
      };

  String get preview => data.length > 50 ? '${data.substring(0, 50)}...' : data;
}

class QrStorage {
  QrStorage._();

  static QrStorage? _instance;
  static QrStorage get instance => _instance ??= QrStorage._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  List<QrHistoryItem> getHistory() {
    final raw = _prefs?.getStringList(_kHistoryKey) ?? [];
    return raw
        .map((e) =>
            QrHistoryItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<QrHistoryItem> getFavorites() {
    return getHistory().where((e) => e.isFavorite).toList();
  }

  Future<void> saveToHistory(QrHistoryItem item) async {
    final history = getHistory();
    // deduplicate by data content, but preserve favorite status
    final wasFavorite =
        history.where((e) => e.data == item.data).any((e) => e.isFavorite);
    history.removeWhere((e) => e.data == item.data);
    if (wasFavorite) item.isFavorite = true;
    history.insert(0, item);
    // trim non-favorite items to keep max 200
    final nonFavorites = history.where((e) => !e.isFavorite).toList();
    if (nonFavorites.length > 200) {
      final toRemove = nonFavorites.sublist(200).toSet();
      history.removeWhere(toRemove.contains);
    }
    await _saveAll(history);
  }

  Future<void> toggleFavorite(String id) async {
    final history = getHistory();
    final index = history.indexWhere((e) => e.id == id);
    if (index != -1) {
      history[index].isFavorite = !history[index].isFavorite;
      await _saveAll(history);
    }
  }

  Future<void> deleteItem(String id) async {
    final history = getHistory();
    history.removeWhere((e) => e.id == id);
    await _saveAll(history);
  }

  Future<void> _saveAll(List<QrHistoryItem> history) async {
    final encoded = history.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs?.setStringList(_kHistoryKey, encoded);
  }
}
