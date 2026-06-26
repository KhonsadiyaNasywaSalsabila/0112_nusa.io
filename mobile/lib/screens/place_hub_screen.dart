import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/place/place_hub_bloc.dart';
import '../blocs/place/place_hub_event.dart';
import '../blocs/place/place_hub_state.dart';
import '../blocs/journal/journal_interaction_bloc.dart';
import '../blocs/journal/journal_interaction_event.dart';
import '../blocs/journal/journal_interaction_state.dart';
import '../blocs/bookmark/bookmark_interaction_bloc.dart';
import '../../services/api_client.dart';
import '../../repositories/journal_repository.dart';
import '../utils/guest_dialog.dart';
import '../utils/location_verifier.dart';
import '../models/location_model.dart';
import '../models/journal_model.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color color;
  final EdgeInsetsGeometry padding;

  const GlassContainer({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.blur = 15.0,
    this.color = const Color(0x1AFFFFFF), // 10% white
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: -5,
              )
            ]
          ),
          child: child,
        ),
      ),
    );
  }
}

class _JournalImageGrid extends StatelessWidget {
  final List<String> mediaUrls;
  final String placeholderPath;

  const _JournalImageGrid({Key? key, required this.mediaUrls, required this.placeholderPath}) : super(key: key);

  Widget _buildImage(String url) {
    final fullUrl = url.startsWith('http') ? url : 'http://10.0.2.2:3000${url.startsWith('/') ? '' : '/'}$url';
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (ctx, err, st) => Image.asset(placeholderPath, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    if (mediaUrls.length == 1) {
      return _buildImage(mediaUrls[0]);
    }

    if (mediaUrls.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildImage(mediaUrls[0])),
          const SizedBox(width: 4),
          Expanded(child: _buildImage(mediaUrls[1])),
        ],
      );
    }

    if (mediaUrls.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _buildImage(mediaUrls[0])),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImage(mediaUrls[1])),
                const SizedBox(height: 4),
                Expanded(child: _buildImage(mediaUrls[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4 or more
    return Row(
      children: [
        Expanded(flex: 2, child: _buildImage(mediaUrls[0])),
        const SizedBox(width: 4),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(child: _buildImage(mediaUrls[1])),
              const SizedBox(height: 4),
              Expanded(child: _buildImage(mediaUrls[2])),
              const SizedBox(height: 4),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(mediaUrls[3]),
                    if (mediaUrls.length > 4)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text('+${mediaUrls.length - 4}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PlaceHubScreen extends StatelessWidget {
  final String locationId;
  final String initialTheme;
  const PlaceHubScreen({Key? key, required this.locationId, this.initialTheme = 'Semua'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => PlaceHubBloc()..add(HubOpened(locationId, theme: initialTheme))),
        BlocProvider(create: (context) => JournalInteractionBloc(repository: JournalRepository())),
      ],
      child: const PlaceHubView(),
    );
  }
}

class PlaceHubView extends StatefulWidget {
  const PlaceHubView({Key? key}) : super(key: key);

  @override
  State<PlaceHubView> createState() => _PlaceHubViewState();
}

class _PlaceHubViewState extends State<PlaceHubView> {
  bool? _isLocationBookmarked;
  final Map<String, bool> _localJournalBookmarks = {};

  Color _getThemeColor(String theme) {
    switch (theme.toUpperCase()) {
      case 'SENI': return Colors.purple;
      case 'KULINER': return Colors.orange;
      case 'ALAM': return Colors.green;
      case 'SEJARAH': return Colors.brown;
      case 'SOSIAL': return Colors.blue;
      case 'PERSONAL': return Colors.pink;
      case 'VINTAGE': return Colors.teal;
      case 'MINDFUL': return Colors.indigo;
      default: return const Color(0xFF4CAF50);
    }
  }

  // Menarik placeholder berulang 1-3 berdasarkan indeks jurnal
  String _getPlaceholderImage(int index) {
    int placeholderNum = (index % 3) + 1;
    return 'assets/images/journal_placeholder_$placeholderNum.jpg';
  }

  void _showReplies(BuildContext context, JournalModel rootJournal, Map<String, List<JournalModel>> repliesMap, LocationModel location, String currentTheme) {
    // Collect replies
    final List<JournalModel> replies = repliesMap[rootJournal.id] ?? [];
    
    // Navigate to JournalDetailScreen, passing the currentTheme too
    context.push('/journal-detail', extra: {
      'rootJournal': rootJournal,
      'replies': replies,
      'location': location,
      'currentTheme': currentTheme,
    });
  }

  void _handleRestrictedAction(BuildContext context, String action, String redirectRoute) {
    GuestDialog.show(context, 'Koleksi Inspirasi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: BlocBuilder<PlaceHubBloc, PlaceHubState>(
        builder: (context, state) {
          if (state is PlaceHubLoaded) {
            return GestureDetector(
              onTap: () async {
                final authState = context.read<AuthBloc>().state;
                final currentUserId = authState is AuthAuthenticated ? authState.userId : null;
                if (currentUserId == null) {
                  GuestDialog.show(context, 'Tulis Jurnal');
                  return;
                }
                final position = await LocationVerifier.verifyAndGetPosition(context, state.location);
                if (position == null) return; // Dibatalkan atau error atau di luar geofence
                
                final result = await context.push('/zen-editor', extra: {
                  'locationId': state.location.id,
                  'latitudeCaptured': position.latitude,
                  'longitudeCaptured': position.longitude,
                  'isMocked': position.isMocked ? 1 : 0,
                });

                if (result == true) {
                  // ignore: use_build_context_synchronously
                  context.read<PlaceHubBloc>().add(HubOpened(state.location.id, theme: state.currentTheme));
                }
              },
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                borderRadius: 30,
                color: Colors.white.withOpacity(0.15), // Efek frosted glass
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Tulis Jurnal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<JournalInteractionBloc, JournalInteractionState>(
            listener: (context, interactionState) {
              if (interactionState is JournalArchiveSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.orange));
                final currentState = context.read<PlaceHubBloc>().state;
                if (currentState is PlaceHubLoaded) {
                  context.read<PlaceHubBloc>().add(HubOpened(currentState.location.id, theme: currentState.currentTheme));
                }
              } else if (interactionState is JournalDeleteSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.redAccent));
                final currentState = context.read<PlaceHubBloc>().state;
                if (currentState is PlaceHubLoaded) {
                  context.read<PlaceHubBloc>().add(HubOpened(currentState.location.id, theme: currentState.currentTheme));
                }
              } else if (interactionState is JournalInteractionFailure) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.red));
              }
            },
          ),
          BlocListener<BookmarkInteractionBloc, BookmarkState>(
            listener: (context, interactionState) {
              if (interactionState is BookmarkSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.green));
              } else if (interactionState is BookmarkFailure) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.error), backgroundColor: Colors.red));
              }
            },
          ),
        ],
        child: BlocBuilder<PlaceHubBloc, PlaceHubState>(
          builder: (context, state) {
            String? coverUrl;
            if (state is PlaceHubLoaded) {
              coverUrl = state.location.coverPhotoUrl;
            }

            return Stack(
              children: [
                // Background Solid Canvas
                Positioned.fill(
                  child: Container(color: const Color(0xFF1F2B22)), // Elegant dark forest green
                ),
                // 1. Hero Header Image (Only top 45%)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: (coverUrl != null && coverUrl.isNotEmpty)
                      ? Image.network(
                          coverUrl.startsWith('http') ? coverUrl : 'http://10.0.2.2:3000${coverUrl.startsWith('/') ? '' : '/'}$coverUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/place_hub_bg.jpg', fit: BoxFit.cover),
                        )
                      : Image.asset(
                          'assets/images/place_hub_bg.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1E2124)),
                        ),
                ),
            
                // 2. Gradient Fade to Solid Background
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.46, // slightly overlap
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1F2B22).withOpacity(0.5), // Top slightly darkened
                          Colors.transparent, // Middle clear
                          const Color(0xFF1F2B22), // Bottom solid to blend seamlessly
                        ],
                        stops: const [0.0, 0.4, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

            // 3. Main Content
            SafeArea(
              child: Builder(
                builder: (context) {
                  if (state is PlaceHubLoading) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  } else if (state is PlaceHubError) {
                    return Center(child: GlassContainer(child: Text(state.error, style: const TextStyle(color: Colors.redAccent))));
                  } else if (state is PlaceHubLoaded) {
                    final location = state.location;
                    final rootJournals = state.rootJournals;
                    final authState = context.read<AuthBloc>().state;
                    final String? currentUserId = authState is AuthAuthenticated ? authState.userId : null;
                    final repliesMap = state.repliesMap;
                    final currentTheme = state.currentTheme;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HEADER: Back Button & Location Title ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 24,
                                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  location.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  if (location.isVisited) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda sudah pernah mengunjungi lokasi ini')));
                                    return;
                                  }

                                  final authState = context.read<AuthBloc>().state;
                                  final currentUserId = authState is AuthAuthenticated ? authState.userId : null;
                                  if (currentUserId == null) {
                                    GuestDialog.show(context, 'Rencana Jelajah');
                                  } else {
                                    bool currentStatus = _isLocationBookmarked ?? location.isBookmarked;
                                    setState(() {
                                      _isLocationBookmarked = !currentStatus;
                                    });
                                    if (currentStatus) {
                                      context.read<BookmarkInteractionBloc>().add(UnbookmarkLocationRequested(location.id));
                                    } else {
                                      context.read<BookmarkInteractionBloc>().add(BookmarkLocationRequested(location.id));
                                    }
                                  }
                                },
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 24,
                                  child: Icon(
                                    location.isVisited ? Icons.verified : ((_isLocationBookmarked ?? location.isBookmarked) ? Icons.bookmark : Icons.bookmark_border),
                                    color: location.isVisited ? Colors.greenAccent : ((_isLocationBookmarked ?? location.isBookmarked) ? Colors.amber : Colors.white),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // --- THEME CHIPS (Glass Pills) ---
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: ['Semua', 'VINTAGE', 'ALAM', 'KULINER', 'SOSIAL', 'PERSONAL', 'MINDFUL', 'SENI'].map((theme) {
                              final isSelected = theme == currentTheme;
                              final Color themeColor = _getThemeColor(theme);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!isSelected) {
                                      context.read<PlaceHubBloc>().add(HubOpened(location.id, theme: theme));
                                    }
                                  },
                                  child: GlassContainer(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    borderRadius: 30,
                                    color: isSelected ? themeColor.withOpacity(0.6) : Colors.white.withOpacity(0.15),
                                    child: Row(
                                      children: [
                                        if (theme == 'Semua') ...[
                                          const Icon(Icons.search, color: Colors.amber, size: 18),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          theme,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- LISTVIEW FOR JOURNALS ---
                        Expanded(
                          child: rootJournals.isEmpty
                              ? Center(
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(32),
                                    borderRadius: 24,
                                    child: const Text(
                                      "Belum ada jurnal untuk tema ini.\nJadilah yang pertama!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 120, top: 8),
                                  itemCount: rootJournals.length,
                                  itemBuilder: (context, index) {
                                    final rootJournal = rootJournals[index];
                                    final themeColor = _getThemeColor(rootJournal.themeTag);
                                    final isOwned = currentUserId != null && rootJournal.user?.id == currentUserId;
                                    final bool isWithdrawn = rootJournal.content == '[Jurnal ini telah ditarik oleh penulis]';
                                    
                                    Widget cardChild = Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95), // Modern luxury clean white
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                                        ],
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Top: Author Info & Tag
                                          Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundImage: (rootJournal.user?.avatarUrl != null && rootJournal.user!.avatarUrl!.isNotEmpty)
                                                      ? NetworkImage(rootJournal.user!.avatarUrl!.startsWith('http') 
                                                          ? rootJournal.user!.avatarUrl! 
                                                          : 'http://10.0.2.2:3000${rootJournal.user!.avatarUrl!.startsWith('/') ? '' : '/'}${rootJournal.user!.avatarUrl!}')
                                                      : const AssetImage('assets/images/avatar_placeholder.jpg') as ImageProvider,
                                                  backgroundColor: Colors.grey[300],
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    rootJournal.user?.username ?? 'Anonim',
                                                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: themeColor.withOpacity(0.1),
                                                    border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    rootJournal.themeTag,
                                                    style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Courier'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Middle: Image Grid (Protruding/No Padding)
                                          if (rootJournal.mediaUrls.isNotEmpty)
                                            SizedBox(
                                              width: double.infinity,
                                              height: 300, // Memberikan tinggi pasti agar tidak conflict di scrollview
                                              child: _JournalImageGrid(
                                                mediaUrls: rootJournal.mediaUrls,
                                                placeholderPath: _getPlaceholderImage(index),
                                              ),
                                            ),
                                          
                                          // Middle: Text Content
                                          if (rootJournal.content.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.all(20.0),
                                              child: Text(
                                                rootJournal.content,
                                                style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5, fontFamily: 'Georgia'),
                                              ),
                                            ),
                                          
                                          // Bottom: Elegant Divider & Actions
                                          if (rootJournal.content.isEmpty && rootJournal.mediaUrls.isNotEmpty)
                                            const SizedBox(height: 12),
                                            
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                            child: Divider(color: Colors.grey.shade200, height: 1),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (currentUserId == null) {
                                                          GuestDialog.show(context, 'Koleksi Inspirasi');
                                                        } else {
                                                          bool currentStatus = _localJournalBookmarks[rootJournal.id] ?? rootJournal.isBookmarked;
                                                          setState(() {
                                                            _localJournalBookmarks[rootJournal.id] = !currentStatus;
                                                          });
                                                          if (currentStatus) {
                                                            context.read<BookmarkInteractionBloc>().add(UnsaveJournalRequested(rootJournal.id));
                                                          } else {
                                                            context.read<BookmarkInteractionBloc>().add(SaveJournalRequested(rootJournal.id));
                                                          }
                                                        }
                                                      },
                                                      child: Icon(
                                                        (_localJournalBookmarks[rootJournal.id] ?? rootJournal.isBookmarked) ? Icons.bookmark : Icons.bookmark_border,
                                                        color: (_localJournalBookmarks[rootJournal.id] ?? rootJournal.isBookmarked) ? const Color(0xFF4CAF50) : Colors.grey.shade700,
                                                        size: 26,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 24),
                                                    GestureDetector(
                                                      onTap: () => _showReplies(context, rootJournal, repliesMap, location, currentTheme),
                                                      child: Icon(Icons.mode_comment_outlined, color: Colors.grey.shade700, size: 26),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text('${repliesMap[rootJournal.id]?.length ?? 0}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Courier')),
                                                  ],
                                                ),
                                                if (isOwned)
                                                  PopupMenuButton<String>(
                                                    icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 26),
                                                    color: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                    onSelected: (value) {
                                                      if (value == 'archive') {
                                                        context.read<JournalInteractionBloc>().add(ArchiveJournalRequested(rootJournal.id));
                                                      } else if (value == 'delete') {
                                                        context.read<JournalInteractionBloc>().add(DeleteJournalRequested(rootJournal.id));
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(value: 'archive', child: Text('Arsipkan', style: TextStyle(color: Colors.black87))),
                                                      const PopupMenuItem(value: 'delete', child: Text('Hapus Permanen', style: TextStyle(color: Colors.redAccent))),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    
                                    if (isWithdrawn) {
                                      cardChild = ColorFiltered(
                                        colorFilter: const ColorFilter.matrix([
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0,      0,      0,      1, 0,
                                        ]),
                                        child: Opacity(
                                          opacity: 0.85,
                                          child: cardChild,
                                        ),
                                      );
                                    }
                                    
                                    return cardChild;
                                  },
                                ),
                        ),
                        const SizedBox(height: 32), // Bottom padding
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        );
        },
      ),
      ),
    );
  }
}
