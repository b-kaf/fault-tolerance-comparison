#include <stdint.h>

#include "test.h"
#include "tmr.h"

static void test_clean_read_returns_value(void) {
    printf("Tmr: clean read returns value\n");
    tmr_int_t t = tmr_int_init(42);
    int val = 0;
    tmr_status_t s = tmr_int_read(&t, &val);
    CHECK(s == TMR_OK);
    CHECK(val == 42);
}

static void test_single_fault_majority_wins(void) {
    printf("Tmr: single fault — majority wins\n");
    tmr_int_t t = tmr_int_init(100);
    tmr_int_inject_fault_a(&t, 0xFF);
    int val = 0;
    tmr_status_t s = tmr_int_read(&t, &val); /* b==c==100, majority wins */
    CHECK(s == TMR_OK);
    CHECK(val == 100);
    CHECK(t.fault_count == 1);
}

static void test_no_majority_error_returned(void) {
    printf("Tmr: no majority — error returned\n");
    tmr_int_t t = tmr_int_init(0);
    tmr_int_inject_all(&t, 1, 2, 3);
    int val = 0;
    tmr_status_t s = tmr_int_read(&t, &val);
    CHECK(s == TMR_ERR_NO_MAJORITY);
}

static void test_write_restores_clean_state(void) {
    printf("Tmr: write restores clean state\n");
    tmr_int_t t = tmr_int_init(0);
    tmr_int_inject_all(&t, 1, 2, 3);
    tmr_int_write(&t, 99);
    int val = 0;
    tmr_status_t s = tmr_int_read(&t, &val);
    CHECK(s == TMR_OK);
    CHECK(val == 99);
}

static void test_clean_read_does_not_reset_fault_count(void) {
    printf("Tmr: clean read does not reset fault count\n");
    tmr_int_t t = tmr_int_init(7);
    tmr_int_inject_fault_a(&t, 0xFF);
    int val = 0;
    (void)tmr_int_read(&t, &val);
    CHECK(t.fault_count == 1);

    tmr_int_write(&t, 7); /* restores clean state without touching counter */
    (void)tmr_int_read(&t, &val);
    CHECK(t.fault_count == 1);
}

static void test_fault_count_saturates_at_u32_max(void) {
    printf("Tmr: fault count saturates at UINT32_MAX\n");
    tmr_int_t t = tmr_int_init(7);
    t.fault_count = UINT32_MAX;
    tmr_int_inject_fault_a(&t, 0xFF);
    int val = 0;
    (void)tmr_int_read(&t, &val);
    CHECK(t.fault_count == UINT32_MAX);
}

int main(void) {
    test_clean_read_returns_value();
    test_single_fault_majority_wins();
    test_no_majority_error_returned();
    test_write_restores_clean_state();
    test_clean_read_does_not_reset_fault_count();
    test_fault_count_saturates_at_u32_max();

    return test_finish("");
}
