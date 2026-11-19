import 'dart:io';
import 'dart:async';
import '../cloud_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/draft_repository.dart';
import '../services/device_location_service.dart';
import '../services/photo_upload_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/upload_queue_repository.dart';

class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final TextEditingController _nameController =
  TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final DraftRepository _draftRepository = DraftRepository();
  final DeviceLocationService _locationService =
  DeviceLocationService();

  String? _photoPath;
  double? _latitude;
  double? _longitude;
  LocationFailureType? _locationError;

  bool _isLoading = false;

  final PhotoUploadService _photoUploadService =
  PhotoUploadService();

  bool _isUploading = false;
  String? _uploadedPhotoUrl;

  final UploadQueueRepository _uploadQueueRepository =
  UploadQueueRepository();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _restoreLocalDraft();
    _startConnectivityListener();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }


  Future<void> _processUploadQueue() async {
    if (!_isOnline || !CloudConfig.enabled || _isUploading) {
      return;
    }

    final pendingPhotos =
    await _uploadQueueRepository.getPendingUploads();

    for (final photoPath in pendingPhotos) {
      if (!mounted || !_isOnline) return;

      final photo = File(photoPath);

      if (!await photo.exists()) {
        await _uploadQueueRepository.removeFromQueue(photoPath);
        continue;
      }

      setState(() {
        _isUploading = true;
      });

      try {
        await _photoUploadService.upload(photo);

        await _uploadQueueRepository.removeFromQueue(photoPath);

        _showMessage('Foto antrean berhasil diunggah!');
      } catch (e) {
        _showMessage('Upload antrean gagal: $e');
        break;
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }


  Future<void> _startConnectivityListener() async {
    final initialStatus = await _connectivity.checkConnectivity();

    if (!mounted) return;

    setState(() {
      _isOnline =
      !initialStatus.contains(ConnectivityResult.none);
    });

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
          if (!mounted) return;

          final connected =
          !results.contains(ConnectivityResult.none);

          setState(() {
            _isOnline = connected;
          });

          if (connected) {
            _showMessage('Koneksi terdeteksi. Memeriksa antrean upload...');
            _processUploadQueue();
          }
        });
  }

  // Memulihkan draft ketika halaman dibuka.
  Future<void> _restoreLocalDraft() async {
    try {
      final draft = await _draftRepository.loadDraft();

      if (draft == null || !mounted) return;

      final savedPhoto = draft['photoPath'] as String?;

      setState(() {
        _nameController.text = draft['name'] ?? '';
        _photoPath = savedPhoto;
        _latitude = (draft['latitude'] as num?)?.toDouble();
        _longitude = (draft['longitude'] as num?)?.toDouble();
      });

      if (savedPhoto != null &&
          !await File(savedPhoto).exists() &&
          mounted) {
        setState(() {
          _photoPath = null;
        });
      }
    } catch (e) {
      _showMessage('Gagal memulihkan draft: $e');
    }
    await _recoverInterruptedPicker();
  }

  // Menampilkan pesan kepada pengguna.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  Future<void> _uploadPhoto() async {
    if (!_isOnline) {
      await _uploadQueueRepository.addToQueue(_photoPath!);
      _showMessage(
        'Tidak ada koneksi internet. Foto masuk antrean upload.',
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await _photoUploadService.upload(
        File(_photoPath!),
      );

      setState(() {
        _uploadedPhotoUrl = result.publicUrl;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil diunggah ke Supabase!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload gagal: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Memilih foto dari kamera atau galeri.
  Future<void> _choosePhoto(ImageSource source) async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (selected == null) {
        _showMessage('Pemilihan foto dibatalkan.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final permanentPath =
      await _draftRepository.savePermanentPhoto(selected);

      if (!mounted) return;

      setState(() {
        _photoPath = permanentPath;
      });

      await _saveDraft();

      _showMessage('Foto berhasil disimpan.');
    } catch (e) {
      _showMessage('Gagal mengambil foto: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recoverInterruptedPicker() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final lostData = await _picker.retrieveLostData();

      if (lostData.isEmpty) return;

      if (lostData.files != null && lostData.files!.isNotEmpty) {
        final pickedFile = lostData.files!.first;

        final permanentPath =
        await _draftRepository.savePermanentPhoto(pickedFile);

        if (!mounted) return;

        setState(() {
          _photoPath = permanentPath;
        });

        await _saveDraft();

        _showMessage('Foto yang sebelumnya terputus berhasil dipulihkan.');
      } else if (lostData.exception != null) {
        _showMessage('Pemulihan foto gagal: ${lostData.exception}');
      }
    } catch (e) {
      _showMessage('Terjadi kesalahan saat memulihkan foto: $e');
    }
  }

  // Mengambil koordinat GPS.
  Future<void> _getLocation() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      final Position position =
      await _locationService.getPosition();

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _saveDraft();

      _showMessage('Koordinat lokasi berhasil diperoleh.');
    } on LocationFailure catch (e) {
      if (!mounted) return;

      setState(() {
        _locationError = e.type;
      });

      _showMessage(e.message);
    } on TimeoutException {
      _showMessage(
        'Waktu mencari GPS habis. Coba di area terbuka.',
      );
    } catch (e) {
      _showMessage('Gagal mengambil lokasi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Menyimpan seluruh informasi draft.
  Future<void> _saveDraft() async {
    final draft = {
      'name': _nameController.text.trim(),
      'photoPath': _photoPath,
      'latitude': _latitude,
      'longitude': _longitude,
    };

    await _draftRepository.saveDraft(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder Device Demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                CloudConfig.enabled
                    ? 'Mode: Online'
                    : 'Mode: Lokal/Offline',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Kos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kos',
                hintText: 'Masukkan nama kos',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              onChanged: (_) => _saveDraft(),
            ),

            const SizedBox(height: 24),

            const Text(
              'Foto Kamar Kos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (_photoPath != null &&
                File(_photoPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photoPath!),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 55, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Belum ada foto'),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _choosePhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _choosePhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Lokasi Kos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getLocation,
              icon: const Icon(Icons.location_on),
              label: const Text('Ambil Koordinat GPS'),
            ),

            const SizedBox(height: 12),
            if (_locationError ==
                LocationFailureType.serviceDisabled)
              TextButton.icon(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Buka Pengaturan Lokasi'),
              ),

            if (_locationError ==
                LocationFailureType.deniedForever)
              TextButton.icon(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Buka Pengaturan Izin Aplikasi'),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitude: ${_latitude?.toStringAsFixed(6) ?? '-'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Longitude: ${_longitude?.toStringAsFixed(6) ?? '-'}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                try {
                  await _saveDraft();
                  _showMessage('Draft berhasil disimpan secara lokal.');
                } catch (e) {
                  _showMessage('Gagal menyimpan draft: $e');
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Simpan Draft Lokal'),

            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: (_isUploading || _photoPath == null)
                  ? null
                  : _uploadPhoto,
              icon: _isUploading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _isUploading
                    ? 'Sedang Mengunggah...'
                    : 'Upload Foto ke Supabase',
              ),
            ),

            if (_uploadedPhotoUrl != null) ...[
              const SizedBox(height: 12),
              const Text(
                'URL Foto Supabase:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(_uploadedPhotoUrl!),
            ],


            if (CloudConfig.enabled) ...[
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: (_isUploading || _photoPath == null)
                    ? null
                    : _uploadPhoto,
                icon: _isUploading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _isUploading
                      ? 'Sedang Mengunggah...'
                      : 'Upload Foto ke Supabase',
                ),
              ),

              if (_uploadedPhotoUrl != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'URL Foto Supabase:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SelectableText(_uploadedPhotoUrl!),
              ],
            ],


            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
