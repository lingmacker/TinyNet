use std::ptr;

use crate::speed::{compute_speed, InterfaceCounters, InterfaceFilterRule, NetSample, Speed};

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TinyNetSpeedFfi {
    pub upload_bps: u64,
    pub download_bps: u64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TinyNetFfiError {
    Ok = 0,
    NullPointer = 1,
}

pub struct TinyNetCalculator {
    previous: Option<NetSample>,
    rule: InterfaceFilterRule,
}

impl TinyNetCalculator {
    fn new() -> Self {
        Self {
            previous: None,
            rule: InterfaceFilterRule::ExcludeLoopbackAndVirtual,
        }
    }

    fn push_totals(&mut self, timestamp_ms: i64, rx_bytes: u64, tx_bytes: u64) -> Speed {
        let current = NetSample {
            timestamp_ms,
            interfaces: vec![InterfaceCounters {
                name: "en0".to_string(),
                rx_bytes,
                tx_bytes,
            }],
        };

        let speed = compute_speed(self.previous.as_ref(), &current, &self.rule);
        self.previous = Some(current);
        speed
    }

    fn reset(&mut self) {
        self.previous = None;
    }
}

#[no_mangle]
pub extern "C" fn tinynet_calculator_new() -> *mut TinyNetCalculator {
    Box::into_raw(Box::new(TinyNetCalculator::new()))
}

#[no_mangle]
pub extern "C" fn tinynet_calculator_free(calculator: *mut TinyNetCalculator) {
    if calculator.is_null() {
        return;
    }

    // SAFETY: `calculator` comes from `Box::into_raw` in `tinynet_calculator_new`
    // and is freed at most once by this function.
    unsafe {
        drop(Box::from_raw(calculator));
    }
}

#[no_mangle]
pub extern "C" fn tinynet_calculator_reset(calculator: *mut TinyNetCalculator) -> TinyNetFfiError {
    if calculator.is_null() {
        return TinyNetFfiError::NullPointer;
    }

    // SAFETY: null is checked above and pointer is expected to be a valid
    // `TinyNetCalculator` allocated by this library.
    let calculator_ref = unsafe { &mut *calculator };
    calculator_ref.reset();
    TinyNetFfiError::Ok
}

#[no_mangle]
pub extern "C" fn tinynet_calculator_push_totals(
    calculator: *mut TinyNetCalculator,
    timestamp_ms: i64,
    rx_bytes: u64,
    tx_bytes: u64,
    out_speed: *mut TinyNetSpeedFfi,
) -> TinyNetFfiError {
    if calculator.is_null() || out_speed.is_null() {
        return TinyNetFfiError::NullPointer;
    }

    // SAFETY: pointers are validated as non-null above and expected to be valid
    // for unique mutable access during this call.
    let calculator_ref = unsafe { &mut *calculator };
    let speed = calculator_ref.push_totals(timestamp_ms, rx_bytes, tx_bytes);

    let ffi_speed = TinyNetSpeedFfi {
        upload_bps: speed.upload_bps,
        download_bps: speed.download_bps,
    };

    // SAFETY: out_speed is validated non-null above and points to writable memory
    // provided by the caller for this output.
    unsafe {
        ptr::write(out_speed, ffi_speed);
    }

    TinyNetFfiError::Ok
}
