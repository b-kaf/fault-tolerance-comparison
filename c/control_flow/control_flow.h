#ifndef CONTROL_FLOW_H
#define CONTROL_FLOW_H

#include <stdint.h>

typedef enum {
    CONTROL_FLOW_OK = 0,
    CONTROL_FLOW_ERR_INVALID_TRANSITION = 1,
    CONTROL_FLOW_ERR_BAD_SIGNATURE = 2,
    CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL = 3,
} control_flow_status_t;

typedef enum {
    CONTROL_FLOW_PHASE_START = 0,
    CONTROL_FLOW_PHASE_READ_INPUT = 1,
    CONTROL_FLOW_PHASE_COMPUTE = 2,
    CONTROL_FLOW_PHASE_VALIDATE = 3,
    CONTROL_FLOW_PHASE_COMMIT = 4,
    CONTROL_FLOW_PHASE_DONE = 5,
} control_flow_phase_t;

typedef struct {
    uint32_t phase;
    uint32_t signature;
    uint32_t transitions;
} control_flow_monitor_t;

static inline uint32_t
control_flow_status_code(control_flow_status_t status) {
    return (uint32_t)status;
}

static inline uint32_t control_flow_phase_code(control_flow_phase_t phase) {
    return (uint32_t)phase;
}

static inline int control_flow_passed(control_flow_status_t status) {
    return status == CONTROL_FLOW_OK;
}

static inline uint32_t control_flow_rotl_u32(uint32_t value, unsigned shift) {
    return (value << shift) | (value >> (32u - shift));
}

static inline uint32_t control_flow_phase_signature(uint32_t phase) {
    uint32_t signature = 0xc0def00du;

    signature ^= phase * 0x9e3779b9u;
    signature = control_flow_rotl_u32(signature, (phase % 13u) + 3u);
    signature ^= 0xa5a50000u | phase;
    return signature;
}

static inline control_flow_monitor_t control_flow_monitor_init(void) {
    const control_flow_monitor_t monitor = {
        CONTROL_FLOW_PHASE_START,
        control_flow_phase_signature(CONTROL_FLOW_PHASE_START),
        0u,
    };
    return monitor;
}

static inline control_flow_status_t control_flow_monitor_validate_current(
    const control_flow_monitor_t *self,
    control_flow_phase_t expected_phase) {
    if (self->phase != (uint32_t)expected_phase) {
        return CONTROL_FLOW_ERR_INVALID_TRANSITION;
    }
    if (self->signature != control_flow_phase_signature(expected_phase)) {
        return CONTROL_FLOW_ERR_BAD_SIGNATURE;
    }
    return CONTROL_FLOW_OK;
}

static inline control_flow_status_t control_flow_monitor_advance(
    control_flow_monitor_t *self,
    control_flow_phase_t expected_from,
    control_flow_phase_t next_phase) {
    const control_flow_status_t current_status =
        control_flow_monitor_validate_current(self, expected_from);
    if (!control_flow_passed(current_status)) {
        return current_status;
    }

    self->phase = (uint32_t)next_phase;
    self->signature = control_flow_phase_signature(next_phase);
    self->transitions += 1u;
    return CONTROL_FLOW_OK;
}

static inline control_flow_status_t control_flow_monitor_finish(
    const control_flow_monitor_t *self) {
    if (self->phase != CONTROL_FLOW_PHASE_DONE) {
        return CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL;
    }
    if (self->signature != control_flow_phase_signature(CONTROL_FLOW_PHASE_DONE)) {
        return CONTROL_FLOW_ERR_BAD_SIGNATURE;
    }
    return CONTROL_FLOW_OK;
}

#endif
