use std::path::PathBuf;
use rayon::prelude::*;
use crate::compress_image_internal;

#[derive(Debug, Clone, Copy)]
pub enum OutputFormat {
    Jpeg,
    Png,
}

#[derive(Debug, Clone)]
pub struct CompressionRequest {
    pub input_path: String,
    pub output_path: String,
    pub quality: u8,
    pub png_level: u8,
    pub max_long_edge: Option<u32>,
    pub output_format: OutputFormat,
}

#[derive(Debug, Clone)]
pub struct CompressionResponse {
    pub output_path: String,
    pub original_bytes: u64,
    pub compressed_bytes: u64,
}

pub fn compress_image(request: CompressionRequest) -> Result<CompressionResponse, String> {
    let internal_request = crate::InternalCompressionRequest {
        input_path: PathBuf::from(request.input_path),
        output_path: PathBuf::from(request.output_path),
        quality: quality_clamp(request.quality),
        png_level: request.png_level,
        max_long_edge: request.max_long_edge,
        output_format: match request.output_format {
            OutputFormat::Jpeg => crate::InternalOutputFormat::Jpeg,
            OutputFormat::Png => crate::InternalOutputFormat::Png,
        },
    };

    let response = compress_image_internal(&internal_request).map_err(|e| e.to_string())?;

    Ok(CompressionResponse {
        output_path: response.output_path.to_string_lossy().into_owned(),
        original_bytes: response.original_bytes,
        compressed_bytes: response.compressed_bytes,
    })
}

pub fn compress_images_batch(
    requests: Vec<CompressionRequest>,
) -> Vec<Option<CompressionResponse>> {
    requests
        .into_par_iter()
        .map(|req| compress_image(req).ok())
        .collect()
}

fn quality_clamp(q: u8) -> u8 {
    if q == 0 {
        80
    } else if q > 100 {
        100
    } else {
        q
    }
}
