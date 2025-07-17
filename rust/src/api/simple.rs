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
use std::path::PathBuf;
use std::fs;
use zstd::stream::decode_all;
use md5::compute;
use std::io::Write;
use itertools::Itertools;

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
    pub media_map: HashMap<String, String>, // 文件名 -> 数字编号的映射
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
    // 如果目录已存在，递归删除
    if deck_dir.exists() {
        println!("DEBUG: 递归删除已存在的deck目录: {}", deck_dir.display());
        fs::remove_dir_all(&deck_dir).map_err(|e| format!("递归删除deck目录失败: {} - {}", deck_dir.display(), e))?;
    }
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
    // 4. 处理 collection 文件
    let anki21b = deck_dir.join("collection.anki21b");
    let anki2 = deck_dir.join("collection.anki2");
    let sqlite_path = deck_dir.join("collection.sqlite");

    println!("DEBUG: 检查 collection 文件");
    println!("DEBUG: anki21b 路径: {}", anki21b.display());
    println!("DEBUG: anki2 路径: {}", anki2.display());
    println!("DEBUG: sqlite 目标路径: {}", sqlite_path.display());
    println!("DEBUG: anki21b 存在: {}", anki21b.exists());
    println!("DEBUG: anki2 存在: {}", anki2.exists());

    if anki21b.exists() {
        // 新版：zstd 解压
        println!("DEBUG: 开始处理 anki21b");
        let mut zstd_file = File::open(&anki21b).map_err(|e| format!("打开anki21b失败: {e}"))?;
        let mut zstd_bytes = Vec::new();
        zstd_file.read_to_end(&mut zstd_bytes).map_err(|e| format!("读取anki21b失败: {e}"))?;
        println!("DEBUG: anki21b 大小: {} bytes", zstd_bytes.len());
        let sqlite_bytes = decode_all(&zstd_bytes[..]).map_err(|e| format!("zstd解压失败: {e}"))?;
        println!("DEBUG: 解压后大小: {} bytes", sqlite_bytes.len());
        let mut out = File::create(&sqlite_path).map_err(|e| format!("创建sqlite文件失败: {e}"))?;
        out.write_all(&sqlite_bytes).map_err(|e| format!("写入sqlite失败: {e}"))?;
        println!("DEBUG: anki21b 处理完成");
    } else if anki2.exists() {
        // 老版：直接复制
        println!("DEBUG: 开始处理 anki2");
        fs::copy(&anki2, &sqlite_path).map_err(|e| format!("复制anki2失败: {e}"))?;
        println!("DEBUG: anki2 复制完成");
    } else {
        println!("DEBUG: 警告：未找到 collection.anki21b 或 collection.anki2");
    }

    println!("DEBUG: 最终 sqlite 文件存在: {}", sqlite_path.exists());
    if sqlite_path.exists() {
        if let Ok(metadata) = fs::metadata(&sqlite_path) {
            println!("DEBUG: sqlite 文件大小: {} bytes", metadata.len());
        }
    }

    // 5. 解压媒体文件
    println!("DEBUG: 开始解压媒体文件");
    let media_dir = deck_dir.join("unarchived_media");
    
    // 检查 unarchived_media 路径是否存在
    if media_dir.exists() {
        if media_dir.is_file() {
            // 如果是文件，删除它
            fs::remove_file(&media_dir).map_err(|e| format!("删除已存在的unarchived_media文件失败: {e}"))?;
            println!("DEBUG: 删除了已存在的unarchived_media文件");
        } else {
            // 如果是目录，清空它
            fs::remove_dir_all(&media_dir).map_err(|e| format!("清空已存在的unarchived_media目录失败: {e}"))?;
            println!("DEBUG: 清空了已存在的unarchived_media目录");
        }
    }
    
    // 先解压所有文件，包括media映射文件
    let file = File::open(&apkg_path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是有效的apkg/zip文件: {e}"))?;
    // 先解析 media 映射
    let mut media_map: HashMap<String, String> = HashMap::new();
    for i in 0..zip.len() {
        let mut entry = zip.by_index(i).map_err(|e| format!("读取zip entry失败: {e}"))?;
        let name = entry.name().to_string();
        if name == "media" && entry.is_file() {
            let mut buf = String::new();
            entry.read_to_string(&mut buf).map_err(|e| format!("读取media映射文件失败: {e}"))?;
            if let Ok(media_json) = serde_json::from_str::<serde_json::Value>(&buf) {
                if let Some(obj) = media_json.as_object() {
                    for (key, value) in obj.iter() {
                        if let Some(filename) = value.as_str() {
                            media_map.insert(key.clone(), filename.to_string());
                        }
                    }
                }
            }
        }
    }
    // 再次遍历解压媒体文件（数字编号文件），用真实文件名存储
    let file = File::open(&apkg_path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是有效的apkg/zip文件: {e}"))?;
    for i in 0..zip.len() {
        let mut entry = zip.by_index(i).map_err(|e| format!("读取zip entry失败: {e}"))?;
        let name = entry.name().to_string();
        // 跳过目录和collection文件和media映射文件
        if name.ends_with('/') || name.starts_with("collection.") || name == "meta" || name == "media" {
            continue;
        }
        // 只处理数字编号文件
        if let Some(real_name) = media_map.get(&name) {
            let outpath = media_dir.join(real_name);
            if let Some(parent) = outpath.parent() {
                fs::create_dir_all(parent).map_err(|e| format!("创建父目录失败: {} - {}", parent.display(), e))?;
            }
            let mut outfile = File::create(&outpath).map_err(|e| format!("创建媒体文件失败: {} - {}", outpath.display(), e))?;
            std::io::copy(&mut entry, &mut outfile).map_err(|e| format!("写入媒体文件失败: {} - {}", outpath.display(), e))?;
        }
    }
    println!("DEBUG: 媒体文件解压完成");
    
    // 6. 解析 media 映射文件
    

    println!("DEBUG: 媒体文件解压完成");
    
    // 6. 解析 media 映射文件
    println!("DEBUG: 开始解析 media 映射");
    let mut media_map: HashMap<String, String> = HashMap::new();
    let media_mapping_file = deck_dir.join("media");
    println!("DEBUG: media 映射文件路径: {}", media_mapping_file.display());
    println!("DEBUG: media 映射文件存在: {}", media_mapping_file.exists());
    println!("DEBUG: media 映射文件是文件: {}", media_mapping_file.is_file());
    
    if media_mapping_file.exists() && media_mapping_file.is_file() {
        println!("DEBUG: 尝试读取 media 映射文件");
        match fs::read_to_string(&media_mapping_file) {
            Ok(media_content) => {
                println!("DEBUG: media 文件内容长度: {}", media_content.len());
                println!("DEBUG: media 文件内容前100字符: {}", &media_content[..media_content.len().min(100)]);
                
                match serde_json::from_str::<serde_json::Value>(&media_content) {
                    Ok(media_json) => {
                        println!("DEBUG: JSON 解析成功");
                        if let Some(obj) = media_json.as_object() {
                            println!("DEBUG: JSON 对象键数量: {}", obj.len());
                            for (key, value) in obj.iter() {
                                if let Some(filename) = value.as_str() {
                                    media_map.insert(filename.to_string(), key.clone());
                                    println!("DEBUG: 媒体映射: {} -> {}", filename, key);
                                } else {
                                    println!("DEBUG: 跳过非字符串值: key={}, value={:?}", key, value);
                                }
                            }
                        } else {
                            println!("DEBUG: JSON 不是对象类型");
                        }
                    }
                    Err(e) => println!("DEBUG: JSON 解析失败: {}", e),
                }
            }
            Err(e) => println!("DEBUG: 读取 media 文件失败: {}", e),
        }
    } else {
        println!("DEBUG: media 映射文件不存在或不是文件");
    }
    println!("DEBUG: media 映射解析完成，共 {} 个文件", media_map.len());
    
    Ok(ExtractResult { dir: md5str.clone(), md5: md5str, media_map })
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DeckNotesResult {
    pub notes: Vec<NoteExt>,
    pub notetypes: Vec<NotetypeExt>,
    pub fields: Vec<FieldExt>,
    pub cards: Vec<CardExt>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct NoteExt {
    pub id: i64,
    pub guid: String,
    pub mid: i64,
    pub flds: Vec<String>,
    pub notetype_name: String,
    pub field_names: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct NotetypeExt {
    pub id: i64,
    pub name: String,
    pub config: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FieldExt {
    pub id: i64,
    pub notetype_id: i64,
    pub name: String,
    pub ord: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CardExt {
    pub id: i64,
    pub nid: i64,
    pub ord: i64,
    pub type_: i64,
    pub queue: i64,
    pub due: i64,
}

// 辅助函数：判断表是否包含所有指定字段
fn table_has_columns(conn: &rusqlite::Connection, table: &str, columns: &[&str]) -> bool {
    let sql = format!("PRAGMA table_info({})", table);
    if let Ok(mut stmt) = conn.prepare(&sql) {
        if let Ok(mut rows) = stmt.query([]) {
            let mut found = vec![];
            while let Ok(Some(row)) = rows.next() {
                let name: String = row.get(1).unwrap_or_default();
                found.push(name);
            }
            return columns.iter().all(|c| found.contains(&c.to_string()));
        }
    }
    false
}

#[flutter_rust_bridge::frb]
pub fn get_deck_notes(sqlite_path: String) -> Result<DeckNotesResult, String> {
    println!("DEBUG: get_deck_notes 被调用");
    println!("DEBUG: 传入的 sqlite_path: {}", sqlite_path);
    
    // 调试：先判断文件是否存在
    if !std::path::Path::new(&sqlite_path).exists() {
        println!("DEBUG: 文件不存在: {}", sqlite_path);
        return Err(format!("文件不存在: {sqlite_path}"));
    }
    println!("DEBUG: 文件存在，尝试打开");
    let f = std::fs::File::open(&sqlite_path);
    if let Err(e) = &f {
        println!("DEBUG: 文件无法打开: {:?}", e);
        return Err(format!("文件无法打开: {sqlite_path}, err={:?}", e));
    }
    println!("DEBUG: 文件可以打开，继续处理");
    let conn = Connection::open(&sqlite_path).map_err(|e| format!("打开sqlite失败: {e}"))?;
    // 判断是否有 notetypes 表
    let has_notetypes = conn.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='notetypes'")
        .and_then(|mut stmt| stmt.exists([])).unwrap_or(false);
    // 判断 fields 表结构
    let has_fields = table_has_columns(&conn, "fields", &["id", "notetype_id", "name", "ord"]);
    let mut notetypes = Vec::new();
    let mut fields = Vec::new();
    if has_notetypes {
        // 新版结构
        let mut stmt = conn.prepare("SELECT id, name, config FROM notetypes").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
        while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
            let name: String = row.get(1).map_err(|e| format!("读取name失败: {e}"))?;
            let config: Option<String> = row.get(2).ok();
            notetypes.push(NotetypeExt { id, name, config });
        }
        if has_fields {
            let mut stmt = conn.prepare("SELECT id, notetype_id, name, ord FROM fields").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
            while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
                let notetype_id: i64 = row.get(1).map_err(|e| format!("读取notetype_id失败: {e}"))?;
                let name: String = row.get(2).map_err(|e| format!("读取name失败: {e}"))?;
                let ord: i64 = row.get(3).map_err(|e| format!("读取ord失败: {e}"))?;
                fields.push(FieldExt { id, notetype_id, name, ord });
            }
        }
    }
    if !has_notetypes || !has_fields {
        // 兼容老版结构：col.models 字段
        let mut stmt = conn.prepare("SELECT models FROM col").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
        let mut models_json = String::new();
        if let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            models_json = row.get(0).map_err(|e| format!("读取models失败: {e}"))?;
        }
        if models_json.trim().is_empty() {
            // fallback: 只读 notes 表，字段名和模板名设为 None/空
            let mut notes = Vec::new();
            let mut stmt = conn.prepare("SELECT id, guid, mid, flds FROM notes").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
            while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
                let guid: String = row.get(1).map_err(|e| format!("读取guid失败: {e}"))?;
                let mid: i64 = row.get(2).map_err(|e| format!("读取mid失败: {e}"))?;
                let flds: String = row.get(3).map_err(|e| format!("读取flds失败: {e}"))?;
                let flds_vec: Vec<String> = flds.split('\x1f').map(|s| s.to_string()).collect();
                notes.push(NoteExt {
                    id,
                    guid,
                    mid,
                    flds: flds_vec,
                    notetype_name: "".to_string(),
                    field_names: vec![],
                });
            }
            return Ok(DeckNotesResult {
                notes,
                notetypes: vec![],
                fields: vec![],
                cards: vec![],
            });
        }
        let models: serde_json::Value = serde_json::from_str(&models_json).map_err(|e| format!("解析models JSON失败: {e}"))?;
        if let Some(obj) = models.as_object() {
            for (id_str, model) in obj.iter() {
                let id = id_str.parse::<i64>().unwrap_or(0);
                let name = model.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let config = Some(model.to_string()); // 整个模型JSON作为config
                if !notetypes.iter().any(|n| n.id == id) {
                    notetypes.push(NotetypeExt { id, name, config });
                }
                // 字段
                if let Some(flds) = model.get("flds").and_then(|v| v.as_array()) {
                    for (ord, f) in flds.iter().enumerate() {
                        let fname = f.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
                        if !fields.iter().any(|fld| fld.notetype_id == id && fld.ord == ord as i64) {
                            fields.push(FieldExt {
                                id: ord as i64, // 老版无字段id，用序号代替
                                notetype_id: id,
                                name: fname,
                                ord: ord as i64,
                            });
                        }
                    }
                }
            }
        }
    }
    // 3. 读取 notes
    let mut notes = Vec::new();
    let mut stmt = conn.prepare("SELECT id, guid, mid, flds FROM notes").map_err(|e| format!("准备SQL失败: {e}"))?;
    let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
    while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
        let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
        let guid: String = row.get(1).map_err(|e| format!("读取guid失败: {e}"))?;
        let mid: i64 = row.get(2).map_err(|e| format!("读取mid失败: {e}"))?;
        let flds: String = row.get(3).map_err(|e| format!("读取flds失败: {e}"))?;
        let flds_vec: Vec<String> = flds.split('\x1f').map(|s| s.to_string()).collect();
        let notetype = notetypes.iter().find(|n| n.id == mid);
        let notetype_name = notetype.map(|n| n.name.clone()).unwrap_or_default();
        let field_names: Vec<String> = fields.iter().filter(|f| f.notetype_id == mid).sorted_by_key(|f| f.ord).map(|f| f.name.clone()).collect();
        notes.push(NoteExt { id, guid, mid, flds: flds_vec, notetype_name, field_names });
    }
    // 4. 读取 cards
    let mut cards = Vec::new();
    let mut stmt = conn.prepare("SELECT id, nid, ord, type, queue, due FROM cards").map_err(|e| format!("准备SQL失败: {e}"))?;
    let mut rows = stmt.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
    while let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
        let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
        let nid: i64 = row.get(1).map_err(|e| format!("读取nid失败: {e}"))?;
        let ord: i64 = row.get(2).map_err(|e| format!("读取ord失败: {e}"))?;
        let type_: i64 = row.get(3).map_err(|e| format!("读取type失败: {e}"))?;
        let queue: i64 = row.get(4).map_err(|e| format!("读取queue失败: {e}"))?;
        let due: i64 = row.get(5).map_err(|e| format!("读取due失败: {e}"))?;
        cards.push(CardExt { id, nid, ord, type_, queue, due });
    }
    Ok(DeckNotesResult { notes, notetypes, fields, cards })
}
