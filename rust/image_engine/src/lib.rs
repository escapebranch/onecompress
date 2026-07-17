pub mod api;
mod frb_generated;

use image::codecs::jpeg::JpegEncoder;
use image::codecs::png::{CompressionType, FilterType, PngEncoder};
use image::codecs::webp::WebPEncoder;
use image::{ColorType, DynamicImage, ImageEncoder, ImageFormat, ImageReader};
use std::fs;
use std::io::{BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use thiserror::Error;

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

const BUFFER_CAPACITY: usize = 64 * 1024; // 64 KB I/O buffer

pub fn compress_image_internal(
    request: &InternalCompressionRequest,
) -> Result<InternalCompressionResponse, ImageEngineError> {
    let original_bytes = fs::metadata(&request.input_path)?.len();

    let mut input_file = fs::File::open(&request.input_path)?;
    let format = detect_format_with_magic_bytes(&mut input_file, &request.input_path)?;

    input_file.seek(SeekFrom::Start(0))?;
    let buffered_reader = BufReader::with_capacity(BUFFER_CAPACITY, input_file);

    let mut image = ImageReader::with_format(buffered_reader, format)
        .decode()
        .map_err(|e| ImageEngineError::Decode(e.to_string()))?;

    image = apply_resize(image, &request.resize_mode);

    let target_format = match request.output_format {
        InternalOutputFormat::Jpeg => InternalOutputFormat::Jpeg,
        InternalOutputFormat::Png => InternalOutputFormat::Png,
        InternalOutputFormat::Webp => InternalOutputFormat::Webp,
        InternalOutputFormat::Auto => match format {
            ImageFormat::Png => InternalOutputFormat::Png,
            ImageFormat::WebP => InternalOutputFormat::Webp,
            _ => InternalOutputFormat::Jpeg,
        },
    };

    if let Some(parent) = request.output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let output_file = fs::File::create(&request.output_path)?;
    let mut buffered_writer = BufWriter::with_capacity(BUFFER_CAPACITY, output_file);

    let final_width = image.width();
    let final_height = image.height();

    match target_format {
        InternalOutputFormat::Jpeg => encode_jpeg(image, request.quality, &mut buffered_writer)?,
        InternalOutputFormat::Png => encode_png(image, request.png_level, &mut buffered_writer)?,
        InternalOutputFormat::Webp => encode_webp(image, &mut buffered_writer)?,
        InternalOutputFormat::Auto => encode_jpeg(image, request.quality, &mut buffered_writer)?,
    }

    buffered_writer.flush()?;

    let compressed_bytes = fs::metadata(&request.output_path)?.len();

    let format_str = match target_format {
        InternalOutputFormat::Jpeg => "jpeg",
        InternalOutputFormat::Png => "png",
        InternalOutputFormat::Webp => "webp",
        InternalOutputFormat::Auto => "jpeg",
    }
    .to_string();

    Ok(InternalCompressionResponse {
        output_path: request.output_path.clone(),
        original_bytes,
        compressed_bytes,
        width: final_width,
        height: final_height,
        format: format_str,
    })
}

fn detect_format_with_magic_bytes(
    file: &mut fs::File,
    path: &Path,
) -> Result<ImageFormat, ImageEngineError> {
    let mut header = [0u8; 12];
    let bytes_read = file.read(&mut header).unwrap_or(0);

    if bytes_read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
        return Ok(ImageFormat::Jpeg);
    }

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

    if bytes_read >= 12 && &header[0..4] == b"RIFF" && &header[8..12] == b"WEBP" {
        return Ok(ImageFormat::WebP);
    }

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
            if long_edge <= max_long_edge {
                return image;
            }
            let scale = max_long_edge as f32 / long_edge as f32;
            let next_width = ((width as f32 * scale).round() as u32).max(1);
            let next_height = ((height as f32 * scale).round() as u32).max(1);
            image.resize(
                next_width,
                next_height,
                image::imageops::FilterType::Triangle,
            )
        }
        InternalResizeMode::ExactSize {
            width: target_width,
            height: target_height,
            keep_aspect_ratio,
        } => {
            let target_w = (*target_width).max(1);
            let target_h = (*target_height).max(1);
            if *keep_aspect_ratio {
                image.resize(
                    target_w,
                    target_h,
                    image::imageops::FilterType::Triangle,
                )
            } else {
                image.resize_exact(
                    target_w,
                    target_h,
                    image::imageops::FilterType::Triangle,
                )
            }
        }
        InternalResizeMode::ScalePercentage { percentage } => {
            let scale = (percentage / 100.0).max(0.01);
            let next_width = ((width as f32 * scale).round() as u32).max(1);
            let next_height = ((height as f32 * scale).round() as u32).max(1);
            image.resize(
                next_width,
                next_height,
                image::imageops::FilterType::Triangle,
            )
        }
    }
}

fn encode_jpeg<W: Write>(
    image: DynamicImage,
    quality: u8,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    let rgb = image.into_rgb8();
    let encoder = JpegEncoder::new_with_quality(writer, quality);
    encoder
        .write_image(
            rgb.as_raw(),
            rgb.width(),
            rgb.height(),
            ColorType::Rgb8.into(),
        )
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

fn encode_png<W: Write>(
    image: DynamicImage,
    png_level: u8,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    let rgba = image.into_rgba8();
    let encoder = PngEncoder::new_with_quality(
        writer,
        map_png_compression(png_level),
        FilterType::Adaptive,
    );
    encoder
        .write_image(
            rgba.as_raw(),
            rgba.width(),
            rgba.height(),
            ColorType::Rgba8.into(),
        )
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

fn encode_webp<W: Write>(
    image: DynamicImage,
    writer: &mut W,
) -> Result<(), ImageEngineError> {
    let rgba = image.into_rgba8();
    let encoder = WebPEncoder::new_lossless(writer);
    encoder
        .write_image(
            rgba.as_raw(),
            rgba.width(),
            rgba.height(),
            ColorType::Rgba8.into(),
        )
        .map_err(|e| ImageEngineError::Encode(e.to_string()))?;
    Ok(())
}

fn map_png_compression(level: u8) -> CompressionType {
    match level {
        0..=3 => CompressionType::Fast,
        4..=6 => CompressionType::Default,
        _ => CompressionType::Best,
    }
}
