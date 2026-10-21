import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Every corrected dictation, newest first, saved on the device.
class History extends ChangeNotifier {
  static const _key = 'history';
  SharedPreferences? _store;
  final List<DictationRecord> records = [];

  Future<void> load() async {
    _store = await SharedPreferences.getInstance();
    final raw = _store!.getString(_key);
    if (raw == null) return;
    try {
      records
        ..clear()
        ..addAll([
          for (final j in jsonDecode(raw) as List) DictationRecord.fromJson(j as Map<String, dynamic>)
        ]);
    } catch (_) {
      // A damaged history should not stop the app from opening.
    }
  }

  Future<void> add(DictationRecord r) async {
    records.insert(0, r);
    await save();
  }

  Future<void> remove(DictationRecord r) async {
    records.remove(r);
    await save();
  }

  /// Call after changing a record in place (e.g. marking a word as correct).
  Future<void> save() async {
    notifyListeners();
    await _store?.setString(_key, jsonEncode([for (final r in records) r.toJson()]));
  }
}
