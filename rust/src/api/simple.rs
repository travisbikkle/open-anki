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
use crate::frb_generated::StreamSink;
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref LOG_SINK: Mutex<Option<StreamSink<String>>> = Mutex::new(None);
}

#[flutter_rust_bridge::frb]
pub fn register_log_callback(sink: StreamSink<String>) {
    *LOG_SINK.lock().unwrap() = Some(sink);
}

fn rust_log(msg: &str) {
    if let Some(sink) = &*LOG_SINK.lock().unwrap() {
        let _ = sink.add(msg.to_string());
    }
}

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
    pub version: String, // 新增：anki2/anki21b
}

#[flutter_rust_bridge::frb]
pub fn extract_apkg(apkg_path: String, base_dir: String) -> Result<ExtractResult, String> {
    rust_log(&format!("DEBUG: extract_apkg 被调用"));
    // 1. 计算md5
    let mut file = File::open(&apkg_path).map_err(|e| format!("无法打开apkg文件: {e}"))?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf).map_err(|e| format!("读取apkg失败: {e}"))?;
    let md5str = format!("{:x}", compute(&buf));
    // 2. 建立目录
    let deck_dir = PathBuf::from(&base_dir).join(&md5str);
    // 如果目录已存在，递归删除
    if deck_dir.exists() {
        rust_log(&format!("DEBUG: 递归删除已存在的deck目录: {}", deck_dir.display()));
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

    rust_log(&format!("DEBUG: 检查 collection 文件"));
    rust_log(&format!("DEBUG: anki21b 路径: {}", anki21b.display()));
    rust_log(&format!("DEBUG: anki2 路径: {}", anki2.display()));
    rust_log(&format!("DEBUG: sqlite 目标路径: {}", sqlite_path.display()));
    rust_log(&format!("DEBUG: anki21b 存在: {}", anki21b.exists()));
    rust_log(&format!("DEBUG: anki2 存在: {}", anki2.exists()));

    let version = if anki21b.exists() {
        // 新版：zstd 解压
        rust_log(&format!("DEBUG: 开始处理 anki21b"));
        let mut zstd_file = File::open(&anki21b).map_err(|e| format!("打开anki21b失败: {e}"))?;
        let mut zstd_bytes = Vec::new();
        zstd_file.read_to_end(&mut zstd_bytes).map_err(|e| format!("读取anki21b失败: {e}"))?;
        rust_log(&format!("DEBUG: anki21b 大小: {} bytes", zstd_bytes.len()));
        let sqlite_bytes = decode_all(&zstd_bytes[..]).map_err(|e| format!("zstd解压失败: {e}"))?;
        rust_log(&format!("DEBUG: 解压后大小: {} bytes", sqlite_bytes.len()));
        let mut out = File::create(&sqlite_path).map_err(|e| format!("创建sqlite文件失败: {e}"))?;
        out.write_all(&sqlite_bytes).map_err(|e| format!("写入sqlite失败: {e}"))?;
        rust_log(&format!("DEBUG: anki21b 处理完成"));
        "anki21b"
    } else if anki2.exists() {
        // 老版：直接复制
        rust_log(&format!("DEBUG: 开始处理 anki2"));
        fs::copy(&anki2, &sqlite_path).map_err(|e| format!("复制anki2失败: {e}"))?;
        rust_log(&format!("DEBUG: anki2 复制完成"));
        "anki2"
    } else {
        // 警告：未找到 collection.anki21b 或 collection.anki2
        rust_log(&format!("DEBUG: 警告：未找到 collection.anki21b 或 collection.anki2"));
        "unknown"
    };

    rust_log(&format!("DEBUG: 最终 sqlite 文件存在: {}", sqlite_path.exists()));
    if sqlite_path.exists() {
        if let Ok(metadata) = fs::metadata(&sqlite_path) {
            rust_log(&format!("DEBUG: sqlite 文件大小: {} bytes", metadata.len()));
        }
    }

    // 5. 解压媒体文件
    rust_log(&format!("DEBUG: 开始解压媒体文件"));
    let media_dir = deck_dir.join("unarchived_media");
    
    // 检查 unarchived_media 路径是否存在
    if media_dir.exists() {
        if media_dir.is_file() {
            // 如果是文件，删除它
            fs::remove_file(&media_dir).map_err(|e| format!("删除已存在的unarchived_media文件失败: {e}"))?;
            rust_log(&format!("DEBUG: 删除了已存在的unarchived_media文件"));
        } else {
            // 如果是目录，清空它
            fs::remove_dir_all(&media_dir).map_err(|e| format!("清空已存在的unarchived_media目录失败: {e}"))?;
            rust_log(&format!("DEBUG: 清空了已存在的unarchived_media目录"));
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
            let mut bytes = Vec::new();
            entry.read_to_end(&mut bytes).map_err(|e| format!("读取media映射文件失败: {e}"))?;
            let buf = String::from_utf8_lossy(&bytes);
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
    rust_log(&format!("DEBUG: 媒体文件解压完成"));
    
    // 6. 解析 media 映射文件
    

    rust_log(&format!("DEBUG: 媒体文件解压完成"));
    
    // 6. 解析 media 映射文件
    rust_log(&format!("DEBUG: 开始解析 media 映射"));
    let mut media_map: HashMap<String, String> = HashMap::new();
    let media_mapping_file = deck_dir.join("media");
    rust_log(&format!("DEBUG: media 映射文件路径: {}", media_mapping_file.display()));
    rust_log(&format!("DEBUG: media 映射文件存在: {}", media_mapping_file.exists()));
    rust_log(&format!("DEBUG: media 映射文件是文件: {}", media_mapping_file.is_file()));
    
    if media_mapping_file.exists() && media_mapping_file.is_file() {
        rust_log(&format!("DEBUG: 尝试读取 media 映射文件"));
        match fs::read_to_string(&media_mapping_file) {
            Ok(media_content) => {
                rust_log(&format!("DEBUG: media 文件内容长度: {}", media_content.len()));
                rust_log(&format!("DEBUG: media 文件内容前100字符: {}", &media_content[..media_content.len().min(100)]));
                
                match serde_json::from_str::<serde_json::Value>(&media_content) {
                    Ok(media_json) => {
                        rust_log(&format!("DEBUG: JSON 解析成功"));
                        if let Some(obj) = media_json.as_object() {
                            rust_log(&format!("DEBUG: JSON 对象键数量: {}", obj.len()));
                            for (key, value) in obj.iter() {
                                if let Some(filename) = value.as_str() {
                                    media_map.insert(filename.to_string(), key.clone());
                                    //rust_log(&format!("DEBUG: 媒体映射: {} -> {}", filename, key));
                                } else {
                                    rust_log(&format!("DEBUG: 跳过非字符串值: key={}, value={:?}", key, value));
                                }
                            }
                        } else {
                            rust_log(&format!("DEBUG: JSON 不是对象类型"));
                        }
                    }
                    Err(e) => rust_log(&format!("DEBUG: JSON 解析失败: {}", e)),
                }
            }
            Err(e) => rust_log(&format!("DEBUG: 读取 media 文件失败: {}", e)),
        }
    } else {
        rust_log(&format!("DEBUG: media 映射文件不存在或不是文件"));
    }
    rust_log(&format!("DEBUG: media 映射解析完成，共 {} 个文件", media_map.len()));
    
    Ok(ExtractResult {
        dir: deck_dir.to_string_lossy().to_string(),
        md5: md5str,
        media_map,
        version: version.to_string(), // 修正类型
    })
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

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SingleNoteResult {
    pub note: NoteExt,
    pub notetype: Option<NotetypeExt>,
    pub fields: Vec<FieldExt>,
    pub ord: i64,
    pub front: String, // 正面模板
    pub back: String,  // 反面模板
    pub css: String,
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
pub fn get_deck_note(sqlite_path: String, note_id: i64, version: String) -> Result<SingleNoteResult, String> {
    rust_log(&format!("DEBUG: get_deck_note 被调用, note_id={}, version={}", note_id, version));
    if !std::path::Path::new(&sqlite_path).exists() {
        return Err(format!("文件不存在: {sqlite_path}"));
    }
    let conn = Connection::open(&sqlite_path).map_err(|e| format!("打开sqlite失败: {e}"))?;
    let mut note: Option<NoteExt> = None;
    let mut notetype: Option<NotetypeExt> = None;
    let mut fields: Vec<FieldExt> = vec![];
    let mut ord: i64 = 0;
    let mut front = String::new();
    let mut back = String::new();
    let mut css = String::new();
    if version == "anki21b" {
        // 新版表结构
        let mut stmt = conn.prepare("SELECT id, guid, mid, flds FROM notes WHERE id = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows = stmt.query([note_id]).map_err(|e| format!("查询SQL失败: {e}"))?;
        if let Some(row) = rows.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            let id: i64 = row.get(0).map_err(|e| format!("读取id失败: {e}"))?;
            let guid: String = row.get(1).map_err(|e| format!("读取guid失败: {e}"))?;
            let mid: i64 = row.get(2).map_err(|e| format!("读取mid失败: {e}"))?;
            let flds: String = row.get(3).map_err(|e| format!("读取flds失败: {e}"))?;
            let flds_vec: Vec<String> = flds.split('\x1f').map(|s| s.to_string()).collect();
            // 查找卡片ord
            let mut stmt_card = conn.prepare("SELECT ord FROM cards WHERE nid = ? LIMIT 1").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows_card = stmt_card.query([id]).map_err(|e| format!("查询SQL失败: {e}"))?;
            if let Some(row_card) = rows_card.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                ord = row_card.get(0).map_err(|e| format!("读取ord失败: {e}"))?;
            }
            // notetype
            let mut stmt2 = conn.prepare("SELECT id, name, config FROM notetypes WHERE id = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows2 = stmt2.query([mid]).map_err(|e| format!("查询SQL失败: {e}"))?;
            if let Some(row2) = rows2.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                let nid: i64 = row2.get(0).map_err(|e| format!("读取id失败: {e}"))?;
                let name: String = row2.get(1).map_err(|e| format!("读取name失败: {e}"))?;
                let config: Option<String> = row2.get::<_, Option<String>>(2).unwrap_or(Some(String::new()));
                notetype = Some(NotetypeExt { id: nid, name, config });
            }
            // fields
            let mut stmt3 = conn.prepare("SELECT ntid, ord, name FROM fields WHERE ntid = ? ORDER BY ord ASC").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows3 = stmt3.query([mid]).map_err(|e| format!("查询SQL失败: {e}"))?;
            let mut field_vec = vec![];
            while let Some(row3) = rows3.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                let notetype_id: i64 = row3.get(0).map_err(|e| format!("读取ntid失败: {e}"))?;
                let ord_f: i64 = row3.get(1).map_err(|e| format!("读取ord失败: {e}"))?;
                let name: String = row3.get(2).map_err(|e| format!("读取name失败: {e}"))?;
                let id = notetype_id * 1000 + ord_f;
                field_vec.push(FieldExt { id, notetype_id, name, ord: ord_f });
            }
            let field_names: Vec<String> = field_vec.iter().map(|f| f.name.clone()).collect();
            note = Some(NoteExt { id, guid, mid, flds: flds_vec, notetype_name: notetype.as_ref().map(|n| n.name.clone()).unwrap_or_default(), field_names });
            fields = field_vec;
            // 查模板
            let mut stmt_tpl = conn.prepare("SELECT config FROM templates WHERE ntid = ? AND ord = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows_tpl = stmt_tpl.query([mid, ord]).map_err(|e| format!("查询SQL失败: {e}"))?;
            if let Some(row_tpl) = rows_tpl.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                let config_bytes: Vec<u8> = row_tpl.get(0).map_err(|e| format!("读取config失败: {e}"))?;
                let config = String::from_utf8_lossy(&config_bytes).to_string();

                // 通用分割正反面：优先用 <hr id=answer>，否则用 <hr>，否则用两个换行
                if let Some(idx) = config.find("\n\n") {
                    front = config[..idx].to_string();
                    back = config[idx + 2..].to_string();
                } else {
                    front = config.clone();
                    back = String::new();
                }
            }
            // 查样式 1580121962837
            let mut stmt_css = conn.prepare("SELECT config FROM notetypes WHERE id = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
            let mut rows_css = stmt_css.query([mid]).map_err(|e| format!("查询SQL失败: {e}"))?;
            rust_log(&format!("[DEBUG] begin to query row_css"));
            if let Some(row_css) = rows_css.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
                if let Ok(Some(config_bytes)) = row_css.get::<_, Option<Vec<u8>>>(0) {
                    let config_str = String::from_utf8_lossy(&config_bytes).to_string();
                    // 先尝试json解析
                    if let Ok(model) = serde_json::from_str::<serde_json::Value>(&config_str) {
                        if let Some(css_val) = model.get("css").and_then(|v| v.as_str()) {
                            css = css_val.to_string();
                        } else {
                            rust_log("[DEBUG] JSON中未找到css字段");
                        }
                    } else if let Some(idx) = config_str.find("\\documentclass") {
                        rust_log(&format!("[DEBUG] config_str 不是JSON，\\documentclass分割点: {}", idx));
                        css = config_str[..idx].trim().to_string();
                    } else {
                        rust_log("[DEBUG] config_str 不是JSON，也没有\\documentclass分割点，直接trim");
                        css = config_str.trim().to_string();
                    }
                } else {
                    rust_log("[DEBUG] row_css.get::<_, Option<Vec<u8>>>(0) 失败或为None");
                }
            }
        }
    } else {
        // anki2 或其他老版本
        // 1. 通过 card_id 查 cards 表，拿到 nid（note id）和 ord（模板序号）
        let mut stmt_card = conn.prepare("SELECT nid, ord FROM cards WHERE nid = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows_card = stmt_card.query([note_id]).map_err(|e| format!("查询SQL失败: {e}"))?;
        let (nid, ord): (i64, i64) = if let Some(row) = rows_card.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            (row.get(0).map_err(|e| format!("读取nid失败: {e}"))?, row.get(1).map_err(|e| format!("读取ord失败: {e}"))?)
        } else {
            return Err("未找到指定id的card".to_string());
        };
        // 2. 用 nid 查 notes 表
        let mut stmt_note = conn.prepare("SELECT id, guid, mid, flds FROM notes WHERE id = ?").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows_note = stmt_note.query([nid]).map_err(|e| format!("查询SQL失败: {e}"))?;
        let (id, guid, mid, flds): (i64, String, i64, String) = if let Some(row) = rows_note.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            (row.get(0).map_err(|e| format!("读取id失败: {e}"))?, row.get(1).map_err(|e| format!("读取guid失败: {e}"))?, row.get(2).map_err(|e| format!("读取mid失败: {e}"))?, row.get(3).map_err(|e| format!("读取flds失败: {e}"))?)
        } else {
            return Err("未找到指定id的note".to_string());
        };
        let flds_vec: Vec<String> = flds.split('\x1f').map(|s| s.to_string()).collect();
        // 3. 读取 col.models
        let mut stmt_models = conn.prepare("SELECT models FROM col LIMIT 1").map_err(|e| format!("准备SQL失败: {e}"))?;
        let mut rows_models = stmt_models.query([]).map_err(|e| format!("查询SQL失败: {e}"))?;
        let models_json: String = if let Some(row) = rows_models.next().map_err(|e| format!("遍历SQL失败: {e}"))? {
            row.get(0).map_err(|e| format!("读取models失败: {e}"))?
        } else {
            return Err("未找到col.models".to_string());
        };
        let models: serde_json::Value = serde_json::from_str(&models_json).map_err(|e| format!("解析models JSON失败: {e}"))?;
        // 4. 用 mid 关联模型
        let model = models.get(mid.to_string()).ok_or("未找到模型")?;
        // 5. 取 tpls[ord]
        let tpls = model.get("tmpls").and_then(|v| v.as_array()).ok_or("tmpls 字段缺失或不是数组")?;
        let tpl = tpls.get(ord as usize).or_else(|| tpls.get(0)).ok_or("未找到模板")?;
        front = tpl.get("qfmt").and_then(|v| v.as_str()).unwrap_or("").to_string();
        back = tpl.get("afmt").and_then(|v| v.as_str()).unwrap_or("").to_string();
        css = model.get("css").and_then(|v| v.as_str()).unwrap_or("").to_string();
        // 组装 note/ext/fields
        let mut notetype_name = model.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let mut field_names = vec![];
        let mut fields_vec = vec![];
        if let Some(flds_def) = model.get("flds").and_then(|v| v.as_array()) {
            for (ord_f, f) in flds_def.iter().enumerate() {
                let fname = f.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
                field_names.push(fname.clone());
                fields_vec.push(FieldExt {
                    id: ord_f as i64,
                    notetype_id: mid,
                    name: fname,
                    ord: ord_f as i64,
                });
            }
        }
        notetype = Some(NotetypeExt { id: mid, name: notetype_name.clone(), config: Some(model.to_string()) });
        note = Some(NoteExt { id, guid, mid, flds: flds_vec, notetype_name, field_names });
        fields = fields_vec;
    }
    if let Some(note) = note {
        // 查模板和样式同上，直接从 notetype.config 解析
        if let Some(nt) = &notetype {
            if let Some(config_str) = &nt.config {
                if let Ok(model) = serde_json::from_str::<serde_json::Value>(config_str) {
                    if let Some(tpls) = model.get("tpls").and_then(|v| v.as_array()) {
                        let tpl = tpls.get(ord as usize).or_else(|| tpls.get(0));
                        if let Some(tpl) = tpl {
                            front = tpl.get("qfmt").and_then(|v| v.as_str()).unwrap_or("").to_string();
                            back = tpl.get("afmt").and_then(|v| v.as_str()).unwrap_or("").to_string();
                        }
                    }
                    if let Some(css_val) = model.get("css").and_then(|v| v.as_str()) {
                        css = css_val.to_string();
                    }
                }
            }
        }
        //rust_log(&format!("[DEBUG]: css内容: {}", css));
        Ok(SingleNoteResult { note, notetype, fields, ord, front, back, css })
    } else {
        Err("未找到指定id的note".to_string())
    }
}

#[flutter_rust_bridge::frb]
pub fn get_card_count(sqlite_path: String) -> usize {
    use rusqlite::Connection;
    let conn = Connection::open(sqlite_path).unwrap();
    let mut stmt = conn.prepare("SELECT COUNT(*) FROM notes").unwrap();
    let count: usize = stmt.query_row([], |row| row.get(0)).unwrap_or(0);
    count
}

#[flutter_rust_bridge::frb]
pub fn get_card_count_from_deck(app_doc_dir: String, md5: String) -> usize {
    use std::path::Path;
    
    let sqlite_path1 = format!("{}/anki_data/{}/collection.sqlite", app_doc_dir, md5);
    let sqlite_path2 = format!("{}/anki_data/{}/collection.anki2", app_doc_dir, md5);
    
    let real_path = if Path::new(&sqlite_path1).exists() {
        Some(sqlite_path1)
    } else if Path::new(&sqlite_path2).exists() {
        Some(sqlite_path2)
    } else {
        None
    };
    
    if let Some(path) = real_path {
        get_card_count(path)
    } else {
        0
    }
}
