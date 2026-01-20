import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/clip_explorer_provider.dart';
import 'providers/clip_provider.dart';
import 'providers/device_provider.dart';
import 'providers/mark_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/server_provider.dart';
import 'providers/session_provider.dart';
import 'screens/coordinator_home.dart';
import 'services/clip_downloader_service.dart';
import 'services/clip_explorer_service.dart';
import 'services/database_service.dart';
import 'services/device_manager_service.dart';
import 'services/local_playback_service.dart';
import 'services/mark_service.dart';
import 'services/network_service.dart';
import 'services/pairing_service.dart';
import 'services/remote_playback_service.dart';
import 'services/session_manager_service.dart';
import 'services/websocket_server_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize media_kit for video playback
  MediaKit.ensureInitialized();

  // Create services
  final databaseService = DatabaseService();
  final networkService = NetworkService();
  final pairingService = PairingService(databaseService: databaseService);
  final deviceManagerService = DeviceManagerService(
    databaseService: databaseService,
    pairingService: pairingService,
  );
  final sessionManagerService = SessionManagerService(
    databaseService: databaseService,
    deviceManagerService: deviceManagerService,
  );
  final markService = MarkService(
    databaseService: databaseService,
    deviceManagerService: deviceManagerService,
    sessionManagerService: sessionManagerService,
  );
  final clipDownloaderService = ClipDownloaderService(
    databaseService: databaseService,
    deviceManagerService: deviceManagerService,
    sessionManagerService: sessionManagerService,
  );
  final clipExplorerService = ClipExplorerService(
    deviceManagerService: deviceManagerService,
  );
  final webSocketServerService = WebSocketServerService(
    deviceManagerService: deviceManagerService,
    sessionManagerService: sessionManagerService,
    markService: markService,
    clipDownloaderService: clipDownloaderService,
    clipExplorerService: clipExplorerService,
    networkService: networkService,
  );

  // Create playback services
  final localPlaybackService = LocalPlaybackService();
  final remotePlaybackService = RemotePlaybackService(
    deviceManagerService: deviceManagerService,
  );

  // Wire up playback message callbacks
  webSocketServerService.onPlaybackReady = remotePlaybackService.handlePlaybackReady;
  webSocketServerService.onPlaybackStatus = remotePlaybackService.handlePlaybackStatus;
  webSocketServerService.onPlaybackStopped = remotePlaybackService.handlePlaybackStopped;
  webSocketServerService.onPlaybackError = remotePlaybackService.handlePlaybackError;

  // Initialize services
  await databaseService.database; // Ensure database is created
  await sessionManagerService.init();
  await clipDownloaderService.init();
  await clipExplorerService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ServerProvider(
            serverService: webSocketServerService,
            networkService: networkService,
            pairingService: pairingService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(
            deviceManagerService: deviceManagerService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            sessionManagerService: sessionManagerService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MarkProvider(
            markService: markService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ClipProvider(
            clipDownloaderService: clipDownloaderService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaybackProvider(
            localPlaybackService: localPlaybackService,
            remotePlaybackService: remotePlaybackService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ClipExplorerProvider(
            explorerService: clipExplorerService,
            deviceManagerService: deviceManagerService,
          ),
        ),
      ],
      child: const CoordinatorApp(),
    ),
  );
}

class CoordinatorApp extends StatelessWidget {
  const CoordinatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAR Coordinator',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const CoordinatorHome(),
    );
  }
}
