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
import '../../services/api_client.dart';
import '../../repositories/journal_repository.dart';

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

class _JournalImageCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final String placeholderPath;

  const _JournalImageCarousel({Key? key, required this.mediaUrls, required this.placeholderPath}) : super(key: key);

  @override
  State<_JournalImageCarousel> createState() => _JournalImageCarouselState();
}

class _JournalImageCarouselState extends State<_JournalImageCarousel> {
  int _currentIndex = 0;

  void _onTapNext() {
    if (_currentIndex < widget.mediaUrls.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _onTapPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) {
      return Image.asset(
        widget.placeholderPath,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image, color: Colors.white54, size: 48))),
      );
    }

    final mediaUrl = widget.mediaUrls[_currentIndex];
    final fullUrl = mediaUrl.startsWith('http') ? mediaUrl : 'http://10.0.2.2:3000${mediaUrl.startsWith('/') ? '' : '/'}$mediaUrl';

    return Stack(
      children: [
        // Image
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Image.network(
              fullUrl,
              key: ValueKey<String>(fullUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => Image.asset(widget.placeholderPath, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
            ),
          ),
        ),
        
        // Tap Zones
        if (widget.mediaUrls.length > 1) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onTapPrev,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onTapNext,
            ),
          ),
        ],

        // Dots Indicator
        if (widget.mediaUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mediaUrls.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 10 : 6,
                  height: _currentIndex == index ? 10 : 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 1))
                    ],
                  ),
                );
              }),
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
  final PageController _pageController = PageController(viewportFraction: 0.85);

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

  void _handleRestrictedAction(BuildContext context, String actionName, String route) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.push(route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anda harus login untuk $actionName.'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () => context.push('/login'),
          ),
        ),
      );
    }
  }

  void _showReplies(BuildContext context, String rootJournalId, Map<String, List<dynamic>> repliesMap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Balasan", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Expanded(
                child: Center(child: Text("Fitur balasan akan ditampilkan di sini", style: TextStyle(color: Colors.white54))),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: BlocListener<JournalInteractionBloc, JournalInteractionState>(
        listener: (context, interactionState) {
          if (interactionState is JournalBookmarkSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(interactionState.message), backgroundColor: Colors.green));
          } else if (interactionState is JournalArchiveSuccess) {
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
        child: BlocBuilder<PlaceHubBloc, PlaceHubState>(
          builder: (context, state) {
            String? coverUrl;
            if (state is PlaceHubLoaded) {
              coverUrl = state.location.coverPhotoUrl;
            }

            return Stack(
              children: [
                // 1. Full Screen Background Image (Dynamic with Local Fallback)
                Positioned.fill(
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
            
            // 2. Subtle Dark Gradient Overlay (Meningkatkan keterbacaan teks)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
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
                                    child: Text(
                                      theme,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- PAGEVIEW CAROUSEL FOR JOURNALS ---
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
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: rootJournals.length,
                                  itemBuilder: (context, index) {
                                    final rootJournal = rootJournals[index];
                                    final themeColor = _getThemeColor(rootJournal.themeTag);
                                    final isOwned = currentUserId != null && rootJournal.user?.id == currentUserId;
                                    
                                    // Animasi Scale untuk efek Carousel 3D (agar lebih 'pop')
                                    return AnimatedBuilder(
                                      animation: _pageController,
                                      builder: (context, child) {
                                        double value = 1.0;
                                        if (_pageController.position.haveDimensions) {
                                          value = _pageController.page! - index;
                                          value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                                        }
                                        return Center(
                                          child: SizedBox(
                                            height: Curves.easeOut.transform(value) * MediaQuery.of(context).size.height * 0.65,
                                            width: MediaQuery.of(context).size.width * 0.85,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                        child: GlassContainer(
                                          padding: EdgeInsets.zero,
                                          borderRadius: 36,
                                          blur: 20, // Blur lebih kuat untuk kartu utama
                                          color: Colors.white.withOpacity(0.12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Top Half: Full Image Photo
                                              Expanded(
                                                flex: 5,
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                                                  child: _JournalImageCarousel(
                                                    mediaUrls: rootJournal.mediaUrls,
                                                    placeholderPath: _getPlaceholderImage(index),
                                                  ),
                                                ),
                                              ),
                                              
                                              // Bottom Half: Journal Details
                                              Expanded(
                                                flex: 4,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(24.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Author Info & Tag
                                                      Row(
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 20,
                                                            backgroundImage: (rootJournal.user?.avatarUrl != null && rootJournal.user!.avatarUrl!.isNotEmpty)
                                                                ? NetworkImage(rootJournal.user!.avatarUrl!.startsWith('http') 
                                                                    ? rootJournal.user!.avatarUrl! 
                                                                    : 'http://10.0.2.2:3000${rootJournal.user!.avatarUrl!.startsWith('/') ? '' : '/'}${rootJournal.user!.avatarUrl!}')
                                                                : const AssetImage('assets/images/avatar_placeholder.jpg') as ImageProvider,
                                                            backgroundColor: Colors.grey[700],
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              rootJournal.user?.username ?? 'Anonim',
                                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: themeColor.withOpacity(0.9),
                                                              borderRadius: BorderRadius.circular(16),
                                                              boxShadow: [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                                                            ),
                                                            child: Text(
                                                              rootJournal.themeTag,
                                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 20),
                                                      
                                                      // Journal Content
                                                      Expanded(
                                                        child: Text(
                                                          rootJournal.content,
                                                          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5, letterSpacing: 0.3),
                                                          overflow: TextOverflow.fade,
                                                        ),
                                                      ),
                                                      
                                                      const SizedBox(height: 16),
                                                      // Actions Bar
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () {
                                                                  if (currentUserId == null) {
                                                                    _handleRestrictedAction(context, 'menyimpan jurnal', '/login');
                                                                  } else {
                                                                    context.read<JournalInteractionBloc>().add(BookmarkJournalRequested(rootJournal.id));
                                                                  }
                                                                },
                                                                child: const Icon(Icons.bookmark_border, color: Colors.white, size: 28),
                                                              ),
                                                              const SizedBox(width: 24),
                                                              GestureDetector(
                                                                onTap: () => _showReplies(context, rootJournal.id, repliesMap),
                                                                child: const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 28),
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text('${repliesMap[rootJournal.id]?.length ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                            ],
                                                          ),
                                                          if (isOwned)
                                                            PopupMenuButton<String>(
                                                              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                                                              color: const Color(0xFF2C2C2C),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                              onSelected: (value) {
                                                                if (value == 'archive') {
                                                                  context.read<JournalInteractionBloc>().add(ArchiveJournalRequested(rootJournal.id));
                                                                } else if (value == 'delete') {
                                                                  context.read<JournalInteractionBloc>().add(DeleteJournalRequested(rootJournal.id));
                                                                }
                                                              },
                                                              itemBuilder: (context) => [
                                                                const PopupMenuItem(value: 'archive', child: Text('Arsipkan', style: TextStyle(color: Colors.white))),
                                                                const PopupMenuItem(value: 'delete', child: Text('Hapus Permanen', style: TextStyle(color: Colors.redAccent))),
                                                              ],
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
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
