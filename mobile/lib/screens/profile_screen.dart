import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../blocs/profile/profile_bloc.dart';
import '../blocs/profile/profile_event.dart';
import '../blocs/profile/profile_state.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../repositories/journal_repository.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc()..add(ProfileRequested()),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ImagePicker _picker = ImagePicker();
  
  final List<String> _themes = ['Semua', 'VINTAGE', 'ALAM', 'KULINER', 'SOSIAL', 'PERSONAL', 'MINDFUL'];
  String _memorySearchQuery = '';
  String _memoryTheme = 'Semua';
  String _archiveSearchQuery = '';
  String _archiveTheme = 'Semua';
  String _stampSearchQuery = '';
  Timer? _debounce;
  Timer? _stampDebounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _stampDebounce?.cancel();
    super.dispose();
  }

  void _onStampSearchChanged(String value) {
    if (_stampDebounce?.isActive ?? false) _stampDebounce!.cancel();
    _stampDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _stampSearchQuery = value;
      });
      context.read<ProfileBloc>().add(FilterStampsRequested(value));
    });
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (context.mounted) {
        context.read<ProfileBloc>().add(AvatarUpdated(image.path));
      }
    }
  }

  Widget _buildPersonalMap(List<dynamic> stamps) {
    Set<Marker> markers = stamps.map((stamp) {
      final locJson = stamp['location'] as Map<String, dynamic>;
      final loc = LocationModel.fromJson(locJson);
      return Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.latitude, loc.longitude),
        infoWindow: InfoWindow(title: loc.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    }).toSet();

    // Pusat default Indonesia
    CameraPosition initialPos = const CameraPosition(
      target: LatLng(-0.7893, 113.9213),
      zoom: 4,
    );

    if (markers.isNotEmpty) {
      initialPos = CameraPosition(
        target: markers.first.position,
        zoom: 10,
      );
    }

    return GoogleMap(
      initialCameraPosition: initialPos,
      markers: markers,
      mapType: MapType.normal,
      myLocationEnabled: false,
    );
  }

  Widget _buildStampsGrid(List<dynamic> stamps) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: _onStampSearchChanged,
            decoration: InputDecoration(
              hintText: "Cari stempel lokasi...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.green, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: stamps.isEmpty
              ? const Center(child: Text("Belum ada stempel paspor", style: TextStyle(color: Colors.black54)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: stamps.length,
                  itemBuilder: (context, index) {
                    final stamp = stamps[index];
                    final locJson = stamp['location'] as Map<String, dynamic>;
                    final loc = LocationModel.fromJson(locJson);
                    
                    // Format date
                    final earnedAtStr = stamp['earnedAt'] as String?;
                    String dateStr = "UNKNOWN";
                    if (earnedAtStr != null) {
                      try {
                        final date = DateTime.parse(earnedAtStr);
                        dateStr = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
                      } catch (_) {}
                    }

                    // Pseudo-random properties based on location ID to keep it consistent
                    final math.Random random = math.Random(loc.id.hashCode);
                    final double angle = (random.nextDouble() * 0.5) - 0.25; // -0.25 to 0.25 radians
                    final List<Color> colors = [
                      const Color(0xFF9E2A2B), // Vintage Red
                      const Color(0xFF1D3557), // Navy Blue
                      const Color(0xFF386641), // Forest Green
                      const Color(0xFF5D2E46), // Purple
                    ];
                    final Color stampColor = colors[random.nextInt(colors.length)];
                    final int shapeType = random.nextInt(4);
                    final bool isCircle = shapeType == 0;
                    BorderRadius? outerRadius;
                    BorderRadius? innerRadius;
                    if (!isCircle) {
                      if (shapeType == 1) {
                        outerRadius = BorderRadius.circular(12); // Melengkung biasa
                        innerRadius = BorderRadius.circular(8);
                      } else if (shapeType == 2) {
                        outerRadius = BorderRadius.circular(4); // Hampir kotak tajam
                        innerRadius = BorderRadius.circular(2);
                      } else {
                        outerRadius = BorderRadius.circular(32); // Melengkung ekstrem (Kapsul/Stadium)
                        innerRadius = BorderRadius.circular(28);
                      }
                    }

                    return Center(
                      child: Transform.rotate(
                        angle: angle,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                            borderRadius: outerRadius,
                            border: Border.all(
                              color: stampColor.withOpacity(0.8),
                              width: 3.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Inner border
                              Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                                    borderRadius: innerRadius,
                                    border: Border.all(
                                      color: stampColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              // Content
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.flight_land,
                                      color: stampColor.withOpacity(0.9),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        loc.name.toUpperCase(),
                                        style: TextStyle(
                                          color: stampColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                          fontFamily: 'Courier', 
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        color: stampColor.withOpacity(0.85),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "ARRIVED",
                                      style: TextStyle(
                                        color: stampColor.withOpacity(0.7),
                                        fontSize: 7,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _editJournal(dynamic journal) async {
    final result = await context.push('/zen-editor', extra: {
      'id': journal['id'],
      'locationId': journal['location']?['id'] ?? journal['locationId'], // In case location object is nested
      'content': journal['content'],
      'themeTag': journal['themeTag'],
      'latitudeCaptured': journal['latitudeCaptured'],
      'longitudeCaptured': journal['longitudeCaptured'],
      'mediaUrls': (journal['media'] as List<dynamic>?)?.map((m) => m['mediaUrl']).toList(),
      'isLocal': false,
      'status': journal['status'],
    });
    
    // Refresh profile if returning true (meaning published/updated)
    if (result == true && mounted) {
      context.read<ProfileBloc>().add(ProfileRequested());
    }
  }

  Future<void> _confirmDeleteJournal(dynamic journal) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Jurnal?'),
          content: const Text('Apakah Anda yakin ingin menghapus jurnal ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      try {
        final res = await context.read<JournalRepository>().deleteJournal(journal['id']);
        if (res.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res.data['message'] ?? 'Berhasil menghapus jurnal')),
            );
            context.read<ProfileBloc>().add(ProfileRequested());
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus jurnal'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _archiveJournal(dynamic journal) async {
    try {
      final res = await context.read<JournalRepository>().archiveJournal(journal['id']);
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Berhasil mengarsipkan jurnal'), backgroundColor: Colors.orange),
          );
          context.read<ProfileBloc>().add(ProfileRequested());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengarsipkan jurnal'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _publishJournal(dynamic journal) async {
    try {
      final res = await context.read<JournalRepository>().publishJournal(journal['id']);
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Berhasil mempublikasikan jurnal'), backgroundColor: Colors.green),
          );
          context.read<ProfileBloc>().add(ProfileRequested());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mempublikasikan jurnal'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildFilterHeader({
    required String searchQuery,
    required String selectedTheme,
    required Function(String) onSearchChanged,
    required Function(String?) onThemeChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: searchQuery)..selection = TextSelection.fromPosition(TextPosition(offset: searchQuery.length)),
              decoration: InputDecoration(
                hintText: 'Cari kata kunci...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTheme,
                items: _themes.map((theme) {
                  return DropdownMenuItem<String>(
                    value: theme,
                    child: Text(theme, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: onThemeChanged,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildArchivesList(List<dynamic> archives, bool hasMore, VoidCallback onLoadMore) {
    return Column(
      children: [
        _buildFilterHeader(
          searchQuery: _archiveSearchQuery,
          selectedTheme: _archiveTheme,
          onSearchChanged: (val) {
            _archiveSearchQuery = val;
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              context.read<ProfileBloc>().add(FilterArchivesRequested(theme: _archiveTheme, search: _archiveSearchQuery));
            });
          },
          onThemeChanged: (val) {
            if (val != null) {
              setState(() => _archiveTheme = val);
              context.read<ProfileBloc>().add(FilterArchivesRequested(theme: _archiveTheme, search: _archiveSearchQuery));
            }
          },
        ),
        Expanded(
          child: archives.isEmpty
              ? const Center(child: Text("Belum ada jurnal yang diarsipkan", style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: archives.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
        if (index == archives.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: onLoadMore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Muat Lebih Banyak"),
              ),
            ),
          );
        }

        final journal = archives[index];
        final locationName = journal['location']?['name'] ?? 'Lokasi';
        final content = journal['content'] ?? '';
        final mediaList = journal['media'] as List<dynamic>? ?? [];
        
        final math.Random random = math.Random(journal['id'].hashCode);
        final double angle = (random.nextDouble() * 0.06) - 0.03; // -0.03 to 0.03 radians tilt
        
        final List<Color> paperColors = [
          const Color(0xFFF9F6EE), // Krem polaroid
          const Color(0xFFFDFBF7), // Putih tulang
          const Color(0xFFF4ECD8), // Kertas tua
          const Color(0xFFEBE3D5), // Sedikit kusam
          const Color(0xFFE8F0E5), // Hijau sage pudar
          const Color(0xFFE6EBF0), // Biru pudar vintage
          const Color(0xFFF2E6E6), // Merah bata pudar
          const Color(0xFFF0ECD8), // Kuning mentega pudar
        ];
        final Color bgColor = paperColors[random.nextInt(paperColors.length)];

        final List<String> fontChoices = ['Courier', 'Georgia'];
        final String fontFamily = fontChoices[random.nextInt(fontChoices.length)];
        
        final replyCount = journal['_count']?['childJournals'] ?? 0;
        
        return Transform.rotate(
          angle: angle,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4, top: 4),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: Offset(random.nextDouble() * 4, random.nextDouble() * 4 + 2),
                ),
              ],
              border: Border.all(color: Colors.grey.shade400, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Lock (Vintage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text("ARSIP PRIBADI", style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.black54, fontFamily: 'Courier')),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black45, width: 0.5),
                        ),
                        child: Text(
                          (journal['themeTag'] ?? 'LAINNYA').toString().toUpperCase(),
                          style: const TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Courier', letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5, fontFamily: fontFamily),
                    ),
                    const SizedBox(height: 8),
                    Text(content, style: TextStyle(fontSize: 14, fontFamily: fontFamily, color: Colors.black87)),
                    if (mediaList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          // Bervariasi sedikit warnanya berdasarkan random
                          0.50, 0.40, 0.10, 0, 0,
                          0.30, 0.60, 0.10, 0, 0,
                          0.20, 0.20, 0.40, 0, 0,
                          0,    0,    0,    1, 0,
                        ]),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Image.network(
                            'http://10.0.2.2:3000${mediaList[0]['mediaUrl']}', // Menggunakan mediaUrl sesuai skema baru
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180, 
                              color: Colors.grey.shade300, 
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        ),
                      )
                    ],
                    // Action Buttons (Scrapbook style)
                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reply Count
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "$replyCount Balasan",
                              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                            ),
                          ],
                        ),
                        // Actions
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _publishJournal(journal),
                              icon: const Icon(Icons.public, size: 20, color: Colors.green),
                              tooltip: "Pulihkan Publik",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () => _editJournal(journal),
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.teal),
                              tooltip: "Edit",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () => _confirmDeleteJournal(journal),
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: "Hapus",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMemoriesList(List<dynamic> memories, bool hasMore, VoidCallback onLoadMore) {
    return Column(
      children: [
        _buildFilterHeader(
          searchQuery: _memorySearchQuery,
          selectedTheme: _memoryTheme,
          onSearchChanged: (val) {
            _memorySearchQuery = val;
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              context.read<ProfileBloc>().add(FilterMemoriesRequested(theme: _memoryTheme, search: _memorySearchQuery));
            });
          },
          onThemeChanged: (val) {
            if (val != null) {
              setState(() => _memoryTheme = val);
              context.read<ProfileBloc>().add(FilterMemoriesRequested(theme: _memoryTheme, search: _memorySearchQuery));
            }
          },
        ),
        Expanded(
          child: memories.isEmpty
              ? const Center(child: Text("Belum ada jejak memori publik", style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: memories.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
        if (index == memories.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: onLoadMore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Muat Lebih Banyak"),
              ),
            ),
          );
        }

        final journal = memories[index];
        final loc = journal['location'];
        final locationName = loc?['name'] ?? 'Lokasi';
        final isActive = loc?['isActive'] ?? true;
        final content = journal['content'] ?? '';
        final mediaList = journal['media'] as List<dynamic>? ?? [];
        
        final replyCount = journal['_count']?['childJournals'] ?? 0;

        final math.Random random = math.Random(journal['id'].hashCode);
        final double angle = (random.nextDouble() * 0.06) - 0.03; // -0.03 to 0.03 radians tilt
        
        final List<Color> paperColors = [
          const Color(0xFFF9F6EE), // Krem polaroid
          const Color(0xFFFDFBF7), // Putih tulang
          const Color(0xFFF4ECD8), // Kertas tua
          const Color(0xFFEBE3D5), // Sedikit kusam
          const Color(0xFFE8F0E5), // Hijau sage pudar
          const Color(0xFFE6EBF0), // Biru pudar vintage
          const Color(0xFFF2E6E6), // Merah bata pudar
          const Color(0xFFF0ECD8), // Kuning mentega pudar
        ];
        final Color bgColor = paperColors[random.nextInt(paperColors.length)];

        final List<String> fontChoices = ['Courier', 'Georgia'];
        final String fontFamily = fontChoices[random.nextInt(fontChoices.length)];

        return Transform.rotate(
          angle: angle,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4, top: 4),
            decoration: BoxDecoration(
              color: bgColor, // Warna kertas acak
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: Offset(random.nextDouble() * 4, random.nextDouble() * 4 + 2),
                ),
              ],
              border: Border.all(color: Colors.grey.shade400, width: 0.5),
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Vintage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(isActive ? Icons.public : Icons.history_toggle_off, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(isActive ? "PUBLIK" : "KAPSUL WAKTU", style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontFamily: 'Courier')),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.brown.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (journal['themeTag'] ?? 'LAINNYA').toString().toUpperCase(),
                        style: const TextStyle(color: Colors.brown, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Courier', letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5, fontFamily: fontFamily),
                    ),
                    if (!isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                        child: Text(
                          "Jurnal ini ditulis di lokasi yang kini telah menjadi kenangan (Diarsipkan).",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(content, style: TextStyle(fontSize: 14, fontFamily: fontFamily, color: Colors.black87)),
                    if (mediaList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ColorFiltered(
                        // Efek Sepia Tipis
                        colorFilter: const ColorFilter.matrix([
                          0.60, 0.30, 0.10, 0, 0,
                          0.30, 0.50, 0.10, 0, 0,
                          0.20, 0.20, 0.40, 0, 0,
                          0,    0,    0,    1, 0,
                        ]),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Image.network(
                            'http://10.0.2.2:3000${mediaList[0]['mediaUrl']}',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180, 
                              color: Colors.grey.shade300, 
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Action Buttons (Vintage Modern)
                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reply Count
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "$replyCount Balasan",
                              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                            ),
                          ],
                        ),
                        // Actions
                        if (isActive)
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _archiveJournal(journal),
                                icon: const Icon(Icons.archive_outlined, size: 20, color: Colors.brown),
                                tooltip: "Arsipkan",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => _editJournal(journal),
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.teal),
                                tooltip: "Edit",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => _confirmDeleteJournal(journal),
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: "Hapus",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        else
                          const Text("READ ONLY", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'Courier')),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      );
                  },
                ),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet(BuildContext parentContext, UserModel user) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Pengaturan Profil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Profil"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditProfileDialog(parentContext, user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text("Ganti Kata Sandi"),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog(parentContext);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Hapus Akun", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteAccount(parentContext);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext parentContext, UserModel user) {
    final usernameController = TextEditingController(text: user.username);
    final bioController = TextEditingController(text: user.bio ?? '');

    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: "Bio Singkat"),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                parentContext.read<ProfileBloc>().add(ProfileUpdateRequested(
                  username: usernameController.text,
                  bio: bioController.text,
                ));
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext parentContext) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ganti Kata Sandi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                decoration: const InputDecoration(labelText: "Kata Sandi Lama"),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(labelText: "Kata Sandi Baru"),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                parentContext.read<ProfileBloc>().add(PasswordUpdateRequested(
                  oldPassword: oldPasswordController.text,
                  newPassword: newPasswordController.text,
                ));
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus Akun?"),
          content: const Text("Anda yakin ingin menghapus akun? Profil Anda akan dianonimkan agar Jurnal dan Diskusi Anda tetap ada."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                parentContext.read<ProfileBloc>().add(AccountDeleteRequested());
                Navigator.pop(context);
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoaded) {
                return IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsBottomSheet(context, state.user),
                );
              }
              return const SizedBox.shrink();
            },
          )
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is AvatarUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is AvatarUpdateFailed) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
          } else if (state is ProfileActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
            if (state.message.contains("dihapus")) {
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/login');
            }
          } else if (state is ProfileActionError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
          }
        },
        buildWhen: (prev, current) => current is ProfileLoading || current is ProfileLoaded || current is ProfileError,
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProfileError) {
            return Center(child: Text(state.error, style: const TextStyle(color: Colors.red)));
          } else if (state is ProfileLoaded) {
            final user = state.user;
            final stamps = state.stamps;

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _pickAndUploadImage(context),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? NetworkImage('http://10.0.2.2:3000${user.avatarUrl}')
                                    : null,
                                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                    : null,
                              ),
                              Container(
                                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text("@${user.username}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(user.bio ?? "Traveler sejati belum menulis bio", style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  
                  // Tabs
                  const TabBar(
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.green,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: "Peta Personal"),
                      Tab(text: "Stempel Paspor"),
                      Tab(text: "Jejak Memori"),
                      Tab(text: "Arsip Pribadi"),
                    ],
                  ),
                  
                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(), // Map has its own gesture
                      children: [
                        _buildPersonalMap(stamps),
                        _buildStampsGrid(stamps),
                        _buildMemoriesList(
                          state.memories,
                          state.hasMoreMemories,
                          () => context.read<ProfileBloc>().add(LoadMoreMemoriesRequested()),
                        ),
                        _buildArchivesList(
                          state.archives,
                          state.hasMoreArchives,
                          () => context.read<ProfileBloc>().add(LoadMoreArchivesRequested()),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
