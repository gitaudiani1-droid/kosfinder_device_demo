import 'package:geolocator/geolocator.dart';

enum LocationFailureType {
  serviceDisabled,
  denied,
  deniedForever,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type, this.message);

  final LocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

class DeviceLocationService {
  Future<Position> getPosition() async {
    // 1. Periksa apakah layanan lokasi perangkat aktif.
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureType.serviceDisabled,
        'GPS/lokasi perangkat tidak aktif. Nyalakan melalui Settings.',
      );
    }

    // 2. Periksa izin lokasi.
    var permission = await Geolocator.checkPermission();

    // 3. Minta izin jika belum diberikan.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 4. Jika izin ditolak.
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureType.denied,
        'Izin lokasi ditolak. Foto dan draft tetap dapat digunakan.',
      );
    }

    // 5. Jika izin ditolak secara permanen.
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureType.deniedForever,
        'Izin lokasi ditolak permanen. Ubah di Settings aplikasi.',
      );
    }

    // 6. Ambil koordinat lokasi perangkat.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}
