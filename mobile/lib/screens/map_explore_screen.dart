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
import '../blocs/journal/journal_interaction_bloc.dart';
import '../blocs/journal/journal_interaction_event.dart';
import '../blocs/journal/journal_interaction_state.dart';

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({Key? key}) : super(key: key);

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  GoogleMapController? _mapController;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  // Titik awal kamera (Default ke Tugu Jogja agar pas di tengah)
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-7.7829, 110.3671),
    zoom: 13.0,
  );

  // Daftar tema untuk filter
  final List<String> _themes = ['Semua', ...AppConstants.themeTags];
  String _selectedTheme = 'Semua';

  List<LocationModel> _allLocations = [];
  bool _isLoading = true;
  int _currentCarouselIndex = 0;

  List<LocationModel> get _filteredLocations {
    if (_selectedTheme == 'Semua') return _allLocations;
    return _allLocations.where((loc) => loc.availableThemes.contains(_selectedTheme)).toList();
  }

  int _getDisplayCount(LocationModel loc) {
    if (_selectedTheme == 'Semua') return loc.journals.length;
    return loc.journals.where((j) => j.themeTag == _selectedTheme).length;
  }

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    try {
      final response = await ApiClient.instance.get('/map');
      
      if (response.data['success']) {
        setState(() {
          final List<dynamic> data = response.data['data'];
          _allLocations = data.map((json) => LocationModel.fromJson(json as Map<String, dynamic>)).toList();
          _isLoading = false;
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

    // Sinkronkan Carousel: Cari lokasi ini
    int index = _filteredLocations.indexWhere((loc) => loc.id == locationId);
    if (index != -1 && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
        icon: BitmapDescriptor.defaultMarkerWithHue(loc.isBookmarked ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueGreen),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup bottom sheet
                    context.go('/login'); // Ke halaman login
                  },
                  child: const Text('Daftar / Masuk', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), // Icon Drawer
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF9F9F9),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF4CAF50)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                  SizedBox(height: 12),
                  Text('Menu nusa.io', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Jelajah memori', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil & Paspor'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                _handleRestrictedAction('Profil', '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Rencana Jelajah'),
              onTap: () {
                Navigator.pop(context);
                _handleRestrictedAction('Rencana Jelajah', '/bookmarks');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_document),
              title: const Text('Draf Saya'),
              onTap: () {
                Navigator.pop(context);
                _handleRestrictedAction('Draf', '/my-drafts');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () {
                context.read<AuthBloc>().add(LogoutRequested());
              },
            ),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : BlocListener<JournalInteractionBloc, JournalInteractionState>(
            listener: (context, interactionState) {
              if (interactionState is JournalBookmarkSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.green));
              } else if (interactionState is JournalInteractionFailure) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.red));
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
            },
            markers: _buildMarkers(),
            circles: _filteredLocations.map((loc) {
              int displayCount = _getDisplayCount(loc);
              double radius = 50.0 + (displayCount * 5.0); 
              return Circle(
                circleId: CircleId("glow_${loc.id}"),
                center: LatLng(loc.latitude, loc.longitude),
                radius: radius > 300 ? 300 : radius,
                fillColor: Colors.orangeAccent.withOpacity(0.2 + (displayCount * 0.01).clamp(0.0, 0.4)),
                strokeWidth: 0,
              );
            }).toSet(),
          ),

          // ==========================================
          // LAYER 2: FILTER CHIPS
          // ==========================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
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
                        selectedColor: const Color(0xFF4CAF50),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ==========================================
          // LAYER 3: CAROUSEL GLASSMORPHISM
          // ==========================================
          if (_filteredLocations.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: SizedBox(
                  height: 160,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onCarouselPageChanged,
                    itemCount: _filteredLocations.length,
                    itemBuilder: (context, index) {
                      final loc = _filteredLocations[index];
                      // Menentukan warna aksen berdasarkan tema jurnal pertama
                      Color accentColor = const Color(0xFF4CAF50); // Default Hijau
                      if (loc.availableThemes.contains('SENI')) accentColor = Colors.purple;
                      if (loc.availableThemes.contains('KULINER')) accentColor = Colors.orange;
                      
                      // Ambil jurnal representasi berdasarkan tema (jika ada)
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
                      String? mediaUrl = journal != null && journal.mediaUrls.isNotEmpty ? journal.mediaUrls.first : loc.coverPhotoUrl;
                      
                      if (mediaUrl != null && mediaUrl.startsWith('/uploads')) {
                        mediaUrl = 'http://10.0.2.2:3000$mediaUrl';
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            context.push('/place-hub/${loc.id}?theme=$_selectedTheme');
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Kotak Gambar Placeholder
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 100,
                                      height: double.infinity,
                                      color: Colors.grey.withOpacity(0.3),
                                      child: mediaUrl != null
                                        ? Image.network(mediaUrl, fit: BoxFit.cover)
                                        : const Icon(Icons.image, color: Color(0x80FFFFFF)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Detail Teks
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          loc.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          journal?.content ?? 'Belum ada jurnal.',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Icon(Icons.book, size: 14, color: accentColor),
                                            const SizedBox(width: 4),
                                            Text('${_getDisplayCount(loc)} Jurnal', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            const Spacer(),
                                            if (journal != null) ...[
                                              IconButton(
                                                icon: const Icon(Icons.bookmark_border, size: 16),
                                                color: Colors.blueAccent,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  context.read<JournalInteractionBloc>().add(BookmarkJournalRequested(journal!.id));
                                                },
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Text('@${journal?.user?.username ?? 'anonim'}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ), // PageView
                ), // SizedBox
              ), // Padding
            ), // Align
        ], // Stack children
      ), // Stack
    ), // BlocListener
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _handleRestrictedAction('Menulis Jurnal', '/zen-editor');
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}