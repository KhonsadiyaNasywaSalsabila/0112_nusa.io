import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../blocs/profile/profile_bloc.dart';
import '../blocs/profile/profile_event.dart';
import '../blocs/profile/profile_state.dart';
import '../models/location_model.dart';

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
    if (stamps.isEmpty) {
      return const Center(child: Text("Belum ada stempel paspor", style: TextStyle(color: Colors.black54)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: stamps.length,
      itemBuilder: (context, index) {
        final locJson = stamps[index]['location'] as Map<String, dynamic>;
        final loc = LocationModel.fromJson(locJson);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
            image: loc.coverPhotoUrl != null && loc.coverPhotoUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(loc.coverPhotoUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                  )
                : null,
            color: Colors.green.shade700,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: Colors.amber, size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  loc.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchivesList(List<dynamic> archives) {
    if (archives.isEmpty) {
      return const Center(child: Text("Belum ada jurnal yang diarsipkan", style: TextStyle(color: Colors.black54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archives.length,
      itemBuilder: (context, index) {
        final journal = archives[index];
        final locationName = journal['location']?['name'] ?? 'Lokasi';
        final content = journal['content'] ?? '';
        final mediaList = journal['media'] as List<dynamic>? ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lock Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text("Hanya Anda yang bisa melihat ini", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        journal['themeTag'] ?? 'Lainnya',
                        style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
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
                      locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(content, style: const TextStyle(fontSize: 14)),
                    if (mediaList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'http://10.0.2.2:3000${mediaList[0]['url']}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                        ),
                      )
                    ]
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemoriesList(List<dynamic> memories) {
    if (memories.isEmpty) {
      return const Center(child: Text("Belum ada jejak memori publik", style: TextStyle(color: Colors.black54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final journal = memories[index];
        final loc = journal['location'];
        final locationName = loc?['name'] ?? 'Lokasi';
        final isActive = loc?['isActive'] ?? true;
        final content = journal['content'] ?? '';
        final mediaList = journal['media'] as List<dynamic>? ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location & Tag Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(isActive ? Icons.public : Icons.history, size: 16, color: isActive ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    Text(isActive ? "Publik" : "Kapsul Waktu", style: TextStyle(fontSize: 12, color: isActive ? Colors.blue : Colors.grey)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        journal['themeTag'] ?? 'Lainnya',
                        style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
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
                      locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    Text(content, style: const TextStyle(fontSize: 14)),
                    if (mediaList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'http://10.0.2.2:3000${mediaList[0]['url']}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                        ),
                      )
                    ],
                    // Action Buttons
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isActive) ...[
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                            label: const Text("Edit", style: TextStyle(color: Colors.blue)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text("Balas"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ] else ...[
                          const Text("Mode Baca Saja", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
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
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is AvatarUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is AvatarUpdateFailed) {
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
                        _buildMemoriesList(state.memories),
                        _buildArchivesList(state.archives),
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
