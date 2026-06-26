import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../services/api_client.dart';
import '../models/journal_model.dart';
import '../blocs/bookmark/bookmark_interaction_bloc.dart';

class SavedJournalsScreen extends StatefulWidget {
  const SavedJournalsScreen({Key? key}) : super(key: key);

  @override
  State<SavedJournalsScreen> createState() => _SavedJournalsScreenState();
}

class _SavedJournalsScreenState extends State<SavedJournalsScreen> {
  List<dynamic> _savedJournals = [];
  bool _isLoading = true;
  String? _error;
  bool _hasMore = false;
  int _page = 1;
  bool _isLoadingMore = false;
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
      _fetchSavedJournals();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchSavedJournals();
  }

  Future<void> _fetchSavedJournals() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = false;
    });

    try {
      String url = '/bookmarks/journals?page=1&limit=5';
      if (_searchQuery.isNotEmpty) url += '&search=${Uri.encodeComponent(_searchQuery)}';
      final res = await ApiClient.instance.get(url);
      if (res.statusCode == 200) {
        setState(() {
          _savedJournals = res.data['data'];
          _hasMore = res.data['meta']?['hasNextPage'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Gagal memuat jurnal tersimpan.";
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['message'] ?? "Terjadi kesalahan koneksi.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Terjadi kesalahan: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      String url = '/bookmarks/journals?page=$nextPage&limit=5';
      if (_searchQuery.isNotEmpty) url += '&search=${Uri.encodeComponent(_searchQuery)}';
      final res = await ApiClient.instance.get(url);
      if (res.statusCode == 200) {
        setState(() {
          _savedJournals.addAll(res.data['data']);
          _hasMore = res.data['meta']?['hasNextPage'] ?? false;
          _page = nextPage;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _unsaveJournal(String saveId) async {
    try {
      final res = await ApiClient.instance.delete('/bookmarks/journals/$saveId');
      if (res.statusCode == 200) {
        setState(() {
          _savedJournals.removeWhere((item) => item['id'] == saveId);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jurnal dihapus dari koleksi'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus jurnal'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Koleksi Inspirasi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Cari jurnal (isi jurnal, lokasi)...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E2124),
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
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _savedJournals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.collections_bookmark_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text("Belum ada jurnal yang disimpan", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedJournals.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _savedJournals.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: _isLoadingMore
                                  ? const CircularProgressIndicator(color: Color(0xFF4CAF50))
                                  : ElevatedButton(
                                      onPressed: _loadMore,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E2124),
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Color(0xFF4CAF50)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text("Muat Lebih Banyak"),
                                    ),
                            ),
                          );
                        }

                        final save = _savedJournals[index];
                        final journalData = save['journal'];
                        final media = journalData['media'] as List<dynamic>? ?? [];
                        final imageUrl = media.isNotEmpty ? media[0]['mediaUrl'] : null;

                        return Card(
                          color: const Color(0xFF1E2124),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              context.push('/place-hub/${journalData['locationId']}');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageUrl != null)
                                  Image.network(
                                    imageUrl.toString().startsWith('http') ? imageUrl : 'http://10.0.2.2:3000${imageUrl.startsWith('/') ? '' : '/'}$imageUrl',
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              journalData['themeTag'] ?? 'UMUM',
                                              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.bookmark, color: Color(0xFF4CAF50)),
                                            onPressed: () => _unsaveJournal(save['id']),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        journalData['content'],
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Oleh @${journalData['user']?['username'] ?? 'anonim'} di ${journalData['location']?['name'] ?? 'Lokasi tidak diketahui'}",
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
