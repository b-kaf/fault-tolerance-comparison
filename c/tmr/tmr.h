#ifndef TMR_H
#define TMR_H

#include <stdint.h>

typedef enum {
    TMR_OK = 0,
    TMR_ERR_NO_MAJORITY = 1,
} tmr_status_t;

/* ---------------- int ---------------- */

/* fault_count is a cumulative, saturating counter of reads in which the
 * three copies were not unanimous (single-fault and no-majority alike).
 * It is never reset implicitly — a clean read leaves it unchanged. To
 * clear, re-init the triplet. */
typedef struct {
    int a;
    int b;
    int c;
    uint32_t fault_count;
} tmr_int_t;

static inline void tmr_int_bump_fault_count(tmr_int_t *self) {
    if (self->fault_count != UINT32_MAX) {
        self->fault_count += 1;
    }
}

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
        *out = self->a;
        return TMR_OK;
    }
    if (self->a == self->b) {
        tmr_int_bump_fault_count(self);
        *out = self->a;
        return TMR_OK;
    }
    if (self->a == self->c) {
        tmr_int_bump_fault_count(self);
        *out = self->a;
        return TMR_OK;
    }
    if (self->b == self->c) {
        tmr_int_bump_fault_count(self);
        *out = self->b;
        return TMR_OK;
    }
    tmr_int_bump_fault_count(self);
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
