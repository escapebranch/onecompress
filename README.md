# OneCompress

OneCompress is a high performance cross-platform media compression application built with Flutter for the presentation layer and Rust for native FFI compression execution.

## Features

- High performance batch image compression for JPEG, PNG, and WebP formats
- Interactive before and after image comparison preview slider
- Granular single image tuning and re-compression
- Custom presets for quality, format conversion, and dimension resizing
- Background multi-threaded isolate execution via Rust FFI
- Graceful automatic fallback to Dart raster engine if native binaries are absent
- Direct gallery integration for saving compressed artifacts

## Architecture

The project follows Clean Architecture principles, isolating UI, domain business logic, and data sources:

```text
lib/
  app/                        App configuration and dependency root
  core/                       Theme tokens, shared utilities, core components
  features/
    image_compression/
      application/            Dependency injection and binding
      data/                   File picker, FFI native engine, gallery saver
      domain/                 Entities, use cases, repository interfaces
      presentation/           Controllers, screens, interactive widgets

rust/
  image_engine/               High performance Rust compression engine
```

## Native Engine Bridge

The Rust core is integrated using flutter_rust_bridge and native FFI:

- Android: Packaged native libraries per ABI (.so) in jniLibs
- iOS and macOS: Statically linked native library (.a)
- Desktop (Linux and Windows): Dynamically linked engine library (.so / .dll)

If native libraries are unavailable, the application seamlessly falls back to a pure Dart implementation without interrupting the user workflow.

## Getting Started

1. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Build local Rust engine for desktop development:
   ```bash
   make rust-engine-debug
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## Native Build Prerequisites

To compile native Rust binaries for target platforms, ensure required target toolchains are installed:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
rustup target add aarch64-apple-darwin x86_64-apple-darwin
```
