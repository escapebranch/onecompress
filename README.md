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

## Getting Started

1. Run `flutter pub get`
2. Run `cargo check --manifest-path rust/image_engine/Cargo.toml`
3. Run `flutter run`

## Next Steps

- connect Flutter to the Rust crate through an FFI bridge
- add background job orchestration for large batches
- add module packages for video, audio, PDF, and archive compression
- persist recent jobs and output preferences
