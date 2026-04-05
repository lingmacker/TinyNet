#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InterfaceCounters {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetSample {
    pub timestamp_ms: i64,
    pub interfaces: Vec<InterfaceCounters>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Speed {
    pub download_bps: u64,
    pub upload_bps: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InterfaceFilterRule {
    IncludeOnly(Vec<String>),
    Exclude(Vec<String>),
    ExcludeLoopbackAndVirtual,
}

fn is_virtual_or_loopback(name: &str) -> bool {
    name.starts_with("lo")
        || name.starts_with("utun")
        || name.starts_with("awdl")
        || name.starts_with("bridge")
        || name.starts_with("llw")
}

fn is_allowed(name: &str, rule: &InterfaceFilterRule) -> bool {
    match rule {
        InterfaceFilterRule::IncludeOnly(allowed) => {
            allowed.iter().any(|item| item.as_str() == name)
        }
        InterfaceFilterRule::Exclude(blocked) => !blocked.iter().any(|item| item.as_str() == name),
        InterfaceFilterRule::ExcludeLoopbackAndVirtual => !is_virtual_or_loopback(name),
    }
}

fn delta_bytes(prev: &NetSample, curr: &NetSample, rule: &InterfaceFilterRule) -> (u64, u64) {
    curr.interfaces
        .iter()
        .filter(|iface| is_allowed(iface.name.as_str(), rule))
        .fold((0_u64, 0_u64), |(rx_sum, tx_sum), curr_iface| {
            let prev_iface = prev
                .interfaces
                .iter()
                .find(|item| item.name == curr_iface.name);

            let prev_rx = prev_iface.map_or(curr_iface.rx_bytes, |item| item.rx_bytes);
            let prev_tx = prev_iface.map_or(curr_iface.tx_bytes, |item| item.tx_bytes);

            (
                rx_sum.saturating_add(curr_iface.rx_bytes.saturating_sub(prev_rx)),
                tx_sum.saturating_add(curr_iface.tx_bytes.saturating_sub(prev_tx)),
            )
        })
}

pub fn compute_speed(
    prev: Option<&NetSample>,
    curr: &NetSample,
    rule: &InterfaceFilterRule,
) -> Speed {
    let Some(previous) = prev else {
        return Speed {
            download_bps: 0,
            upload_bps: 0,
        };
    };

    let dt_ms = curr.timestamp_ms - previous.timestamp_ms;
    if dt_ms <= 0 {
        return Speed {
            download_bps: 0,
            upload_bps: 0,
        };
    }

    let (rx_delta, tx_delta) = delta_bytes(previous, curr, rule);
    let dt_seconds = (dt_ms as f64) / 1000.0;

    if dt_seconds <= 0.0 {
        return Speed {
            download_bps: 0,
            upload_bps: 0,
        };
    }

    Speed {
        download_bps: (rx_delta as f64 / dt_seconds) as u64,
        upload_bps: (tx_delta as f64 / dt_seconds) as u64,
    }
}
