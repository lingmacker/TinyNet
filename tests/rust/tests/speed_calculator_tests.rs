use net_speed_core::{
    compute_speed, InterfaceCounters, InterfaceFilterRule, NetSample,
};

fn sample(ts_ms: i64, interfaces: Vec<(&str, u64, u64)>) -> NetSample {
    NetSample {
        timestamp_ms: ts_ms,
        interfaces: interfaces
            .into_iter()
            .map(|(name, rx, tx)| InterfaceCounters {
                name: name.to_string(),
                rx_bytes: rx,
                tx_bytes: tx,
            })
            .collect(),
    }
}

#[test]
fn first_sample_returns_zero_speed() {
    let curr = sample(1_000, vec![("en0", 1_000, 2_000)]);

    let speed = compute_speed(None, &curr, &InterfaceFilterRule::ExcludeLoopbackAndVirtual);

    assert_eq!(speed.download_bps, 0);
    assert_eq!(speed.upload_bps, 0);
}

#[test]
fn computes_speed_from_delta_bytes_over_dt() {
    let prev = sample(1_000, vec![("en0", 1_000, 2_000)]);
    let curr = sample(3_000, vec![("en0", 5_000, 6_000)]);

    let speed = compute_speed(
        Some(&prev),
        &curr,
        &InterfaceFilterRule::ExcludeLoopbackAndVirtual,
    );

    assert_eq!(speed.download_bps, 2_000);
    assert_eq!(speed.upload_bps, 2_000);
}

#[test]
fn clamps_negative_delta_to_zero_on_counter_decrease_or_wrap() {
    let prev = sample(1_000, vec![("en0", 10_000, 10_000)]);
    let curr = sample(2_000, vec![("en0", 1_000, 12_000)]);

    let speed = compute_speed(
        Some(&prev),
        &curr,
        &InterfaceFilterRule::ExcludeLoopbackAndVirtual,
    );

    assert_eq!(speed.download_bps, 0);
    assert_eq!(speed.upload_bps, 2_000);
}

#[test]
fn returns_zero_speed_when_dt_is_zero_or_negative() {
    let prev = sample(2_000, vec![("en0", 1_000, 2_000)]);
    let curr_same = sample(2_000, vec![("en0", 5_000, 6_000)]);
    let curr_older = sample(1_500, vec![("en0", 5_000, 6_000)]);

    let speed_same = compute_speed(
        Some(&prev),
        &curr_same,
        &InterfaceFilterRule::ExcludeLoopbackAndVirtual,
    );
    let speed_older = compute_speed(
        Some(&prev),
        &curr_older,
        &InterfaceFilterRule::ExcludeLoopbackAndVirtual,
    );

    assert_eq!(speed_same.download_bps, 0);
    assert_eq!(speed_same.upload_bps, 0);
    assert_eq!(speed_older.download_bps, 0);
    assert_eq!(speed_older.upload_bps, 0);
}

#[test]
fn filters_interfaces_by_rule_before_aggregation() {
    let prev = sample(
        1_000,
        vec![("en0", 1_000, 1_000), ("lo0", 100_000, 100_000), ("utun2", 50_000, 50_000)],
    );
    let curr = sample(
        2_000,
        vec![("en0", 2_000, 3_000), ("lo0", 200_000, 200_000), ("utun2", 60_000, 60_000)],
    );

    let speed = compute_speed(
        Some(&prev),
        &curr,
        &InterfaceFilterRule::ExcludeLoopbackAndVirtual,
    );

    assert_eq!(speed.download_bps, 1_000);
    assert_eq!(speed.upload_bps, 2_000);
}

#[test]
fn all_interfaces_filtered_out_returns_zero() {
    let prev = sample(1_000, vec![("lo0", 1_000, 1_000)]);
    let curr = sample(2_000, vec![("lo0", 5_000, 7_000)]);

    let speed = compute_speed(
        Some(&prev),
        &curr,
        &InterfaceFilterRule::IncludeOnly(vec!["en0".to_string()]),
    );

    assert_eq!(speed.download_bps, 0);
    assert_eq!(speed.upload_bps, 0);
}

#[test]
fn missing_interface_in_next_sample_treated_as_zero_delta_not_negative() {
    let prev = sample(1_000, vec![("en0", 1_000, 1_000), ("en1", 2_000, 2_000)]);
    let curr = sample(2_000, vec![("en0", 2_500, 3_000)]);

    let speed = compute_speed(
        Some(&prev),
        &curr,
        &InterfaceFilterRule::IncludeOnly(vec!["en0".to_string(), "en1".to_string()]),
    );

    assert_eq!(speed.download_bps, 1_500);
    assert_eq!(speed.upload_bps, 2_000);
}
