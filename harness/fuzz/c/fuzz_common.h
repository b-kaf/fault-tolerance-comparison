#ifndef HARNESS_FUZZ_COMMON_H
#define HARNESS_FUZZ_COMMON_H

#include <stdint.h>

extern volatile uint64_t harness_trial_seed;
extern volatile uint32_t harness_done;
extern volatile uint32_t harness_detected;
extern volatile uint32_t harness_corrected;
extern volatile uint32_t harness_safe_state;
extern volatile uint32_t harness_output;
extern volatile uint32_t harness_expected;
extern volatile uint32_t harness_error_code;
extern volatile uint32_t harness_fault_window_open;

uint64_t harness_seed_state(void);
uint64_t harness_splitmix64_next(uint64_t *state);
uint32_t harness_random_u32(uint64_t *state);

void harness_open_fault_window(void);
void harness_close_fault_window(void);
void harness_finish(void);

#endif
