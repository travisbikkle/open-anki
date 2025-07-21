use std::fs::OpenOptions;
use std::io::Write;

fn set_panic_hook() {
    std::panic::set_hook(Box::new(|panic_info| {
        let msg = format!("[{}] Rust panic: {}\n", chrono::Local::now().to_rfc3339(), panic_info);
        if let Ok(mut file) = OpenOptions::new().create(true).append(true).open("/tmp/panic_log.txt") {
            let _ = file.write_all(msg.as_bytes());
        }
        // 也输出到stderr，方便Xcode调试
        eprintln!("{}", msg);
    }));
}

#[ctor::ctor]
fn init() {
    set_panic_hook();
}

pub mod api;
mod frb_generated;
