#ifndef RECOVERY_BLOCK_H
#define RECOVERY_BLOCK_H

#include <stdint.h>

#include "../checkpoint/checkpoint.h"

typedef enum {
    RECOVERY_BLOCK_PRIMARY_ACCEPTED = 0,
    RECOVERY_BLOCK_ALTERNATE_ACCEPTED = 1,
    RECOVERY_BLOCK_UNRECOVERABLE = 2,
    RECOVERY_BLOCK_CHECKPOINT_FAILED = 3,
    RECOVERY_BLOCK_RESTORE_FAILED = 4,
} recovery_block_status_t;

typedef struct {
    recovery_block_status_t status;
    checker_status_t checkpoint_check;
    checker_status_t primary_check;
    checker_status_t restore_check;
    checker_status_t alternate_check;
} recovery_block_result_t;

typedef void (*recovery_block_operation_t)(checker_record_t *active, void *context);
typedef void (*recovery_block_hook_t)(checkpoint_record_t *state, void *context);

enum {
    RECOVERY_BLOCK_SAMPLE_FAULT_NONE = 0u,
    RECOVERY_BLOCK_SAMPLE_FAULT_PRIMARY_RANGE = 1u << 0,
    RECOVERY_BLOCK_SAMPLE_FAULT_PRIMARY_CHECKSUM = 1u << 1,
    RECOVERY_BLOCK_SAMPLE_FAULT_ALTERNATE_RANGE = 1u << 2,
    RECOVERY_BLOCK_SAMPLE_FAULT_ALTERNATE_CHECKSUM = 1u << 3,
};

typedef struct {
    uint32_t sample;
    uint32_t faults;
} recovery_block_sample_update_t;

static inline uint32_t
recovery_block_status_code(recovery_block_status_t status) {
    return (uint32_t)status;
}

static inline recovery_block_result_t recovery_block_result_init(void) {
    const recovery_block_result_t result = {
        RECOVERY_BLOCK_UNRECOVERABLE,
        CHECKER_OK,
        CHECKER_OK,
        CHECKER_OK,
        CHECKER_OK,
    };
    return result;
}

static inline recovery_block_result_t recovery_block_run_with_hooks(
    checkpoint_record_t *state,
    recovery_block_operation_t primary,
    recovery_block_hook_t after_primary,
    recovery_block_operation_t alternate,
    recovery_block_hook_t after_alternate,
    void *context) {
    recovery_block_result_t result = recovery_block_result_init();

    result.checkpoint_check = checkpoint_record_capture(state);
    if (!checker_passed(result.checkpoint_check)) {
        result.status = RECOVERY_BLOCK_CHECKPOINT_FAILED;
        return result;
    }

    primary(&state->active, context);
    if (after_primary != 0) {
        after_primary(state, context);
    }

    result.primary_check = checker_record_validate(&state->active);
    if (checker_passed(result.primary_check)) {
        (void)checkpoint_record_capture(state);
        result.status = RECOVERY_BLOCK_PRIMARY_ACCEPTED;
        return result;
    }

    result.restore_check = checkpoint_record_restore(state);
    if (!checker_passed(result.restore_check)) {
        result.status = RECOVERY_BLOCK_RESTORE_FAILED;
        return result;
    }

    alternate(&state->active, context);
    if (after_alternate != 0) {
        after_alternate(state, context);
    }

    result.alternate_check = checker_record_validate(&state->active);
    if (checker_passed(result.alternate_check)) {
        (void)checkpoint_record_capture(state);
        result.status = RECOVERY_BLOCK_ALTERNATE_ACCEPTED;
        return result;
    }

    result.restore_check = checkpoint_record_restore(state);
    result.status = checker_passed(result.restore_check)
        ? RECOVERY_BLOCK_UNRECOVERABLE
        : RECOVERY_BLOCK_RESTORE_FAILED;
    return result;
}

static inline recovery_block_result_t recovery_block_run(
    checkpoint_record_t *state,
    recovery_block_operation_t primary,
    recovery_block_operation_t alternate,
    void *context) {
    return recovery_block_run_with_hooks(
        state,
        primary,
        0,
        alternate,
        0,
        context);
}

static inline uint32_t recovery_block_sample_primary_value(uint32_t sample) {
    const uint32_t reduced = sample % 700u;
    return 100u + (((reduced * 37u) + 17u) % 700u);
}

static inline uint32_t recovery_block_sample_alternate_value(uint32_t sample) {
    const uint32_t reduced = sample % 700u;
    uint32_t acc = 17u;

    for (uint32_t i = 0; i < 37u; ++i) {
        acc += reduced;
        acc %= 700u;
    }

    return 100u + acc;
}

static inline void recovery_block_sample_set_above_range(checker_record_t *active) {
    active->value = active->max + 1u;
    checker_record_refresh_checksum(active);
}

static inline void recovery_block_sample_primary(
    checker_record_t *active,
    void *context) {
    const recovery_block_sample_update_t *update =
        (const recovery_block_sample_update_t *)context;

    active->value = recovery_block_sample_primary_value(update->sample);
    checker_record_refresh_checksum(active);

    if ((update->faults & RECOVERY_BLOCK_SAMPLE_FAULT_PRIMARY_RANGE) != 0u) {
        recovery_block_sample_set_above_range(active);
    }
    if ((update->faults & RECOVERY_BLOCK_SAMPLE_FAULT_PRIMARY_CHECKSUM) != 0u) {
        active->checksum ^= 0x10u;
    }
}

static inline void recovery_block_sample_alternate(
    checker_record_t *active,
    void *context) {
    const recovery_block_sample_update_t *update =
        (const recovery_block_sample_update_t *)context;

    active->value = recovery_block_sample_alternate_value(update->sample);
    checker_record_refresh_checksum(active);

    if ((update->faults & RECOVERY_BLOCK_SAMPLE_FAULT_ALTERNATE_RANGE) != 0u) {
        recovery_block_sample_set_above_range(active);
    }
    if ((update->faults & RECOVERY_BLOCK_SAMPLE_FAULT_ALTERNATE_CHECKSUM) != 0u) {
        active->checksum ^= 0x10u;
    }
}

static inline recovery_block_result_t recovery_block_sample_update(
    checkpoint_record_t *state,
    recovery_block_sample_update_t update) {
    return recovery_block_run(
        state,
        recovery_block_sample_primary,
        recovery_block_sample_alternate,
        &update);
}

#endif
