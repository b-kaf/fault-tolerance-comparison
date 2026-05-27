#ifndef HARNESS_FUZZ_COMMON_H
#define HARNESS_FUZZ_COMMON_H

#include <stdint.h>

volatile uint64_t harness_trial_seed;
volatile uint32_t harness_done;
volatile uint32_t harness_detected;
volatile uint32_t harness_corrected;
volatile uint32_t harness_safe_state;
volatile uint32_t harness_output;
volatile uint32_t harness_expected;
volatile uint32_t harness_error_code;
volatile uint32_t harness_fault_window_open;

static uint64_t harness_seed_state(void) {
    const uint64_t seed = harness_trial_seed;
    return seed == 0u ? UINT64_C(0x9e3779b97f4a7c15) : seed;
}

static uint64_t harness_splitmix64_next(uint64_t *state) {
    uint64_t z;

    *state += UINT64_C(0x9e3779b97f4a7c15);
    z = *state;
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}

static uint32_t harness_random_u32(uint64_t *state) {
    return (uint32_t)(harness_splitmix64_next(state) >> 32);
}

static void harness_open_fault_window(void) {
    __asm__ volatile("" ::: "memory");
    harness_fault_window_open = 1u;
    __asm__ volatile("" ::: "memory");
}

static void harness_close_fault_window(void) {
    __asm__ volatile("" ::: "memory");
    harness_fault_window_open = 0u;
    __asm__ volatile("" ::: "memory");
}

static void harness_finish(void) {
    __asm__ volatile("" ::: "memory");
    harness_done = 1u;
    __asm__ volatile("" ::: "memory");
    for (;;) {
        __asm__ volatile("nop");
    }
}

#endif
