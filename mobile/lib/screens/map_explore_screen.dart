import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../widgets/glass_card.dart';
import '../services/database_helper.dart';
import '../services/api_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../models/location_model.dart';
import '../models/journal_model.dart';
import '../utils/constants.dart';
import '../blocs/bookmark/bookmark_interaction_bloc.dart';
import '../utils/guest_dialog.dart';
import '../utils/location_verifier.dart';
import 'journal_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:ui';

class MapExploreScreen extends StatefulWidget {
  final double? targetLat;
  final double? targetLng;
  final String? targetLocationId;

  const MapExploreScreen({
    Key? key,
    this.targetLat,
    this.targetLng,
    this.targetLocationId,
  }) : super(key: key);

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  GoogleMapController? _mapController;
  final PageController _pageController = PageController(viewportFraction: 0.65);

  late CameraPosition _initialPosition;

  // Daftar tema untuk filter
  final List<String> _themes = ['Semua', ...AppConstants.themeTags];
  String _selectedTheme = 'Semua';

  List<LocationModel> _allLocations = [];
  bool _isLoading = true;
  int _currentCarouselIndex = 0;
  String? _myAvatarUrl;
  String _searchQuery = '';

  bool get _isFilterActive => _selectedTheme != 'Semua' || _searchQuery.isNotEmpty;
  LocationModel? _selectedLocation;
  CameraPosition? _currentCameraPosition;

  List<LocationModel> get _filteredLocations {
    List<LocationModel> result = _allLocations;

    if (_selectedTheme != 'Semua') {
      result = result.where((loc) => loc.availableThemes.contains(_selectedTheme)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((loc) => loc.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return result;
  }

  int _getDisplayCount(LocationModel loc) {
    if (_selectedTheme == 'Semua') return loc.journals.length;
    return loc.journals.where((j) => j.themeTag == _selectedTheme).length;
  }

  @override
  void initState() {
    super.initState();
    // Gunakan target dari route jika ada, jika tidak default ke Tugu Jogja
    _initialPosition = CameraPosition(
      target: LatLng(widget.targetLat ?? -7.7829, widget.targetLng ?? 110.3671),
      zoom: widget.targetLat != null ? 18.0 : 13.0,
    );
    _fetchMapData();
    _fetchMyProfile();
  }

  @override
  void didUpdateWidget(MapExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle jika user diarahkan kembali ke Map saat widget sudah ter-mount
    if (widget.targetLocationId != oldWidget.targetLocationId && widget.targetLocationId != null) {
      if (!_isLoading && _allLocations.isNotEmpty) {
        _handleTargetLocation(widget.targetLocationId!, widget.targetLat, widget.targetLng);
      }
    }
  }

  void _handleTargetLocation(String locationId, double? lat, double? lng) {
    try {
      final loc = _allLocations.firstWhere((l) => l.id == locationId);
      setState(() {
        _selectedLocation = loc;
      });

      int index = _filteredLocations.indexWhere((l) => l.id == locationId);
      if (index != -1) {
        setState(() {
          _currentCarouselIndex = index;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      }

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(lat ?? loc.latitude, lng ?? loc.longitude), 
            18.0
          )
        );
      }
    } catch (e) {
      // Abaikan jika tidak ketemu
    }
  }

  Future<void> _fetchMyProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      try {
        final res = await ApiClient.instance.get('/auth/me');
        if (res.data['success']) {
          if (mounted) {
            setState(() {
              _myAvatarUrl = res.data['data']['avatarUrl'] ?? res.data['data']['profilePhotoUrl'];
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
      }
    }
  }

  Future<void> _fetchMapData() async {
    try {
      final response = await ApiClient.instance.get('/map');

      if (response.data['success']) {
        setState(() {
          final List<dynamic> data = response.data['data'];
          _allLocations = data
              .map(
                (json) => LocationModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
          _isLoading = false;

          // Jika ada targetLocationId, buka kartunya otomatis
          if (widget.targetLocationId != null) {
            _handleTargetLocation(widget.targetLocationId!, widget.targetLat, widget.targetLng);
          }
        });
        // Cache data for offline usage
        await DatabaseHelper.instance.cacheLocations(_allLocations);
      }
    } catch (e) {
      debugPrint("Error fetching map data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onPinTapped(String locationId, double lat, double lng) {
    // Fly to
    _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));

    if (_isFilterActive) {
      // Sinkronkan Carousel: Cari lokasi ini
      int index = _filteredLocations.indexWhere((loc) => loc.id == locationId);
      if (index != -1 && _pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Tampilkan Single Card Popup
      setState(() {
        _selectedLocation = _allLocations.firstWhere((loc) => loc.id == locationId);
      });
    }
  }

  void _onCarouselPageChanged(int index) {
    setState(() {
      _currentCarouselIndex = index;
    });
    // Fly to location of this journal
    if (index >= 0 && index < _filteredLocations.length) {
      final loc = _filteredLocations[index];
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
      );
    }
  }

  // Membuat marker dengan "Glow" berdasarkan journalCount
  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};
    for (var loc in _filteredLocations) {
      final marker = Marker(
        markerId: MarkerId(loc.id.toString()),
        position: LatLng(loc.latitude, loc.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          loc.isBookmarked
              ? BitmapDescriptor.hueYellow
              : BitmapDescriptor.hueGreen,
        ),
        onTap: () => _onPinTapped(loc.id, loc.latitude, loc.longitude),
      );
      markers.add(marker);
    }
    return markers;
  }

  // --- FUNGSI SATPAM SANTAI (Tamu menabrak dinding) ---
  Future<void> _handleRestrictedAction(String featureName, String route) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthGuestMode) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Daftar dulu yuk!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Untuk menggunakan fitur $featureName, kamu perlu memiliki akun.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup bottom sheet
                    context.go('/login'); // Ke halaman login
                  },
                  child: const Text(
                    'Daftar / Masuk',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      await context.push(route);
      if (route == '/zen-editor') {
        _fetchMapData(); // Refresh Map after publishing
      }
    }
  }

