#ifndef TINYNET_NET_SPEED_FFI_H
#define TINYNET_NET_SPEED_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TinyNetCalculator TinyNetCalculator;

typedef struct TinyNetSpeedFfi {
    uint64_t upload_bps;
    uint64_t download_bps;
} TinyNetSpeedFfi;

typedef enum TinyNetFfiError {
    TINYNET_FFI_OK = 0,
    TINYNET_FFI_NULL_POINTER = 1,
} TinyNetFfiError;

TinyNetCalculator *tinynet_calculator_new(void);
void tinynet_calculator_free(TinyNetCalculator *calculator);
TinyNetFfiError tinynet_calculator_reset(TinyNetCalculator *calculator);
TinyNetFfiError tinynet_calculator_push_totals(
    TinyNetCalculator *calculator,
    int64_t timestamp_ms,
    uint64_t rx_bytes,
    uint64_t tx_bytes,
    TinyNetSpeedFfi *out_speed
);

#ifdef __cplusplus
}
#endif

#endif
