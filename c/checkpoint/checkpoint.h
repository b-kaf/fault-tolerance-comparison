#ifndef CHECKPOINT_H
#define CHECKPOINT_H

#include <stdint.h>

#include "../checker/checker.h"

typedef enum {
  CHECKPOINT_RESTART_COMMITTED = 0,
  CHECKPOINT_RESTART_RESTORED = 1,
  CHECKPOINT_RESTART_RESTORE_FAILED = 2,
} checkpoint_restart_status_t;

typedef struct {
  checkpoint_restart_status_t status;
  checker_status_t active_check;
  checker_status_t checkpoint_check;
} checkpoint_restart_result_t;

typedef struct {
  checker_record_t active;
  checker_record_t checkpoint;
} checkpoint_record_t;

static inline uint32_t
checkpoint_restart_status_code(checkpoint_restart_status_t status) {
  return (uint32_t)status;
}

static inline checkpoint_record_t
checkpoint_record_init(checker_record_t initial) {
  checkpoint_record_t self = {
      initial,
      initial,
  };
  return self;
}

static inline checker_status_t
checkpoint_record_capture(checkpoint_record_t *self) {
  const checker_status_t active_check = checker_record_validate(&self->active);
  if (checker_passed(active_check)) {
    self->checkpoint = self->active;
  }
  return active_check;
}

static inline checker_status_t
checkpoint_record_restore(checkpoint_record_t *self) {
  const checker_status_t checkpoint_check =
      checker_record_validate(&self->checkpoint);
  if (checker_passed(checkpoint_check)) {
    self->active = self->checkpoint;
  }
  return checkpoint_check;
}

static inline checkpoint_restart_result_t
checkpoint_record_commit_or_restart(checkpoint_record_t *self) {
  const checker_status_t active_check = checker_record_validate(&self->active);
  if (checker_passed(active_check)) {
    self->checkpoint = self->active;
    const checkpoint_restart_result_t result = {
        CHECKPOINT_RESTART_COMMITTED,
        active_check,
        CHECKER_OK,
    };
    return result;
  }

  const checker_status_t checkpoint_check =
      checker_record_validate(&self->checkpoint);
  if (checker_passed(checkpoint_check)) {
    self->active = self->checkpoint;
    const checkpoint_restart_result_t result = {
        CHECKPOINT_RESTART_RESTORED,
        active_check,
        checkpoint_check,
    };
    return result;
  }

  const checkpoint_restart_result_t result = {
      CHECKPOINT_RESTART_RESTORE_FAILED,
      active_check,
      checkpoint_check,
  };
  return result;
}

#endif
