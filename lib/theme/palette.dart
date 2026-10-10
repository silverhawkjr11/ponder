import 'package:flutter/material.dart';

/// One Catppuccin flavour.
class Palette {
  final String name;
  final bool light;
  final Color rosewater, flamingo, pink, mauve, red, maroon, peach, yellow;
  final Color green, teal, sky, sapphire, blue, lavender;
  final Color text, subtext1, subtext0, overlay2, overlay1, overlay0;
  final Color surface2, surface1, surface0, base, mantle, crust;

  const Palette({
    required this.name,
    this.light = false,
    required this.rosewater,
    required this.flamingo,
    required this.pink,
    required this.mauve,
    required this.red,
    required this.maroon,
    required this.peach,
    required this.yellow,
    required this.green,
    required this.teal,
    required this.sky,
    required this.sapphire,
    required this.blue,
    required this.lavender,
    required this.text,
    required this.subtext1,
    required this.subtext0,
    required this.overlay2,
    required this.overlay1,
    required this.overlay0,
    required this.surface2,
    required this.surface1,
    required this.surface0,
    required this.base,
    required this.mantle,
    required this.crust,
  });

  /// Accent colours for dot pairs, ordered so neighbours stay distinct.
  List<Color> get flows => [
    red, blue, green, yellow, mauve, peach, teal, pink,
    sapphire, maroon, lavender, sky, rosewater, flamingo,
  ];

  static const mocha = Palette(
    name: 'Mocha',
    rosewater: Color(0xFFF5E0DC), flamingo: Color(0xFFF2CDCD), pink: Color(0xFFF5C2E7),
    mauve: Color(0xFFCBA6F7), red: Color(0xFFF38BA8), maroon: Color(0xFFEBA0AC),
    peach: Color(0xFFFAB387), yellow: Color(0xFFF9E2AF), green: Color(0xFFA6E3A1),
    teal: Color(0xFF94E2D5), sky: Color(0xFF89DCEB), sapphire: Color(0xFF74C7EC),
    blue: Color(0xFF89B4FA), lavender: Color(0xFFB4BEFE),
    text: Color(0xFFCDD6F4), subtext1: Color(0xFFBAC2DE), subtext0: Color(0xFFA6ADC8),
    overlay2: Color(0xFF9399B2), overlay1: Color(0xFF7F849C), overlay0: Color(0xFF6C7086),
    surface2: Color(0xFF585B70), surface1: Color(0xFF45475A), surface0: Color(0xFF313244),
    base: Color(0xFF1E1E2E), mantle: Color(0xFF181825), crust: Color(0xFF11111B),
  );

  static const macchiato = Palette(
    name: 'Macchiato',
    rosewater: Color(0xFFF4DBD6), flamingo: Color(0xFFF0C6C6), pink: Color(0xFFF5BDE6),
    mauve: Color(0xFFC6A0F6), red: Color(0xFFED8796), maroon: Color(0xFFEE99A0),
    peach: Color(0xFFF5A97F), yellow: Color(0xFFEED49F), green: Color(0xFFA6DA95),
    teal: Color(0xFF8BD5CA), sky: Color(0xFF91D7E3), sapphire: Color(0xFF7DC4E4),
    blue: Color(0xFF8AADF4), lavender: Color(0xFFB7BDF8),
    text: Color(0xFFCAD3F5), subtext1: Color(0xFFB8C0E0), subtext0: Color(0xFFA5ADCB),
    overlay2: Color(0xFF939AB7), overlay1: Color(0xFF8087A2), overlay0: Color(0xFF6E738D),
    surface2: Color(0xFF5B6078), surface1: Color(0xFF494D64), surface0: Color(0xFF363A4F),
    base: Color(0xFF24273A), mantle: Color(0xFF1E2030), crust: Color(0xFF181926),
  );

