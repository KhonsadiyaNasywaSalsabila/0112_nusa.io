import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../models/location_model.dart';
import '../blocs/bookmark/bookmark_interaction_bloc.dart';
import '../services/database_helper.dart';

/// Helper untuk mendapatkan posisi GPS saat ini secara aman.
/// Menggunakan lastKnownPosition (instan di emulator) lalu stream sebagai fallback.
Future<Position?> _getSafePosition() async {
  // Lapis 1: lastKnownPosition – instan, cocok untuk mock location emulator
  try {
    final last = await Geolocator.getLastKnownPosition()
        .timeout(const Duration(seconds: 2));
    if (last != null) {
      debugPrint('[LocationVerifier] lastKnown: ${last.latitude}, ${last.longitude}');
      return last;
    }
  } catch (_) {}

  // Lapis 2: stream – ambil posisi pertama, timeout 8 detik
  try {
    final pos = await Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 0,
      ),
    ).timeout(const Duration(seconds: 8)).first;
    debugPrint('[LocationVerifier] stream: ${pos.latitude}, ${pos.longitude}');
    return pos;
  } catch (e) {
    debugPrint('[LocationVerifier] stream gagal: $e');
  }

  return null;
}

class LocationVerifier {
  // --- Rumus Haversine ---
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // Radius bumi dalam meter
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // Hasil dalam meter
  }

  /// Verifikasi posisi terhadap satu lokasi target (LocationModel).
  /// Digunakan saat klik "Tulis Jurnal" di PlaceHub.
  /// Mengembalikan Position jika di dalam geofence, null jika tidak.
  static Future<Position?> verifyAndGetPosition(
    BuildContext context,
    LocationModel targetLocation,
  ) async {
    // 1. Cek izin GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) _showGpsError(context, 'GPS mati. Nyalakan GPS untuk menulis jurnal.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (context.mounted) _showGpsError(context, 'Izin GPS ditolak. Aktifkan di pengaturan.');
      return null;
    }

    // 2. Tampilkan indikator loading ringan
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Memeriksa lokasi kamu...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
    }

    try {
      // 3. Ambil posisi secara aman (tidak freeze emulator)
      final position = await _getSafePosition();

      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (position == null) {
        _showGpsError(context, 'Tidak dapat mendeteksi posisi GPS. Pastikan GPS aktif dan coba lagi.');
        return null;
      }

      debugPrint('[LocationVerifier] Target: ${targetLocation.latitude}, ${targetLocation.longitude}');
      debugPrint('[LocationVerifier] Posisi user: ${position.latitude}, ${position.longitude}');

      // 4. Hitung Haversine
      final dist = _haversineDistance(
        position.latitude, position.longitude,
        targetLocation.latitude, targetLocation.longitude,
      );

      double radius = targetLocation.geofenceRadius;
      if (radius <= 0) radius = 100.0; // Fallback 100m jika admin belum mengisi

      debugPrint('[LocationVerifier] Jarak: ${dist.toStringAsFixed(1)}m, Radius: ${radius.toStringAsFixed(1)}m');

      if (dist <= radius) {
        // ✅ Di dalam geofence
        return position;
      } else {
        // ❌ Di luar geofence - tampilkan dialog ramah
        if (context.mounted) _showLocationMismatchFriendly(context, targetLocation);
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showGpsError(context, 'Gagal mendapatkan lokasi: ${e.toString()}');
      }
      return null;
    }
  }

  /// Verifikasi posisi terhadap semua lokasi di cache.
  /// Digunakan di MapExploreScreen ketika user belum memilih lokasi spesifik.
  static Future<Map<String, dynamic>?> verifyAndGetPositionAny(BuildContext context) async {
    // 1. Cek izin GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) _showGpsError(context, 'GPS mati. Nyalakan GPS untuk menulis jurnal.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (context.mounted) _showGpsError(context, 'Izin GPS ditolak. Aktifkan di pengaturan.');
      return null;
    }

    // 2. Tampilkan indikator loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Memeriksa lokasi kamu...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
    }

    try {
      // 3. Ambil posisi secara aman
      final position = await _getSafePosition();

      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (position == null) {
        _showGpsError(context, 'Tidak dapat mendeteksi posisi GPS. Pastikan GPS aktif dan coba lagi.');
        return null;
      }

      // 4. Cocokkan dengan semua lokasi di cache
      final cachedLocations = await DatabaseHelper.instance.getLocationsCache();
      Map<String, dynamic>? matchedLoc;
      double nearestDistance = double.infinity;
      Map<String, dynamic>? nearestLoc;

      for (var loc in cachedLocations) {
        final dist = _haversineDistance(
          position.latitude, position.longitude,
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        );
        if (dist < nearestDistance) {
          nearestDistance = dist;
          nearestLoc = loc;
        }
        double radius = (loc['geofenceRadius'] as num?)?.toDouble() ?? 100.0;
        if (radius <= 0) radius = 100.0;
        if (dist <= radius) {
          matchedLoc = loc;
          break;
        }
      }

      if (!context.mounted) return null;

      if (matchedLoc != null) {
        return {
          'position': position,
          'locationId': matchedLoc['id'].toString(),
        };
      } else {
        final distStr = nearestDistance == double.infinity
            ? 'tidak diketahui'
            : nearestDistance < 1000
                ? '${nearestDistance.toStringAsFixed(0)} m'
                : '${(nearestDistance / 1000).toStringAsFixed(1)} km';
        _showOutOfGeofence(
          context,
          nearestName: nearestLoc?['name'] as String? ?? '-',
          distance: distStr,
        );
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showGpsError(context, 'Gagal mendapatkan lokasi: ${e.toString()}');
      }
      return null;
    }
  }

  // --- Dialog GPS Error ---
  static void _showGpsError(BuildContext context, String message) {
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('GPS Tidak Tersedia', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog Mismatch Friendly (lokasi tidak cocok) ---
  static void _showLocationMismatchFriendly(BuildContext context, LocationModel targetLocation) {
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            const Text('Belum Sampai Tujuan?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Sepertinya kamu belum berada di area ${targetLocation.name}.\n\nIngin menyimpan ke Rencana Jelajah agar kamu tidak lupa?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      // Simpan ke Rencana Jelajah
                      context.read<BookmarkInteractionBloc>().add(BookmarkLocationRequested(targetLocation.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${targetLocation.name} disimpan ke Rencana Jelajah!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Arahkan ke halaman Rencana Jelajah
                      context.go('/bookmarks');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Rencanakan Jelajah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog Out of Geofence (Generic) ---
  static void _showOutOfGeofence(BuildContext context, {required String nearestName, required String distance}) {
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pin_drop_outlined, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Di Luar Jangkauan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Kamu terlalu jauh dari lokasi terdaftar manapun.\n(Lokasi terdekat: $nearestName, jarak: $distance)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
