# Dots

A clean, ad-free connect-the-dots (flow) puzzle for Android in the Catppuccin Mocha palette.

Connect every pair of matching dots with a pipe and fill every cell. Levels are generated
randomly per difficulty, and each one shows its seed so you can replay it.

| Difficulty | Grid         |
|------------|--------------|
| Easy       | 5×5, 6×6     |
| Medium     | 7×7, 8×8     |
| Hard       | 9×9, 10×10   |
| Expert     | 11×11, 12×12 |

## Build

```
flutter pub get
flutter test
flutter build apk --release
```

Layout: `lib/game` (level model, generator, board logic), `lib/ui` (screens, painter, effects),
`lib/theme` (Mocha palette), `lib/services` (stats persistence).
