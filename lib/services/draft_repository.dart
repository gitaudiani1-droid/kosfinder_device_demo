import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftRepository {
  static const String _draftKey = 'kosfinder_device_demo_draft_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  // Menyimpan foto secara permanen di penyimpanan internal aplikasi.
  Future<String> savePermanentPhoto(XFile selected) async {
    final extension = selected.path.split('.').last.toLowerCase();

    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      throw Exception('Format foto harus JPG, JPEG, atau PNG.');
    }

    final sourceFile = File(selected.path);

    if (!await sourceFile.exists()) {
      throw Exception('File foto tidak ditemukan.');
    }

    final fileSize = await sourceFile.length();

    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Ukuran foto maksimal 5 MB.');
    }

    final appDirectory = await getApplicationDocumentsDirectory();

    final photoDirectory = Directory(
      '${appDirectory.path}/kosfinder_photos',
    );

    if (!await photoDirectory.exists()) {
      await photoDirectory.create(recursive: true);
    }

    final fileName =
        'kos_${DateTime.now().microsecondsSinceEpoch}.$extension';

    final destinationPath = '${photoDirectory.path}/$fileName';

    final savedFile = await sourceFile.copy(destinationPath);

    return savedFile.path;
  }

  // Menyimpan informasi draft dalam bentuk JSON.
  Future<void> saveDraft(Map<String, dynamic> data) async {
    final jsonData = jsonEncode(data);
    await _preferences.setString(_draftKey, jsonData);
  }

  // Mengambil draft yang sebelumnya tersimpan.
  Future<Map<String, dynamic>?> loadDraft() async {
    final jsonData = await _preferences.getString(_draftKey);

    if (jsonData == null) {
      return null;
    }

    final decodedData = jsonDecode(jsonData);

    if (decodedData is Map<String, dynamic>) {
      return decodedData;
    }

    return null;
  }

  // Menghapus data draft.
  Future<void> clearDraft() async {
    await _preferences.remove(_draftKey);
  }
}
