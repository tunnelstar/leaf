use std::{ffi::CStr, os::raw::c_char};

pub const ER_OK: i32 = 0;
pub const ER_CNF_PATH: i32 = 1;
pub const ER_CNF: i32 = 2;
pub const ER_IO: i32 = 3;
pub const ER_WTER: i32 = 4;
pub const ER_ASY_CHNL_SEND: i32 = 5;
pub const ER_SYNC_CHNL_RECV: i32 = 6;
pub const ER_RT_MNGR: i32 = 7;
pub const ER_NO_CNF_FILE: i32 = 8;

fn to_errno(e: leaf::Error) -> i32 {
    match e {
        leaf::Error::Config(..) => ER_CNF,
        leaf::Error::NoConfigFile => ER_NO_CNF_FILE,
        leaf::Error::Io(..) => ER_IO,
        #[cfg(feature = "auto-reload")]
        leaf::Error::Watcher(..) => ER_WTER,
        leaf::Error::AsyncChannelSend(..) => ER_ASY_CHNL_SEND,
        leaf::Error::SyncChannelRecv(..) => ER_SYNC_CHNL_RECV,
        leaf::Error::RuntimeManager => ER_RT_MNGR,
    }
}

// #[no_mangle]
// pub extern "C" fn leaf_run_with_options(
//     rt_id: u16,
//     config_path: *const c_char,
//     auto_reload: bool, // requires this parameter anyway
//     multi_thread: bool,
//     auto_threads: bool,
//     threads: i32,
//     stack_size: i32,
// ) -> i32 {
//     if let Ok(config_path) = unsafe { CStr::from_ptr(config_path).to_str() } {
//         if let Err(e) = leaf::util::run_with_options(
//             rt_id,
//             config_path.to_string(),
//             #[cfg(feature = "auto-reload")]
//             auto_reload,
//             multi_thread,
//             auto_threads,
//             threads as usize,
//             stack_size as usize,
//         ) {
//             return to_errno(e);
//         }
//         ER_OK
//     } else {
//         ER_CNF_PATH
//     }
// }

// #[no_mangle]
// pub extern "C" fn leaf_run(rt_id: u16, config_path: *const c_char) -> i32 {
//     if let Ok(config_path) = unsafe { CStr::from_ptr(config_path).to_str() } {
//         let opts = leaf::StartOptions {
//             config: leaf::Config::File(config_path.to_string()),
//             #[cfg(feature = "auto-reload")]
//             auto_reload: false,
//             runtime_opt: leaf::RuntimeOption::SingleThread,
//         };
//         if let Err(e) = leaf::start(rt_id, opts) {
//             return to_errno(e);
//         }
//         ER_OK
//     } else {
//         ER_CNF_PATH
//     }
// }

#[no_mangle]
pub extern "C" fn leaf_run_with_config_string(rt_id: u16, config: *const c_char) -> i32 {
    if let Ok(config) = unsafe { CStr::from_ptr(config).to_str() } {
        let opts = leaf::StartOptions {
            config: leaf::Config::Str(config.to_string()),
            #[cfg(feature = "auto-reload")]
            auto_reload: false,
            runtime_opt: leaf::RuntimeOption::SingleThread,
        };
        if let Err(e) = leaf::start(rt_id, opts) {
            return to_errno(e);
        }
        ER_OK
    } else {
        ER_CNF_PATH
    }
}

// #[no_mangle]
// pub extern "C" fn leaf_reload(rt_id: u16) -> i32 {
//     if let Err(e) = leaf::reload(rt_id) {
//         return to_errno(e);
//     }
//     ER_OK
// }

#[no_mangle]
pub extern "C" fn leaf_shutdown(rt_id: u16) -> bool {
    leaf::shutdown(rt_id)
}

// #[no_mangle]
// pub extern "C" fn leaf_test_config(config_path: *const c_char) -> i32 {
//     if let Ok(config_path) = unsafe { CStr::from_ptr(config_path).to_str() } {
//         if let Err(e) = leaf::test_config(&config_path) {
//             return to_errno(e);
//         }
//         ER_OK
//     } else {
//         ER_CNF_PATH
//     }
// }
