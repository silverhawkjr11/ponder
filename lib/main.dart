import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/stats.dart';
import 'theme/palette.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final stats = await Stats.load();
  themeController.palette = Palette.byName(stats.themeName);
  runApp(DotsApp(stats: stats));
}

class DotsApp extends StatelessWidget {
  final Stats stats;
  const DotsApp({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final p = Pal.p;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: p.light ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: p.base,
            systemNavigationBarIconBrightness: p.light ? Brightness.dark : Brightness.light,
          ),
        );
        return MaterialApp(
          key: ValueKey(p.name),
          title: 'Ponder',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(p),
          home: HomeScreen(stats: stats),
        );
      },
    );
  }
}
