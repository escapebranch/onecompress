pub mod api;
mod frb_generated;

use image::codecs::jpeg::JpegEncoder;
use image::codecs::png::{CompressionType, FilterType, PngEncoder};
use image::codecs::webp::WebPEncoder;
use image::{ColorType, DynamicImage, ImageEncoder, ImageFormat, ImageReader};
use std::fs;
use std::io::{BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::time::Instant;
use thiserror::Error;

#[allow(unused_imports)]
use log::{debug, error, info, warn};

// ─── Core Error Type ──────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum ImageEngineError {
    #[error("unsupported image input format")]
    UnsupportedInput,
    #[error("failed to decode image: {0}")]
    Decode(String),
    #[error("failed to encode image: {0}")]
    Encode(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("image processing error: {0}")]
    Image(#[from] image::ImageError),
}

// ─── Public API Types (internal) ──────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InternalOutputFormat {
    Jpeg,
    Png,
    Webp,
    Auto,
}

#[derive(Debug, Clone)]
pub enum InternalResizeMode {
    None,
    MaxLongEdge { value: u32 },
    ExactSize {
        width: u32,
        height: u32,
        keep_aspect_ratio: bool,
    },
    ScalePercentage { percentage: f32 },
}

#[derive(Debug, Clone)]
pub struct InternalCompressionRequest {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub quality: u8,
    pub png_level: u8,
    pub resize_mode: InternalResizeMode,
    pub output_format: InternalOutputFormat,
}

#[derive(Debug, Clone)]
pub struct InternalCompressionResponse {
    pub output_path: PathBuf,
    pub original_bytes: u64,
    pub compressed_bytes: u64,
    pub width: u32,
    pub height: u32,
    pub format: String,
}

// ─── I/O Buffer Tuning ────────────────────────────────────────────────────────
// 256 KB read buffer: large images (4–20 MB) benefit from fewer syscalls.
// Write buffer matches: encoder flushes in large chunks.
const READ_BUFFER: usize = 256 * 1024;
const WRITE_BUFFER: usize = 256 * 1024;

// ─── Core Compression Pipeline ────────────────────────────────────────────────

pub fn compress_image_internal(
    request: &InternalCompressionRequest,
) -> Result<InternalCompressionResponse, ImageEngineError> {
    let pipeline_start = Instant::now();
    let file_name = request.input_path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| request.input_path.to_string_lossy().into_owned());

    // [1/6] Stat
    let original_bytes = fs::metadata(&request.input_path)?.len();
    info!("[compress] START file={} original_size={} bytes", file_name, original_bytes);

    // [2/6] Open + format detection
    let t = Instant::now();
    let mut input_file = fs::File::open(&request.input_path)?;
    let format = detect_format_with_magic_bytes(&mut input_file, &request.input_path)?;
    info!("[compress] FORMAT_DETECT file={} detected={:?} elapsed={}us", file_name, format, t.elapsed().as_micros());

    // [3/6] Decode
    let t = Instant::now();
    input_file.seek(SeekFrom::Start(0))?;
    let buffered_reader = BufReader::with_capacity(READ_BUFFER, input_file);
    let image = ImageReader::with_format(buffered_reader, format)
        .decode()
        .map_err(|e| {
            error!("[compress] DECODE_FAILED file={} error={}", file_name, e);
            ImageEngineError::Decode(e.to_string())
        })?;
    info!(
        "[compress] DECODE file={} dims={}x{} color={:?} elapsed={}ms",
        file_name, image.width(), image.height(), image.color(), t.elapsed().as_millis()
    );

    // [4/6] Color space + resize
    let target_format = resolve_target_format(request.output_format, format);
    let image = pre_convert_color_space(image, target_format);

    let pre_resize_w = image.width();
    let pre_resize_h = image.height();
    let t = Instant::now();
    let image = apply_resize(image, &request.resize_mode);
    let post_resize_w = image.width();
    let post_resize_h = image.height();
    if pre_resize_w != post_resize_w || pre_resize_h != post_resize_h {
        info!(
            "[compress] RESIZE file={} from={}x{} to={}x{} mode={:?} elapsed={}ms",
            file_name, pre_resize_w, pre_resize_h, post_resize_w, post_resize_h,
            request.resize_mode, t.elapsed().as_millis()
        );
    } else {
        info!("[compress] RESIZE_SKIPPED file={} dims={}x{} (already within bounds)", file_name, pre_resize_w, pre_resize_h);
    }

    // [5/6] Encode
    if let Some(parent) = request.output_path.parent() {
        fs::create_dir_all(parent)?;
    }
    let output_file = fs::File::create(&request.output_path)?;
    let mut buffered_writer = BufWriter::with_capacity(WRITE_BUFFER, output_file);
    let final_width = image.width();
    let final_height = image.height();

    let t = Instant::now();
    match target_format {
        InternalOutputFormat::Jpeg => {
            info!("[compress] ENCODE_JPEG file={} quality={}", file_name, request.quality);
            encode_jpeg(image, request.quality, &mut buffered_writer)?;
        }
        InternalOutputFormat::Png => {
            info!("[compress] ENCODE_PNG file={} level={}", file_name, request.png_level);
            encode_png(image, request.png_level, &mut buffered_writer)?;
        }
        InternalOutputFormat::Webp => {
            info!("[compress] ENCODE_WEBP file={}", file_name);
            encode_webp(image, &mut buffered_writer)?;
        }
        InternalOutputFormat::Auto => {
            info!("[compress] ENCODE_JPEG(auto) file={} quality={}", file_name, request.quality);
            encode_jpeg(image, request.quality, &mut buffered_writer)?;
        }
    }
    let encode_ms = t.elapsed().as_millis();

    // [6/6] Flush + measure
    buffered_writer.flush()?;
    let compressed_bytes = fs::metadata(&request.output_path)?.len();
    let savings_pct = if original_bytes > 0 {
        100.0 - (compressed_bytes as f64 / original_bytes as f64 * 100.0)
    } else {
        0.0
    };

    let format_str = match target_format {
        InternalOutputFormat::Jpeg => "jpeg",
        InternalOutputFormat::Png => "png",
        InternalOutputFormat::Webp => "webp",
        InternalOutputFormat::Auto => "jpeg",
    }
    .to_string();

    info!(
        "[compress] DONE file={} format={} dims={}x{} original={}B compressed={}B saved={:.1}% encode={}ms total={}ms",
        file_name, format_str, final_width, final_height,
        original_bytes, compressed_bytes, savings_pct,
        encode_ms, pipeline_start.elapsed().as_millis()
    );

    Ok(InternalCompressionResponse {
        output_path: request.output_path.clone(),
        original_bytes,
        compressed_bytes,
        width: final_width,
        height: final_height,
        format: format_str,
    })
}

