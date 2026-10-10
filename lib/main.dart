import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/stats.dart';
import 'theme/mocha.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Mocha.base,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final stats = await Stats.load();
  runApp(DotsApp(stats: stats));
}

class DotsApp extends StatelessWidget {
  final Stats stats;
  const DotsApp({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dots',
      debugShowCheckedModeBanner: false,
      theme: buildMochaTheme(),
      home: HomeScreen(stats: stats),
    );
  }
}
