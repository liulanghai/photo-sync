import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/sync_provider.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoSyncMobileApp());
}

class PhotoSyncMobileApp extends StatelessWidget {
  const PhotoSyncMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = SyncProvider();
        // 延迟初始化，避免在 build 过程中抛异常
        Future.microtask(() => provider.initialize());
        return provider;
      },
      child: MaterialApp(
        title: 'PhotoSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const MobileHomePage(),
      ),
    );
  }
}
