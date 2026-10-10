# Ponder

Four clean, ad-free puzzles for Android in the Catppuccin palettes: Flow (connect the dots), Zip (one path through every cell), Chess puzzles (Lichess database, CC0) and Sudoku. Games autosave and can be resumed from the home screen; Mocha, Macchiato, Frappé and Latte themes.

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

## Chess engine

Play mode uses Stockfish 11 (GPLv3), vendored under `third_party/stockfish` with the Flutter FFI
bridge from the `stockfish` pub package, compiled for arm64 only. Stockfish 11 is the last classical
evaluation release, so no neural network file is bundled and the library is about 1 MB.
