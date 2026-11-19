
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UploadQueueRepository {
  static const String _queueKey = 'kosfinder_upload_queue_v1';

  final SharedPreferencesAsync _preferences =
  SharedPreferencesAsync();

  // Mengambil seluruh antrean upload.
  Future<List<String>> getPendingUploads() async {
    final data = await _preferences.getString(_queueKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(data) as List;
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  // Menambahkan foto ke antrean.
  Future<void> addToQueue(String photoPath) async {
    final queue = await getPendingUploads();

    if (!queue.contains(photoPath)) {
      queue.add(photoPath);
      await _saveQueue(queue);
    }
  }

  // Menghapus foto setelah berhasil diunggah.
  Future<void> removeFromQueue(String photoPath) async {
    final queue = await getPendingUploads();

    queue.remove(photoPath);
    await _saveQueue(queue);
  }

  // Menyimpan antrean secara lokal.
  Future<void> _saveQueue(List<String> queue) async {
    await _preferences.setString(
      _queueKey,
      jsonEncode(queue),
    );
  }
}
