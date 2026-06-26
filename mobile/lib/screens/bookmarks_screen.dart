import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../blocs/bookmark/bookmark_bloc.dart';
import '../blocs/bookmark/bookmark_event.dart';
import '../blocs/bookmark/bookmark_state.dart';
import '../models/bookmark_model.dart';
import '../utils/csv_exporter.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BookmarkBloc()..add(BookmarksRequested()),
      child: const BookmarksView(),
    );
  }
}

class BookmarksView extends StatefulWidget {
  const BookmarksView({Key? key}) : super(key: key);

  @override
  State<BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends State<BookmarksView> {
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
      });
      context.read<BookmarkBloc>().add(FilterBookmarksRequested(search: value));
    });
  }

  void _openMap(double lat, double lng, String locationId) {
    context.go('/map', extra: {
      'targetLat': lat,
      'targetLng': lng,
      'targetLocationId': locationId,
    });
  }

  Widget _buildBookmarkList(List<BookmarkModel> bookmarks, BuildContext context, bool hasMore, {bool isVisitedTab = false}) {
    if (bookmarks.isEmpty) {
      return const Center(
        child: Text("Kosong", style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == bookmarks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  context.read<BookmarkBloc>().add(LoadMoreBookmarksRequested());
                },
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

        final b = bookmarks[index];
        final location = b.location;
        
        if (location == null) {
          return const SizedBox.shrink(); // Ignore if data is incomplete
        }
        
        return Dismissible(
          key: Key(b.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            context.read<BookmarkBloc>().add(BookmarkDeleted(b.id));
          },
          child: Opacity(
            opacity: location.isActive ? 1.0 : 0.5,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  if (!location.isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "📍 Lokasi Resmi Ditutup / Diarsipkan",
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (!isVisitedTab)
                    const SizedBox(height: 12),
                  if (!isVisitedTab)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: location.isActive ? () {
                          _openMap(
                            location.latitude, 
                            location.longitude,
                            location.id
                          );
                        } : null,
                        icon: const Icon(Icons.map, size: 16),
                        label: Text(location.isActive ? "Kunjungi Sekarang" : "Lokasi Ditutup"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: location.isActive ? const Color(0xFF4CAF50) : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        ),
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text('Rencana Jelajah', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            BlocBuilder<BookmarkBloc, BookmarkState>(
              builder: (context, state) {
                if (state is BookmarkLoaded) {
                  return IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.green),
                    tooltip: 'Export ke Excel (CSV)',
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sedang menyiapkan file Excel...')),
                        );
                        final allBookmarks = [...state.planned, ...state.visited];
                        final path = await CsvExporter.exportBookmarksToCsv(allBookmarks, 'Rencana_Jelajah_Nusa');
                        
                        // Menampilkan path agar mudah dicari di File Manager / Emulator
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sukses! File Excel tersimpan di:\n$path'),
                            duration: const Duration(seconds: 5),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal mengekspor file: $e')),
                        );
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Rencana (Planned)"),
              Tab(text: "Pernah Singgah (Visited)"),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Cari lokasi...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
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
              child: BlocConsumer<BookmarkBloc, BookmarkState>(
                listener: (context, state) {
                  if (state is BookmarkActionSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
                  } else if (state is BookmarkActionError) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
                  }
                },
                buildWhen: (prev, current) => current is BookmarkLoading || current is BookmarkLoaded || current is BookmarkError,
                builder: (context, state) {
                  if (state is BookmarkLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is BookmarkError) {
                    return Center(child: Text(state.error, style: const TextStyle(color: Colors.red)));
                  } else if (state is BookmarkLoaded) {
                    return TabBarView(
                      children: [
                        RefreshIndicator(
                          onRefresh: () async {
                            context.read<BookmarkBloc>().add(FilterBookmarksRequested(search: _searchQuery));
                          },
                          child: _buildBookmarkList(state.planned, context, state.hasMore, isVisitedTab: false),
                        ),
                        RefreshIndicator(
                          onRefresh: () async {
                            context.read<BookmarkBloc>().add(FilterBookmarksRequested(search: _searchQuery));
                          },
                          child: _buildBookmarkList(state.visited, context, state.hasMore, isVisitedTab: true),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