// ─── Format Detection (Magic Bytes) ───────────────────────────────────────────

fn detect_format_with_magic_bytes(
    file: &mut fs::File,
    path: &Path,
) -> Result<ImageFormat, ImageEngineError> {
    let mut header = [0u8; 12];
    let bytes_read = file.read(&mut header).unwrap_or(0);

    // JPEG: FF D8 FF
    if bytes_read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
        return Ok(ImageFormat::Jpeg);
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if bytes_read >= 8
        && header[0] == 0x89
        && header[1] == 0x50
        && header[2] == 0x4E
        && header[3] == 0x47
        && header[4] == 0x0D
        && header[5] == 0x0A
        && header[6] == 0x1A
        && header[7] == 0x0A
    {
        return Ok(ImageFormat::Png);
    }

    // WebP: RIFF....WEBP
    if bytes_read >= 12 && &header[0..4] == b"RIFF" && &header[8..12] == b"WEBP" {
        return Ok(ImageFormat::WebP);
    }

    // Extension fallback
    match path
        .extension()
        .and_then(|v| v.to_str())
        .map(|v| v.to_ascii_lowercase())
        .as_deref()
    {
        Some("jpg") | Some("jpeg") => Ok(ImageFormat::Jpeg),
        Some("png") => Ok(ImageFormat::Png),
        Some("webp") => Ok(ImageFormat::WebP),
        _ => Err(ImageEngineError::UnsupportedInput),
    }
}

// ─── Target Format Resolution ─────────────────────────────────────────────────

#[inline(always)]
fn resolve_target_format(
    output_format: InternalOutputFormat,
    input_format: ImageFormat,
) -> InternalOutputFormat {
    match output_format {
        InternalOutputFormat::Auto => match input_format {
            ImageFormat::Png => InternalOutputFormat::Png,
            ImageFormat::WebP => InternalOutputFormat::Webp,
            _ => InternalOutputFormat::Jpeg,
        },
        other => other,
    }
}

// ─── Pre-Convert Color Space ───────────────────────────────────────────────────
// Doing color space conversion once, BEFORE resize, means:
//  • Resize operates on the final pixel format (no wasted pixels).
//  • JPEG encoder gets plain RGB8 (no alpha strip = no extra allocation).
//  • WebP/PNG get RGBA8.

#[inline(always)]
fn pre_convert_color_space(image: DynamicImage, target: InternalOutputFormat) -> DynamicImage {
    match target {
        // JPEG cannot encode alpha; strip to RGB8 now.
        InternalOutputFormat::Jpeg | InternalOutputFormat::Auto => {
            if image.color().has_alpha() {
                DynamicImage::ImageRgb8(image.into_rgb8())
            } else {
                image
            }
        }
        // PNG & WebP support alpha; keep RGBA8.
        InternalOutputFormat::Png | InternalOutputFormat::Webp => {
            if image.color().channel_count() < 4 {
                DynamicImage::ImageRgba8(image.into_rgba8())
            } else {
                image
            }
        }
    }
}

