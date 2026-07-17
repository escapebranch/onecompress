pub mod api;
mod frb_generated;

use image::codecs::jpeg::JpegEncoder;
use image::codecs::png::{CompressionType, FilterType, PngEncoder};
use image::{ColorType, DynamicImage, ImageEncoder, ImageFormat};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Clone, Copy)]
pub enum InternalOutputFormat {
    Jpeg,
    Png,
}

#[derive(Debug, Clone)]
pub struct InternalCompressionRequest {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub quality: u8,
    pub png_level: u8,
    pub max_long_edge: Option<u32>,
    pub output_format: InternalOutputFormat,
}

#[derive(Debug, Clone)]
pub struct InternalCompressionResponse {
    pub output_path: PathBuf,
    pub original_bytes: u64,
    pub compressed_bytes: u64,
}

#[derive(Debug, Error)]
pub enum ImageEngineError {
    #[error("unsupported image input")]
    UnsupportedInput,
    #[error("failed to decode image")]
    Decode,
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("image error: {0}")]
    Image(#[from] image::ImageError),
}

pub fn compress_image_internal(
    request: &InternalCompressionRequest,
) -> Result<InternalCompressionResponse, ImageEngineError> {
    let input_bytes = fs::read(&request.input_path)?;
    let original_bytes = input_bytes.len() as u64;
    let mut image =
        image::load_from_memory_with_format(&input_bytes, detect_format(&request.input_path)?)?;

    if let Some(max_long_edge) = request.max_long_edge {
        image = resize_if_needed(image, max_long_edge);
    }

    let encoded = match request.output_format {
        InternalOutputFormat::Jpeg => encode_jpeg(&image, request.quality)?,
        InternalOutputFormat::Png => encode_png(&image, request.png_level)?,
    };

    if let Some(parent) = request.output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(&request.output_path, &encoded)?;

    Ok(InternalCompressionResponse {
        output_path: request.output_path.clone(),
        original_bytes,
        compressed_bytes: encoded.len() as u64,
    })
}

fn detect_format(path: &Path) -> Result<ImageFormat, ImageEngineError> {
    match path
        .extension()
        .and_then(|value| value.to_str())
        .map(|value| value.to_ascii_lowercase())
        .as_deref()
    {
        Some("jpg") | Some("jpeg") => Ok(ImageFormat::Jpeg),
        Some("png") => Ok(ImageFormat::Png),
        _ => Err(ImageEngineError::UnsupportedInput),
    }
}

fn resize_if_needed(image: DynamicImage, max_long_edge: u32) -> DynamicImage {
    let width = image.width();
    let height = image.height();
    let long_edge = width.max(height);

    if long_edge <= max_long_edge {
        return image;
    }

    let scale = max_long_edge as f32 / long_edge as f32;
    let next_width = (width as f32 * scale).round() as u32;
    let next_height = (height as f32 * scale).round() as u32;
    image.resize(
        next_width,
        next_height,
        image::imageops::FilterType::Lanczos3,
    )
}

fn encode_jpeg(image: &DynamicImage, quality: u8) -> Result<Vec<u8>, ImageEngineError> {
    let rgb = image.to_rgb8();
    let mut output = Vec::new();
    let encoder = JpegEncoder::new_with_quality(&mut output, quality);
    encoder.write_image(
        rgb.as_raw(),
        rgb.width(),
        rgb.height(),
        ColorType::Rgb8.into(),
    )?;
    Ok(output)
}

fn encode_png(image: &DynamicImage, png_level: u8) -> Result<Vec<u8>, ImageEngineError> {
    let rgba = image.to_rgba8();
    let mut output = Vec::new();
    let encoder = PngEncoder::new_with_quality(
        &mut output,
        map_png_compression(png_level),
        FilterType::Adaptive,
    );
    encoder.write_image(
        rgba.as_raw(),
        rgba.width(),
        rgba.height(),
        ColorType::Rgba8.into(),
    )?;
    Ok(output)
}

fn map_png_compression(level: u8) -> CompressionType {
    match level {
        0..=3 => CompressionType::Fast,
        4..=6 => CompressionType::Default,
        _ => CompressionType::Best,
    }
}
