#ifndef TMR_H
#define TMR_H

#include <stdint.h>

typedef enum {
    TMR_OK = 0,
    TMR_ERR_NO_MAJORITY = 1,
} tmr_status_t;

/* ---------------- int ---------------- */

typedef struct {
    int a;
    int b;
    int c;
    uint32_t fault_count;
} tmr_int_t;

static inline tmr_int_t tmr_int_init(int val) {
    tmr_int_t self = { val, val, val, 0 };
    return self;
}

static inline void tmr_int_write(tmr_int_t *self, int val) {
    self->a = val;
    self->b = val;
    self->c = val;
}

/* Majority vote. On success writes the agreed value to *out and
 * returns TMR_OK. If all three disagree, returns TMR_ERR_NO_MAJORITY. */
static inline tmr_status_t tmr_int_read(tmr_int_t *self, int *out) {
    if (self->a == self->b && self->b == self->c) {
        self->fault_count = 0;
        *out = self->a;
        return TMR_OK;
    }
    if (self->a == self->b) {
        self->fault_count += 1;
        *out = self->a;
        return TMR_OK;
    }
    if (self->a == self->c) {
        self->fault_count += 1;
        *out = self->a;
        return TMR_OK;
    }
    if (self->b == self->c) {
        self->fault_count += 1;
        *out = self->b;
        return TMR_OK;
    }
    self->fault_count += 1;
    return TMR_ERR_NO_MAJORITY;
}

/* Inject a fault into copy A — for test harness use only. */
static inline void tmr_int_inject_fault_a(tmr_int_t *self, int bad_val) {
    self->a = bad_val;
}

/* Inject a fault into all copies — for test harness use only. */
static inline void tmr_int_inject_all(tmr_int_t *self, int va, int vb, int vc) {
    self->a = va;
    self->b = vb;
    self->c = vc;
}
#endif