// ─── Resize ───────────────────────────────────────────────────────────────────
// CatmullRom (bicubic) = best quality-to-speed ratio for downscaling.
// Lanczos3 is sharper but ~3x slower — not worth it for compression output.
// Triangle (bilinear) is faster but visibly blurrier on text/fine detail.

fn apply_resize(image: DynamicImage, mode: &InternalResizeMode) -> DynamicImage {
    let width = image.width();
    let height = image.height();

    if width == 0 || height == 0 {
        return image;
    }

    match mode {
        InternalResizeMode::None => image,
        InternalResizeMode::MaxLongEdge { value } => {
            let max_long_edge = *value;
            let long_edge = width.max(height);
            // Skip resize if already within bounds (common case, zero allocation)
            if long_edge <= max_long_edge {
                return image;
            }
            let scale = max_long_edge as f64 / long_edge as f64;
            let next_width = ((width as f64 * scale).round() as u32).max(1);
            let next_height = ((height as f64 * scale).round() as u32).max(1);
            image.resize(next_width, next_height, image::imageops::FilterType::CatmullRom)
        }
        InternalResizeMode::ExactSize {
            width: target_width,
            height: target_height,
            keep_aspect_ratio,
        } => {
            let target_w = (*target_width).max(1);
            let target_h = (*target_height).max(1);
            if *keep_aspect_ratio {
                image.resize(target_w, target_h, image::imageops::FilterType::CatmullRom)
            } else {
                image.resize_exact(target_w, target_h, image::imageops::FilterType::CatmullRom)
            }
        }
        InternalResizeMode::ScalePercentage { percentage } => {
            let scale = (*percentage as f64 / 100.0).max(0.01);
            let next_width = ((width as f64 * scale).round() as u32).max(1);
            let next_height = ((height as f64 * scale).round() as u32).max(1);
            image.resize(next_width, next_height, image::imageops::FilterType::CatmullRom)
        }
    }
}

// ─── JPEG Encoder ─────────────────────────────────────────────────────────────
// The `image` crate's JPEG encoder wraps zune-jpeg (pure-Rust, SIMD on x86/ARM).
// No additional tuning needed; quality is the single control knob.

fn encode_jpeg<W: Write>(
    image: DynamicImage,
    quality: u8,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    // image was pre-converted to RGB8 in pre_convert_color_space — no-op branch.
    let rgb = image.into_rgb8();
    let encoder = JpegEncoder::new_with_quality(writer, quality);
    encoder
        .write_image(rgb.as_raw(), rgb.width(), rgb.height(), ColorType::Rgb8.into())
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

// ─── PNG Encoder ──────────────────────────────────────────────────────────────
// Strategy:
//  • Fast (level 0-3): CompressionType::Fast + FilterType::Sub
//    → Fastest possible path. Sub filter is O(1) per pixel, Fast deflate.
//  • Balanced (level 4-6): CompressionType::Default + FilterType::Sub
//    → Good compression, still quick. Adaptive filter scans 5 variants per row
//    which is 5x slower for the filter pass alone.
//  • Best (level 7+): CompressionType::Best + FilterType::Adaptive
//    → Squeeze every byte. Used only when user explicitly wants max compression.

fn encode_png<W: Write>(
    image: DynamicImage,
    png_level: u8,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    let rgba = image.into_rgba8();
    let (compression, filter) = match png_level {
        0..=3 => (CompressionType::Fast, FilterType::Sub),
        4..=6 => (CompressionType::Default, FilterType::Sub),
        _ => (CompressionType::Best, FilterType::Adaptive),
    };
    let encoder = PngEncoder::new_with_quality(writer, compression, filter);
    encoder
        .write_image(rgba.as_raw(), rgba.width(), rgba.height(), ColorType::Rgba8.into())
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

// ─── WebP Encoder ─────────────────────────────────────────────────────────────
// The `image` crate v0.25 only provides a lossless WebP encoder.
// WebP lossless on photographic images produces files LARGER than JPEG,
// but is ideal for graphics, illustrations, and screenshots (perfect quality).
//
// For compression-focused use the user should choose JPEG or Auto.
// WebP is offered as a "maximum quality" format for graphics workflows.

fn encode_webp<W: Write>(
    image: DynamicImage,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    let rgba = image.into_rgba8();
    let encoder = WebPEncoder::new_lossless(writer);
    encoder
        .write_image(rgba.as_raw(), rgba.width(), rgba.height(), ColorType::Rgba8.into())
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

