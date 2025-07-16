#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

use std::fs::File;
use std::io::Read;
use std::collections::HashMap;
use rusqlite::Connection;
use zip::ZipArchive;
use serde::{Serialize, Deserialize};
use serde_json::Value;
use std::path::PathBuf;
use std::fs;
use zstd::stream::decode_all;
use md5::compute;
use std::io::Write;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Note {
    pub id: i64,
    pub guid: String,
    pub mid: i64,
    pub flds: Vec<String>,
    pub notetype_name: Option<String>, // 新增模板名字段
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ApkgParseResult {
    pub notes: Vec<Note>,
    pub media_map: HashMap<String, String>,
    pub media_files: HashMap<String, Vec<u8>>,
}



#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ExtractResult {
    pub dir: String,
    pub md5: String,
}

#[flutter_rust_bridge::frb]
pub fn extract_apkg(apkg_path: String, base_dir: String) -> Result<ExtractResult, String> {
    // 1. 计算md5
    let mut file = File::open(&apkg_path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf).map_err(|e| format!("读取apkg失败: {e}"))?;
    let md5str = format!("{:x}", compute(&buf));
    // 2. 建立目录
    let deck_dir = PathBuf::from(&base_dir).join(&md5str);
    fs::create_dir_all(&deck_dir).map_err(|e| format!("创建目录失败: {e}"))?;
    // 3. 解压apkg
    let file = File::open(&apkg_path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是有效的apkg/zip文件: {e}"))?;
    for i in 0..zip.len() {
        let mut entry = zip.by_index(i).map_err(|e| format!("读取zip entry失败: {e}"))?;
        let outpath = deck_dir.join(entry.name());
        if entry.is_dir() {
            fs::create_dir_all(&outpath).map_err(|e| format!("创建子目录失败: {e}"))?;
        } else {
            if let Some(parent) = outpath.parent() {
                fs::create_dir_all(parent).map_err(|e| format!("创建父目录失败: {e}"))?;
            }
            let mut outfile = File::create(&outpath).map_err(|e| format!("创建文件失败: {e}"))?;
            std::io::copy(&mut entry, &mut outfile).map_err(|e| format!("写入文件失败: {e}"))?;
        }
    }
    // 4. zstd解压collection.anki21b
    let anki21b = deck_dir.join("collection.anki21b");
    if anki21b.exists() {
        let mut zstd_file = File::open(&anki21b).map_err(|e| format!("打开anki21b失败: {e}"))?;
        let mut zstd_bytes = Vec::new();
        zstd_file.read_to_end(&mut zstd_bytes).map_err(|e| format!("读取anki21b失败: {e}"))?;
        let sqlite_bytes = decode_all(&zstd_bytes[..]).map_err(|e| format!("zstd解压失败: {e}"))?;
        let sqlite_path = deck_dir.join("collection.sqlite");
        let mut out = File::create(&sqlite_path).map_err(|e| format!("创建sqlite文件失败: {e}"))?;
        out.write_all(&sqlite_bytes).map_err(|e| format!("写入sqlite失败: {e}"))?;
    }
    Ok(ExtractResult { dir: deck_dir.to_string_lossy().to_string(), md5: md5str })
}
