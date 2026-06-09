import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _key = 'device_id';
const _uuid = Uuid();

final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_key);
  if (id == null) {
    id = _uuid.v4();
    await prefs.setString(_key, id);
  }
  return id;
});
