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

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Note {
    pub id: i64,
    pub guid: String,
    pub mid: i64,
    pub flds: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ApkgParseResult {
    pub notes: Vec<Note>,
    pub media_map: HashMap<String, String>,
    pub media_files: HashMap<String, Vec<u8>>,
}

#[flutter_rust_bridge::frb]
pub fn parse_apkg(path: String) -> Result<ApkgParseResult, String> {
    let file = File::open(&path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是有效的apkg/zip文件: {e}"))?;

    // 检查 collection 文件名
    let mut has_meta = false;
    let mut has_anki21 = false;
    let mut has_anki2 = false;
    for i in 0..zip.len() {
        if let Ok(name) = zip.by_index(i).map(|f| f.name().to_string()) {
            match name.as_str() {
                "meta" => has_meta = true,
                "collection.anki21" => has_anki21 = true,
                "collection.anki2" => has_anki2 = true,
                _ => {}
            }
        }
    }
    // 重新打开zip
    let file = File::open(&path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是有效的apkg/zip文件: {e}"))?;

    let (collection_name, is_zstd) = if has_meta {
        ("collection.anki21b", true)
    } else if has_anki21 {
        ("collection.anki21", false)
    } else if has_anki2 {
        ("collection.anki2", false)
    } else {
        return Err("apkg中未找到collection.anki21b/21/2".to_string());
    };

    // 读取collection文件内容
    let mut db_bytes = Vec::new();
    zip.by_name(collection_name)
        .map_err(|_| "apkg中未找到collection文件".to_string())?
        .read_to_end(&mut db_bytes)
        .map_err(|_| "读取数据库失败".to_string())?;

    // 如需zstd解压
    let db_data = if is_zstd {
        zstd::stream::decode_all(&db_bytes[..]).map_err(|_| "zstd解压失败".to_string())?
    } else {
        db_bytes
    };

    // 写入临时sqlite文件
    let tmp_path = std::env::temp_dir().join("tmp_collection.sqlite");
    std::fs::write(&tmp_path, &db_data).map_err(|_| "写入临时文件失败".to_string())?;

    // 读取所有notes内容
    let conn = Connection::open(&tmp_path).map_err(|e| format!("打开sqlite失败: {e}"))?;
    let mut stmt = conn.prepare("SELECT id, guid, mid, flds FROM notes").map_err(|e| format!("准备SQL失败: {e}"))?;
    let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
    let mut notes = Vec::new();
    while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
        let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
        let guid: String = row.get(1).map_err(|e| format!("读取guid失败: {e}"))?;
        let mid: i64 = row.get(2).map_err(|e| format!("读取mid失败: {e}"))?;
        let flds: String = row.get(3).map_err(|e| format!("读取flds失败: {e}"))?;
        let flds_vec = flds.split('\x1f').map(|s| s.to_string()).collect();
        notes.push(Note { id, guid, mid, flds: flds_vec });
    }

    // 解析media映射
    let mut media_map: HashMap<String, String> = HashMap::new();
    if let Ok(mut media_file) = zip.by_name("media") {
        let mut media_json = String::new();
        media_file.read_to_string(&mut media_json).ok();
        if let Ok(media_map_json) = serde_json::from_str::<Value>(&media_json) {
            if let Some(obj) = media_map_json.as_object() {
                for (k, v) in obj.iter() {
                    if let Some(vstr) = v.as_str() {
                        media_map.insert(k.clone(), vstr.to_string());
                    }
                }
            }
        }
    }

    // 收集被引用的媒体文件名
    let mut referenced_media = std::collections::HashSet::new();
    for note in &notes {
        for f in &note.flds {
            // 查找 <img src="..."> 和 [sound:...] 引用
            let img_re = regex::Regex::new(r#"<img[^>]*src=[\"']([^\"'>]+)[\"'][^>]*>"#).unwrap();
            for cap in img_re.captures_iter(f) {
                if let Some(fname) = cap.get(1) {
                    referenced_media.insert(fname.as_str().to_string());
                }
            }
            let sound_re = regex::Regex::new(r#"\[sound:([^\]]+)\]"#).unwrap();
            for cap in sound_re.captures_iter(f) {
                if let Some(fname) = cap.get(1) {
                    referenced_media.insert(fname.as_str().to_string());
                }
            }
        }
    }

    // 反查 media_map，找到所有被引用的媒体编号
    let mut referenced_media_keys = std::collections::HashSet::new();
    for (k, v) in &media_map {
        if referenced_media.contains(v) {
            referenced_media_keys.insert(k.clone());
        }
    }

    // 提取媒体文件内容
    let mut media_files: HashMap<String, Vec<u8>> = HashMap::new();
    for key in referenced_media_keys {
        if let Some(fname) = media_map.get(&key) {
            if let Ok(mut file) = zip.by_name(&key) {
                let mut buf = Vec::new();
                file.read_to_end(&mut buf).ok();
                media_files.insert(fname.clone(), buf);
            }
        }
    }

    // 删除临时文件
    let _ = std::fs::remove_file(&tmp_path);

    Ok(ApkgParseResult { notes, media_map, media_files })
}
