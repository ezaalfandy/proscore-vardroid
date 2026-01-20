import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'providers/preview_provider.dart';
import 'providers/recording_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider()..init(),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, PreviewProvider>(
          create: (_) => PreviewProvider(),
          update: (context, connection, previous) {
            final provider = previous ?? PreviewProvider();
            provider.attachConnection(connection.wsService);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, RecordingProvider>(
          create: (context) => RecordingProvider(
            context.read<ConnectionProvider>(),
          ),
          update: (context, connection, previous) =>
              previous ?? RecordingProvider(connection),
        ),
      ],
      child: MaterialApp(
        title: 'VAR Camera Node',
        theme: AppTheme.dark(),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