  // =====================================================================
  // HELPER: Rumus Haversine (jarak dalam meter)
  // =====================================================================
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);

    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // =====================================================================
  // HELPER: Tampilkan Semua Pin di Peta
  // =====================================================================
  void _showAllPins() {
    if (_filteredLocations.isEmpty || _mapController == null) return;

    if (_filteredLocations.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_filteredLocations.first.latitude, _filteredLocations.first.longitude),
            zoom: 14.0,
          ),
        ),
      );
      return;
    }

    double minLat = _filteredLocations.first.latitude;
    double maxLat = _filteredLocations.first.latitude;
    double minLng = _filteredLocations.first.longitude;
    double maxLng = _filteredLocations.first.longitude;

    for (var loc in _filteredLocations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ),
    );
  }

  // =====================================================================
  // FUNGSI UTAMA: Validasi Geofence sebelum buka Zen Editor
  // =====================================================================
  Future<void> _handleWriteJournal(LocationModel? targetLocation) async {
    final authState = context.read<AuthBloc>().state;
    // Cek login
    if (authState is! AuthAuthenticated) {
      _handleRestrictedAction('Menulis Jurnal', '/zen-editor');
      return;
    }

    if (targetLocation != null) {
      final position = await LocationVerifier.verifyAndGetPosition(context, targetLocation);
      if (position != null) {
        await context.push('/zen-editor', extra: {
          'locationId': targetLocation.id,
          'latitudeCaptured': position.latitude,
          'longitudeCaptured': position.longitude,
          'isMocked': position.isMocked ? 1 : 0,
        });
        _fetchMapData();
      }
    } else {
      final result = await LocationVerifier.verifyAndGetPositionAny(context);
      if (result != null) {
        final position = result['position'] as Position;
        final locationId = result['locationId'] as String;
        await context.push('/zen-editor', extra: {
          'locationId': locationId,
          'latitudeCaptured': position.latitude,
          'longitudeCaptured': position.longitude,
          'isMocked': position.isMocked ? 1 : 0,
        });
        _fetchMapData();
      }
    }
  }

  // =====================================================================
  // HELPER: Menampilkan drawer modern sebagai bottom sheet
  // =====================================================================
  void _showModernMenu(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final bool isGuest = authState is AuthGuestMode;
    final String username = isGuest
        ? 'Penjelajah Tamu'
        : (authState is AuthAuthenticated ? 'Wisatawan' : 'Wisatawan');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1F12), Color(0xFF1A3A20)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // === HEADER PROFIL ===
              Row(
                children: [
                  // Avatar dengan ring gradient
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF00E676)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF1A3A20),
                      backgroundImage: _myAvatarUrl != null && _myAvatarUrl!.isNotEmpty
                          ? NetworkImage(_myAvatarUrl!.startsWith('http') 
                              ? _myAvatarUrl! 
                              : 'http://10.0.2.2:3000${_myAvatarUrl!.startsWith('/') ? '' : '/'}$_myAvatarUrl')
                          : null,
                      child: _myAvatarUrl == null || _myAvatarUrl!.isEmpty
                          ? Icon(
                              isGuest ? Icons.person_outline : Icons.person,
                              size: 30,
                              color: const Color(0xFF4CAF50),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                        ),
                        child: Text(
                          isGuest ? '✦ Mode Tamu' : '✦ Jelajah Memori',
                          style: const TextStyle(
                            color: Color(0xFF66BB6A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // === MENU ITEMS ===
              _buildMenuRow(
                icon: Icons.person_pin_circle_rounded,
                label: 'Profil & Paspor',
                subtitle: 'Jejak & stempel perjalananmu',
                onTap: () async {
                  if (isGuest) {
                    Navigator.pop(ctx);
                    GuestDialog.show(context, 'Profil');
                  } else {
                    Navigator.pop(ctx);
                    await context.push('/profile');
                    _fetchMyProfile();
                  }
                },
                isRestricted: isGuest,
              ),
              const SizedBox(height: 16),
              
              _buildMenuRow(
                icon: Icons.map_rounded,
                label: 'Rencana Jelajah',
                subtitle: 'Daftar tempat impianmu',
                color: Colors.blue,
                onTap: () {
                  if (isGuest) {
                    Navigator.pop(ctx);
                    GuestDialog.show(context, 'Rencana Jelajah');
                  } else {
                    Navigator.pop(ctx);
                    context.push('/bookmarks');
                  }
                },
                isRestricted: isGuest,
              ),
              const SizedBox(height: 16),

              _buildMenuRow(
                icon: Icons.collections_bookmark_rounded,
                label: 'Koleksi Inspirasi',
                subtitle: 'Jurnal yang kamu simpan',
                color: Colors.orange,
                onTap: () {
                  if (isGuest) {
                    Navigator.pop(ctx);
                    GuestDialog.show(context, 'Koleksi Inspirasi');
                  } else {
                    Navigator.pop(ctx);
                    context.push('/saved-journals');
                  }
                },
                isRestricted: isGuest,
              ),
              const SizedBox(height: 16),

              _buildMenuRow(
                icon: Icons.edit_document,
                label: 'Draf Saya',
                subtitle: 'Jurnal yang belum dipublikasikan',
                color: Colors.purple,
                onTap: () {
                  if (isGuest) {
                    Navigator.pop(ctx);
                    GuestDialog.show(context, 'Draf Saya');
                  } else {
                    Navigator.pop(ctx);
                    context.push('/my-drafts');
                  }
                },
                isRestricted: isGuest,
              ),
              const SizedBox(height: 28),

              // === DIVIDER ===
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              const SizedBox(height: 20),

              // === TOMBOL KELUAR ===
              GestureDetector(
                onTap: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                  Navigator.pop(ctx);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Keluar',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red.withOpacity(0.5)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === HELPER: Satu item menu bergaya modern ===
  Widget _buildMenuRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color color = const Color(0xFF4CAF50),
    bool isRestricted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isRestricted 
                      ? [Colors.grey.shade700, Colors.grey.shade800]
                      : [color, color.withOpacity(0.7)]
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isRestricted ? Colors.white54 : Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: isRestricted ? Colors.white70 : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            if (isRestricted)
              const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white30)
            else
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // HELPER: Auto-Targeting & Edge Indicators
  // =====================================================================
  double _calculateAngle(LatLng center, LatLng target) {
    double dy = target.latitude - center.latitude;
    double dx = target.longitude - center.longitude;
    return math.atan2(dy, dx);
  }

  Widget _buildEdgeIndicators() {
    if (_isFilterActive || _selectedLocation == null || _currentCameraPosition == null) return const SizedBox.shrink();

    // Hitung jarak (kasar) dari tengah layar
    double latDiff = (_selectedLocation!.latitude - _currentCameraPosition!.target.latitude).abs();
    double lngDiff = (_selectedLocation!.longitude - _currentCameraPosition!.target.longitude).abs();

    // Perkiraan threshold apakah point ada di luar layar (tergantung zoom)
    double threshold = 0.01 * math.pow(2, 13 - _currentCameraPosition!.zoom);

    if (latDiff < threshold && lngDiff < threshold) return const SizedBox.shrink();

    // Point ada di luar layar -> Tampilkan indikator arah di pinggir layar
    double angle = _calculateAngle(
      _currentCameraPosition!.target,
      LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
    );

    // Konversi rotasi dari peta ke rotasi layar
    double screenAngle = -angle + math.pi / 2;

    return Center(
      child: Transform.translate(
        offset: Offset(math.cos(screenAngle - math.pi / 2) * 140, math.sin(screenAngle - math.pi / 2) * 280),
        child: Transform.rotate(
          angle: screenAngle,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
            ),
            child: const Icon(Icons.navigation, color: Colors.green, size: 24),
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // HELPER: Single Location Card Popup
  // =====================================================================
  Widget _buildGlassmorphismCard(LocationModel loc, JournalModel? journal, {bool showCloseButton = false}) {
    String? mediaUrl = journal != null && journal.mediaUrls.isNotEmpty ? journal.mediaUrls.first : loc.coverPhotoUrl;
    if (mediaUrl != null && mediaUrl.startsWith('/uploads')) {
      mediaUrl = 'http://10.0.2.2:3000$mediaUrl';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          context.push('/place-hub/${loc.id}?theme=$_selectedTheme');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7), // Lebih solid agar teks hitam terbaca jelas
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: -5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top section (Text)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.name,
                                    style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (loc.description != null && loc.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      loc.description!,
                                      style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            if (showCloseButton) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedLocation = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.black87, size: 14),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${loc.journalCount} Jurnal', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom Section (Image & Button)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: mediaUrl != null
                                ? Image.network(mediaUrl, fit: BoxFit.cover)
                                : Container(color: Colors.black.withOpacity(0.05), child: const Icon(Icons.image, color: Colors.black26, size: 40)),
                          ),
                          // Button Jelajahi
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Jelajahi',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleLocationCard() {
    if (_selectedLocation == null) return const SizedBox.shrink();
    
    return Align(
      alignment: Alignment.center,
      child: FractionalTranslation(
        translation: const Offset(0, -0.65), // Geser sedikit ke atas dari pin center
        child: SizedBox(
          height: 250,
          child: _buildGlassmorphismCard(_selectedLocation!, null, showCloseButton: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Tombol menu modern di pojok kanan atas
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: GestureDetector(
              onTap: () => _showModernMenu(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: _myAvatarUrl != null && _myAvatarUrl!.isNotEmpty 
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: _myAvatarUrl != null && _myAvatarUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _myAvatarUrl!.startsWith('http') 
                                  ? _myAvatarUrl! 
                                  : 'http://10.0.2.2:3000${_myAvatarUrl!.startsWith('/') ? '' : '/'}$_myAvatarUrl',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : BlocListener<BookmarkInteractionBloc, BookmarkState>(
              listener: (context, interactionState) {
                if (interactionState is BookmarkSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(interactionState.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (interactionState is BookmarkFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(interactionState.error),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Stack(
                children: [
                  // ==========================================
                  // LAYER 1: GOOGLE MAPS
                  // ==========================================
                  GoogleMap(
                    initialCameraPosition: _initialPosition,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (widget.targetLat != null && widget.targetLng != null) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted && _mapController != null) {
                            _mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(LatLng(widget.targetLat!, widget.targetLng!), 18.0)
                            );
                          }
                        });
                      }
                    },
                    onCameraMove: (position) {
                      setState(() {
                        _currentCameraPosition = position;
                      });
                    },
                    onTap: (pos) {
                      if (!_isFilterActive) {
                        setState(() {
                          _selectedLocation = null;
                        });
                      }
                    },
                    markers: _buildMarkers(),
                    circles: _filteredLocations.map((loc) {
                      int displayCount = _getDisplayCount(loc);
                      double radius = 50.0 + (displayCount * 5.0);
                      return Circle(
                        circleId: CircleId("glow_${loc.id}"),
                        center: LatLng(loc.latitude, loc.longitude),
                        radius: radius > 300 ? 300 : radius,
                        fillColor: Colors.orangeAccent.withOpacity(
                          0.2 + (displayCount * 0.01).clamp(0.0, 0.4),
                        ),
                        strokeWidth: 0,
                      );
                    }).toSet(),
                  ),

                  // ==========================================
                  // LAYER 2: SEARCH & FILTER CHIPS
                  // ==========================================
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                              ),
                              child: TextField(
                                style: const TextStyle(color: Colors.black87),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                    _currentCarouselIndex = 0;
                                    if (_filteredLocations.isNotEmpty) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLng(LatLng(_filteredLocations.first.latitude, _filteredLocations.first.longitude)),
                                      );
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Cari lokasi impian...',
                                  hintStyle: const TextStyle(color: Colors.black54),
                                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Filter Chips
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _themes.length,
                              itemBuilder: (context, index) {
                                final theme = _themes[index];
                                final isSelected = theme == _selectedTheme;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: isSelected 
                                    ? ChoiceChip(
                                        label: Text(theme),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _selectedTheme = theme;
                                            });
                                          }
                                        },
                                        selectedColor: Colors.green.shade600,
                                        backgroundColor: Colors.white.withOpacity(0.6),
                                        side: BorderSide(color: Colors.green.shade600, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        labelStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                          child: ChoiceChip(
                                            label: Text(theme),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              if (selected) {
                                                setState(() {
                                                  _selectedTheme = theme;
                                                });
                                              }
                                            },
                                            selectedColor: Colors.white.withOpacity(0.9),
                                            backgroundColor: Colors.white.withOpacity(0.6),
                                            side: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            labelStyle: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                );
                              },
                            ),
                          ),
                    ],
                  ),
                ),
              ),

                  // ==========================================
                  // LAYER 3: CAROUSEL GLASSMORPHISM
                  // ==========================================
                  if (_isFilterActive && _filteredLocations.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: SizedBox(
                          height: 250,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onCarouselPageChanged,
                            itemCount: _filteredLocations.length,
                            itemBuilder: (context, index) {
                              final loc = _filteredLocations[index];
                              
                              JournalModel? journal;
                              if (loc.journals.isNotEmpty) {
                                if (_selectedTheme == 'Semua') {
                                  journal = loc.journals.first;
                                } else {
                                  try {
                                    journal = loc.journals.firstWhere((j) => j.themeTag == _selectedTheme);
                                  } catch (e) {
                                    journal = loc.journals.first;
                                  }
                                }
                              }

                              return _buildGlassmorphismCard(loc, journal);
                            },
                          ), // PageView
                        ), // SizedBox
                      ), // Padding
                    ), // Align

                  // ==========================================
                  // LAYER 4: SINGLE CARD POPUP (Semua)
                  // ==========================================
                  if (!_isFilterActive)
                    _buildSingleLocationCard(),

                  // ==========================================
                  // LAYER 5: EDGE INDICATORS
                  // ==========================================
                  _buildEdgeIndicators(),
                ], // Stack children
              ), // Stack
            ), // BlocListener
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Tombol Auto-Center untuk 'Semua' Mode
          if (!_isFilterActive && _selectedLocation != null) ...[
            FloatingActionButton(
              heroTag: 'auto_center',
              mini: true,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude)),
                );
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
            const SizedBox(height: 16),
          ],
          // Tombol Tampilkan Semua Pin (Kuning) untuk mode 'Semua'
          if (!_isFilterActive) ...[
            FloatingActionButton(
              heroTag: 'show_all_pins',
              mini: true,
              onPressed: _showAllPins,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.map, color: Colors.white),
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            heroTag: 'add_journal',
            onPressed: () {
              // Tentukan target lokasi berdasarkan state aktif
              final LocationModel? targetLocation = _isFilterActive
                  ? (_filteredLocations.isNotEmpty ? _filteredLocations[_currentCarouselIndex] : null)
                  : _selectedLocation;
              _handleWriteJournal(targetLocation);
            },
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