  static const frappe = Palette(
    name: 'Frappé',
    rosewater: Color(0xFFF2D5CF), flamingo: Color(0xFFEEBEBE), pink: Color(0xFFF4B8E4),
    mauve: Color(0xFFCA9EE6), red: Color(0xFFE78284), maroon: Color(0xFFEA999C),
    peach: Color(0xFFEF9F76), yellow: Color(0xFFE5C890), green: Color(0xFFA6D189),
    teal: Color(0xFF81C8BE), sky: Color(0xFF99D1DB), sapphire: Color(0xFF85C1DC),
    blue: Color(0xFF8CAAEE), lavender: Color(0xFFBABBF1),
    text: Color(0xFFC6D0F5), subtext1: Color(0xFFB5BFE2), subtext0: Color(0xFFA5ADCE),
    overlay2: Color(0xFF949CBB), overlay1: Color(0xFF838BA7), overlay0: Color(0xFF737994),
    surface2: Color(0xFF626880), surface1: Color(0xFF51576D), surface0: Color(0xFF414559),
    base: Color(0xFF303446), mantle: Color(0xFF292C3C), crust: Color(0xFF232634),
  );

  static const latte = Palette(
    name: 'Latte',
    light: true,
    rosewater: Color(0xFFDC8A78), flamingo: Color(0xFFDD7878), pink: Color(0xFFEA76CB),
    mauve: Color(0xFF8839EF), red: Color(0xFFD20F39), maroon: Color(0xFFE64553),
    peach: Color(0xFFFE640B), yellow: Color(0xFFDF8E1D), green: Color(0xFF40A02B),
    teal: Color(0xFF179299), sky: Color(0xFF04A5E5), sapphire: Color(0xFF209FB5),
    blue: Color(0xFF1E66F5), lavender: Color(0xFF7287FD),
    text: Color(0xFF4C4F69), subtext1: Color(0xFF5C5F77), subtext0: Color(0xFF6C6F85),
    overlay2: Color(0xFF7C7F93), overlay1: Color(0xFF8C8FA1), overlay0: Color(0xFF9CA0B0),
    surface2: Color(0xFFACB0BE), surface1: Color(0xFFBCC0CC), surface0: Color(0xFFCCD0DA),
    base: Color(0xFFEFF1F5), mantle: Color(0xFFE6E9EF), crust: Color(0xFFDCE0E8),
  );

  static const all = [mocha, macchiato, frappe, latte];

  static Palette byName(String? n) =>
      all.firstWhere((p) => p.name == n, orElse: () => mocha);
}

/// Holds the active flavour. Widgets read colours through [Pal].
class ThemeController extends ChangeNotifier {
  Palette _palette = Palette.mocha;
  Palette get palette => _palette;
  set palette(Palette p) {
    if (p == _palette) return;
    _palette = p;
    notifyListeners();
  }
}

final themeController = ThemeController();

/// Static accessors for the current palette, so call sites stay short.
abstract final class Pal {
  static Palette get p => themeController.palette;
  static Color get rosewater => p.rosewater;
  static Color get flamingo => p.flamingo;
  static Color get pink => p.pink;
  static Color get mauve => p.mauve;
  static Color get red => p.red;
  static Color get maroon => p.maroon;
  static Color get peach => p.peach;
  static Color get yellow => p.yellow;
  static Color get green => p.green;
  static Color get teal => p.teal;
  static Color get sky => p.sky;
  static Color get sapphire => p.sapphire;
  static Color get blue => p.blue;
  static Color get lavender => p.lavender;
  static Color get text => p.text;
  static Color get subtext1 => p.subtext1;
  static Color get subtext0 => p.subtext0;
  static Color get overlay2 => p.overlay2;
  static Color get overlay1 => p.overlay1;
  static Color get overlay0 => p.overlay0;
  static Color get surface2 => p.surface2;
  static Color get surface1 => p.surface1;
  static Color get surface0 => p.surface0;
  static Color get base => p.base;
  static Color get mantle => p.mantle;
  static Color get crust => p.crust;
  static List<Color> get flows => p.flows;
}

ThemeData buildTheme(Palette p) {
  final scheme = ColorScheme(
    brightness: p.light ? Brightness.light : Brightness.dark,
    primary: p.mauve,
    onPrimary: p.crust,
    secondary: p.blue,
    onSecondary: p.crust,
    error: p.red,
    onError: p.crust,
    surface: p.base,
    onSurface: p.text,
    surfaceContainerHighest: p.surface0,
    outline: p.surface1,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.base,
    fontFamily: 'Nunito',
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.subtext1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surface0,
      contentTextStyle: TextStyle(
        color: p.text,
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
