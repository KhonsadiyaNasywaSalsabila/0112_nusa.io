import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/sync/sync_bloc.dart';
import 'blocs/sync/sync_event.dart';
import 'blocs/journal/journal_interaction_bloc.dart';
import 'repositories/journal_repository.dart';
import 'routes/app_router.dart';

// Deklarasi global agar bisa dipakai di app_router.dart
final AuthBloc authBloc = AuthBloc();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<JournalRepository>(create: (context) => JournalRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<JournalInteractionBloc>(
            create: (context) => JournalInteractionBloc(
              repository: context.read<JournalRepository>()
            ),
          ),
          BlocProvider<SyncBloc>(
            create: (context) {
              final syncBloc = SyncBloc(
                repository: context.read<JournalRepository>()
              );
              
              // Dengarkan perubahan konektivitas untuk Auto-Sync
              Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
                if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
                  syncBloc.add(ConnectivityRestored());
                }
              });
              
              return syncBloc;
            }
          ),
        ],
        child: MaterialApp.router(
        title: 'Nusa.io',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
      ),
    );
  }
}