import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/bookmark/bookmark_bloc.dart';
import '../blocs/bookmark/bookmark_event.dart';
import '../blocs/bookmark/bookmark_state.dart';
import '../models/bookmark_model.dart';

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

class BookmarksView extends StatelessWidget {
  const BookmarksView({Key? key}) : super(key: key);

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildBookmarkList(List<BookmarkModel> bookmarks, BuildContext context) {
    if (bookmarks.isEmpty) {
      return const Center(
        child: Text("Kosong", style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final b = bookmarks[index];
        final journal = b.journal;
        final location = b.location;
        
        if (journal == null || location == null) {
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
                  const SizedBox(height: 8),
                  Text(
                    "Jejak dari @${journal.user?.username ?? 'anonim'}",
                    style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: location.isActive ? () {
                        _openMap(
                          location.latitude, 
                          location.longitude
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
        body: BlocConsumer<BookmarkBloc, BookmarkState>(
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
                      context.read<BookmarkBloc>().add(BookmarksRequested());
                    },
                    child: _buildBookmarkList(state.planned, context),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      context.read<BookmarkBloc>().add(BookmarksRequested());
                    },
                    child: _buildBookmarkList(state.visited, context),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
