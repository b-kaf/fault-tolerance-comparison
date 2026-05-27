#include <stdint.h>

#include "fuzz_common.h"
#include "../../common/harness_abi.h"
#include "../../../c/tmr/tmr.h"

_Static_assert((int)TMR_OK == HARNESS_STATUS_OK,
    "tmr_status_t::TMR_OK must match HARNESS_STATUS_OK");
_Static_assert((int)TMR_ERR_NO_MAJORITY == HARNESS_STATUS_NO_MAJORITY,
    "tmr_status_t::TMR_ERR_NO_MAJORITY must match HARNESS_STATUS_NO_MAJORITY");

volatile tmr_int_t harness_fuzz_tmr_state;

static uint32_t sample_value(uint64_t *rng) {
    return 0x5a5a0000u ^ harness_random_u32(rng);
}

void harness_main(void) {
    uint64_t rng = harness_seed_state();
    const uint32_t expected = sample_value(&rng);
    int value = 0;
    tmr_status_t status;

    harness_expected = expected;
    harness_fuzz_tmr_state = tmr_int_init((int)expected);

    harness_open_fault_window();
    status = tmr_int_read((tmr_int_t *)&harness_fuzz_tmr_state, &value);
    harness_close_fault_window();

    if (status == TMR_OK) {
        harness_output = (uint32_t)value;
        if (harness_fuzz_tmr_state.fault_count != 0u) {
            harness_detected = 1u;
            if (harness_output == harness_expected) {
                harness_corrected = 1u;
            }
        }
    } else {
        harness_detected = 1u;
        harness_safe_state = 1u;
        harness_error_code = HARNESS_STATUS_NO_MAJORITY;
    }

    harness_finish();
}
