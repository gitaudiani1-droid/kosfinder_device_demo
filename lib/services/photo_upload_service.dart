
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';

class PhotoUploadResult {
  const PhotoUploadResult(this.storagePath, this.publicUrl);

  final String storagePath;
  final String publicUrl;
}

class PhotoUploadService {
  Future<PhotoUploadResult> upload(File photo) async {
    if (!CloudConfig.enabled) {
      throw StateError(
        'Supabase belum dikonfigurasi. '
            'Gunakan Simpan Draft Lokal atau aktifkan konfigurasi cloud.',
      );
    }

    final client = Supabase.instance.client;

    // Membuat sesi anonymous jika belum ada.
    if (client.auth.currentUser == null) {
      await client.auth.signInAnonymously();
    }

    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError(
        'Sesi anonymous Supabase tidak berhasil dibuat.',
      );
    }

    final extension = photo.path.split('.').last.toLowerCase();

    if (!{'jpg', 'jpeg', 'png'}.contains(extension)) {
      throw const FormatException(
        'Format foto harus JPG, JPEG, atau PNG.',
      );
    }

    if (await photo.length() > 5 * 1024 * 1024) {
      throw const FormatException(
        'Ukuran foto maksimal 5 MB.',
      );
    }

    // File disimpan pada folder sesuai UID pengguna.
    final objectPath =
        '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    final returnedPath = await client.storage
        .from('kosfinder-demo')
        .upload(
      objectPath,
      photo,
      fileOptions: FileOptions(
        upsert: false,
        contentType:
        extension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );

    final publicUrl = client.storage
        .from('kosfinder-demo')
        .getPublicUrl(returnedPath);

    return PhotoUploadResult(returnedPath, publicUrl);
  }
}
