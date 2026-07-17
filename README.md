# OneCompress

OneCompress is a cross-platform compression app built with Flutter for the product layer and Rust for the long-term compression engine. The repo is structured around Clean Architecture so UI, orchestration, and compression logic can evolve independently as new formats are added.

## Phase 1

The first production module focuses on image compression with:

- multi-image selection
- queue previews
- preset and custom quality controls
- batch compression progress
- original vs compressed size comparison
- save and share actions
- graceful failure messaging

Current image support in this milestone is `JPEG` and `PNG`. The architecture is intentionally wider than the first feature so future video, audio, PDF, archive, and metadata workflows can reuse the same app shell and domain boundaries.

## Project Structure

```text
lib/
  app/                        App bootstrap and composition root
  core/                       Theme, shared helpers, reusable widgets
  features/
    image_compression/
      application/            Dependency wiring
      data/                   File picker, compression engine, sharing
      domain/                 Entities, repository contracts, use cases
      presentation/           Controller, page, widgets

rust/
  image_engine/               Native compression crate for future FFI
```

## Rust Engine

`rust/image_engine` contains the native image compression core and mirrors the same concepts used by the Flutter feature module. The app currently ships with a Dart-backed raster implementation to keep the UI flow functional immediately, while the Rust crate establishes the engine contract for the next integration step.

## Flutter-Rust Bridge

The project now includes a native FFI bridge for Flutter's native platforms:

- Flutter prefers the Rust engine through `dart:ffi`
- compression runs in a background isolate to avoid blocking the UI thread
- if the Rust dynamic library is missing, unsupported, or fails at runtime, the app falls back to the Dart raster engine automatically

The native loading strategy is now split by platform family:

- Android: packaged `libimage_engine.so` per ABI in `jniLibs`
- iOS: statically linked `libimage_engine.a`, loaded with `DynamicLibrary.process()`
- macOS: statically linked `libimage_engine.a`, loaded with `DynamicLibrary.process()`
- Linux: bundled `libimage_engine.so`
- Windows: bundled `image_engine.dll`

The desktop bridge looks in:

- `ONECOMPRESS_IMAGE_ENGINE_LIB` if you set it
- the current working directory
- the executable directory
- `rust/image_engine/target/debug`
- `rust/image_engine/target/release`

That gives us a real Rust-backed engine across Flutter's native targets while still keeping a Dart fallback for unsupported or failed native loads.

## Getting Started

1. Run `flutter pub get`
2. For desktop-only local work, run `make rust-engine-debug`
3. Run `flutter run`

## Native Platform Notes

- Android builds automatically call `tool/build_rust_android.sh` before `preBuild` and package ABI-specific `.so` files into `android/app/src/main/jniLibs`
- iOS builds call `tool/build_rust_apple.sh ios` from the Xcode build phase and link a generated static library through `ios/Flutter/Rust.xcconfig`
- macOS builds call `tool/build_rust_apple.sh macos` from the Flutter assemble phase and link a generated static library through `macos/Runner/Configs/Rust.xcconfig`
- Linux and Windows desktop builds invoke `cargo build` from their CMake entrypoints and bundle the produced Rust library next to the Flutter app

Before building mobile or Apple desktop targets, install the Rust targets you need:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
rustup target add aarch64-apple-darwin x86_64-apple-darwin
```

If you want to force a specific dynamic library path during Linux or Windows desktop development:

```bash
export ONECOMPRESS_IMAGE_ENGINE_LIB="$PWD/rust/image_engine/target/debug/libimage_engine.so"
```

On Windows, use `image_engine.dll`.

## Next Steps

- add CI automation for Rust target installation and native artifact builds
- add background job orchestration for large batches
- add module packages for video, audio, PDF, and archive compression
- persist recent jobs and output preferences
