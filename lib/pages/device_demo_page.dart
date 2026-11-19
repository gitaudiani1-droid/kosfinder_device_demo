import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/draft_repository.dart';
import '../services/device_location_service.dart';
import 'sensor_demo_page.dart';

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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _restoreLocalDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
  }

  // Menampilkan pesan kepada pengguna.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  // Mengambil koordinat GPS.
  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
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
      _showMessage(e.message);
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
          IconButton(
            icon: const Icon(Icons.sensors),
            tooltip: 'Accelerometer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SensorDemoPage(),
                ),
              );
            },
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
