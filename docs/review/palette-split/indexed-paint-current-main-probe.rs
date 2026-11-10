//! Temporary source-scoped review probe; removed after evidence capture.
use photocraft_color::{Color, ColorMode, SampleType};
use photocraft_doc::{ColorTable, Document, Size};
use photocraft_engine::{Session, brush_cmds::LiveStroke};
use photocraft_geom::Rect;
use photocraft_paint::StrokePoint;
use serde_json::json;
use std::{error::Error, time::Instant};

fn fixture(indexed: bool, dense: bool) -> Result<Session, Box<dyn Error>> {
    let mut doc = Document::with_background("synthetic review", Size::new(6000, 4000), ColorMode::Rgb, SampleType::U8, Color::rgb(1.0, 1.0, 1.0));
    if dense {
        let id = doc.top_layer().ok_or("missing layer")?;
        let surface = doc.layer_mut(id).and_then(|l| l.surface_mut()).ok_or("missing raster")?;
        let format = surface.format();
        let black = photocraft_raster::from_rgba(&format, [0.0, 0.0, 0.0, 1.0]);
        for x in (0..6000).step_by(128) {
            surface.fill_rect(Rect::new(x, 0, (x + 64).min(6000), 4000), &black);
        }
    }
    if indexed {
        doc.mode = ColorMode::Indexed;
        doc.color_table = Some(ColorTable { colors: vec![[0, 0, 0], [255, 255, 255]], transparent: None });
    }
    let mut s = Session::new();
    s.add_document(doc, None);
    Ok(s)
}

fn region(doc: &Document) -> Result<Vec<f32>, Box<dyn Error>> {
    let id = doc.top_layer().ok_or("missing layer")?;
    let surface = doc.layer(id).and_then(|l| l.surface()).ok_or("missing raster")?;
    Ok(surface.read_region(Rect::new(2900, 1900, 3400, 2100)))
}

fn main() -> Result<(), Box<dyn Error>> {
    let trial = std::env::args().nth(1).ok_or("missing trial")?.parse::<u32>()?;
    let points: Vec<[f64; 3]> = (0..=120)
        .map(|i| {
            let t = f64::from(i);
            [3000.0 + t * 2.0, 2000.0 + 20.0 * (t / 15.0).sin(), 1.0]
        })
        .collect();
    let params = |pts: &[[f64; 3]]| json!({"points":pts,"size":60,"hardness":0.8,"opacity":1.0,"smoothing":0.0,"seed":7,"color":"#ff0000"});
    for indexed in [false, true] {
        for dense in [false, true] {
            let mut s = fixture(indexed, dense)?;
            let table = s.active().ok_or("missing document")?.doc.color_table.clone();
            let before = region(&s.active().ok_or("missing document")?.doc)?;
            let start = Instant::now();
            s.execute("paint.stroke", params(&points))?;
            let commit_ms = start.elapsed().as_secs_f64() * 1000.0;
            let committed = region(&s.active().ok_or("missing document")?.doc)?;
            if committed == before {
                return Err("stroke unexpectedly made no edit".into());
            }
            if s.active().ok_or("missing document")?.doc.color_table != table {
                return Err("stroke changed table".into());
            }
            if indexed && committed.chunks_exact(4).any(|p| p.get(..3).is_none_or(|rgb| rgb != [0.0, 0.0, 0.0] && rgb != [1.0, 1.0, 1.0])) {
                return Err("stroke escaped original black/white palette".into());
            }
            let mut hash = blake3::Hasher::new();
            for sample in &committed {
                hash.update(&sample.to_bits().to_le_bytes());
            }
            let pixel_hash = hash.finalize().to_hex().to_string();
            if !s.undo() {
                return Err("stroke was not undoable".into());
            }
            if region(&s.active().ok_or("missing document")?.doc)? != before {
                return Err("undo changed samples".into());
            }
            let mut samples = Vec::with_capacity(points.len());
            let start = Instant::now();
            let mut live = LiveStroke::begin(&s, &params(points.get(..1).ok_or("missing first point")?))?;
            samples.push(start.elapsed().as_secs_f64() * 1000.0);
            for point in points.get(1..).ok_or("missing remaining points")? {
                let start = Instant::now();
                live.push(&[StrokePoint::new(point[0], point[1], 1.0)])?;
                samples.push(start.elapsed().as_secs_f64() * 1000.0);
            }
            if region(&live.doc)? != committed {
                return Err("live/final samples differ".into());
            }
            if live.doc.color_table != table {
                return Err("preview changed table".into());
            }
            let live_total_ms: f64 = samples.iter().sum();
            samples.sort_by(f64::total_cmp);
            let p95 = samples.get((samples.len() * 95 / 100).min(samples.len().saturating_sub(1))).copied().ok_or("missing samples")?;
            println!(
                "{}",
                json!({"trial":trial,"indexed":indexed,"dense":dense,"width":6000,"height":4000,"commit_ms":commit_ms,"live_total_ms":live_total_ms,"live_updates":samples.len(),"live_update_p95_ms":p95,"pixels_hash":pixel_hash,"palette":table})
            );
        }
    }
    Ok(())
}
