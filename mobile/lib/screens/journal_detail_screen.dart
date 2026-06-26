import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/journal_model.dart';
import '../models/location_model.dart';
import '../utils/location_verifier.dart';

class JournalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> extraData;

  const JournalDetailScreen({Key? key, required this.extraData}) : super(key: key);

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late JournalModel rootJournal;
  late List<JournalModel> replies;
  late LocationModel location;
  late String currentTheme;

  @override
  void initState() {
    super.initState();
    rootJournal = widget.extraData['rootJournal'];
    replies = widget.extraData['replies'] ?? [];
    location = widget.extraData['location'];
    currentTheme = widget.extraData['currentTheme'] ?? 'Semua';
  }


  Future<void> _handleReplyJournal() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login dulu untuk membalas jurnal!'),
          action: SnackBarAction(label: 'Login', onPressed: () => context.push('/login')),
        ),
      );
      return;
    }

    final position = await LocationVerifier.verifyAndGetPosition(context, location);
    if (position == null) return; // Dibatalkan atau error atau di luar geofence

    await context.push('/zen-editor', extra: {
      'rootJournalId': rootJournal.id,
      'locationId': location.id,
      'latitudeCaptured': position.latitude,
      'longitudeCaptured': position.longitude,
      'isMocked': position.isMocked ? 1 : 0,
    });
  }



  Widget _buildJournalItem(JournalModel journal, bool isRoot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRoot ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isRoot ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isRoot ? 20 : 16,
                backgroundImage: (journal.user?.avatarUrl != null && journal.user!.avatarUrl!.isNotEmpty)
                    ? NetworkImage(journal.user!.avatarUrl!.startsWith('http') 
                        ? journal.user!.avatarUrl! 
                        : 'http://10.0.2.2:3000${journal.user!.avatarUrl!.startsWith('/') ? '' : '/'}${journal.user!.avatarUrl!}')
                    : const AssetImage('assets/images/avatar_placeholder.jpg') as ImageProvider,
                backgroundColor: Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  journal.user?.username ?? 'Anonim',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isRoot ? 16 : 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isRoot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    journal.themeTag,
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            journal.content,
            style: TextStyle(color: Colors.white.withOpacity(isRoot ? 1.0 : 0.8), fontSize: isRoot ? 16 : 14, height: 1.5),
          ),
          if (journal.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: isRoot ? 150 : 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: journal.mediaUrls.length,
                itemBuilder: (context, index) {
                  final mediaUrl = journal.mediaUrls[index];
                  final fullUrl = mediaUrl.startsWith('http') ? mediaUrl : 'http://10.0.2.2:3000${mediaUrl.startsWith('/') ? '' : '/'}$mediaUrl';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullUrl,
                        width: isRoot ? 150 : 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          width: isRoot ? 150 : 100,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image, color: Colors.white54),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Thread Jurnal', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: (rootJournal.status == 'PRIVATE_ARCHIVE' || rootJournal.content == '[Jurnal ini telah ditarik oleh penulis]')
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleReplyJournal,
              backgroundColor: const Color(0xFF4CAF50),
              icon: const Icon(Icons.reply, color: Colors.white),
              label: const Text('Balas Jurnal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildJournalItem(rootJournal, true),
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text('Balasan:', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ...replies.map((reply) => Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildJournalItem(reply, false),
              )).toList(),
            ],
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }
}
