import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../blocs/draft/draft_bloc.dart';
import '../blocs/draft/draft_event.dart';
import '../blocs/draft/draft_state.dart';
import '../repositories/journal_repository.dart';

class MyDraftsScreen extends StatelessWidget {
  const MyDraftsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DraftBloc(
        repository: context.read<JournalRepository>()
      )..add(DraftsRequested()),
      child: const MyDraftsView(),
    );
  }
}

class MyDraftsView extends StatelessWidget {
  const MyDraftsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Soft background
      appBar: AppBar(
        title: const Text('Draft Saya', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: BlocConsumer<DraftBloc, DraftState>(
        listener: (context, state) {
          if (state is DraftPublishSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is DraftPublishFailed) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
          }
        },
        buildWhen: (previous, current) {
          // Jangan re-build seluruh list saat muncul dialog/snackbar sukses/gagal saja
          return current is DraftLoading || current is DraftsLoaded || current is DraftError;
        },
        builder: (context, state) {
          if (state is DraftLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DraftError) {
            return Center(child: Text(state.error, style: const TextStyle(color: Colors.red)));
          } else if (state is DraftsLoaded) {
            if (state.combinedDrafts.isEmpty) {
              return const Center(child: Text("Tidak ada draf yang tersimpan", style: TextStyle(color: Colors.black54)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.combinedDrafts.length,
              itemBuilder: (context, index) {
                final draft = state.combinedDrafts[index];
                final bool isLocal = draft.isLocal;
                final DateTime parsedDate = draft.createdAt ?? DateTime.now();
                final int daysOld = DateTime.now().difference(parsedDate).inDays;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HEADER INFO ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLocal ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLocal ? "LOKAL" : "SERVER",
                                style: TextStyle(
                                  color: isLocal ? Colors.deepOrange : Colors.blueAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "${parsedDate.day}/${parsedDate.month}/${parsedDate.year}",
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // --- CONTENT SNIPPET ---
                        Text(
                          draft.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        
                        const SizedBox(height: 12),

                        // --- BADGE REMINDER ---
                        if (daysOld > 3)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3))
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                                const SizedBox(width: 4),
                                Text("$daysOld Hari Belum Tayang!", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                        // --- ACTIONS ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                // draft as Map is expected by zen-editor, we need to pass toJson or update zen_editor
                                // I will use toJson for now since zen editor expects Map
                                if (context.mounted) {
                                  final result = await context.push('/zen-editor', extra: draft.toJson());
                                  if (result == true) {
                                    if (context.mounted) {
                                      context.read<DraftBloc>().add(DraftsRequested());
                                    }
                                  }
                                }
                              }, 
                              icon: const Icon(Icons.edit, size: 16), 
                              label: const Text("Edit")
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: isLocal ? null : () {
                                context.read<DraftBloc>().add(PublishPressed(draft.id));
                              }, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                              icon: isLocal ? const Icon(Icons.sync_problem, size: 16) : const Icon(Icons.public, size: 16), 
                              label: Text(isLocal ? "Tunggu Sync" : "Publish")
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
