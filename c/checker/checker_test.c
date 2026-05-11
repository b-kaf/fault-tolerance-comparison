#include <stdint.h>

#include "checker.h"
#include "test.h"

static void test_status_codes_are_stable_abi_values(void) {
    printf("Checker: status codes are stable ABI values\n");
    CHECK(checker_status_code(CHECKER_OK) == 0);
    CHECK(checker_status_code(CHECKER_ERR_BELOW_MIN) == 1);
    CHECK(checker_status_code(CHECKER_ERR_ABOVE_MAX) == 2);
    CHECK(checker_status_code(CHECKER_ERR_INVALID_LENGTH) == 3);
    CHECK(checker_status_code(CHECKER_ERR_INVALID_CHECKSUM) == 4);
    CHECK(checker_status_code(CHECKER_ERR_INCONSISTENT_FIELDS) == 5);
    CHECK(checker_status_code(CHECKER_ERR_INVALID_TAG) == 6);
}

static void test_range_check_accepts_inclusive_bounds(void) {
    printf("Checker: range check accepts inclusive bounds\n");
    CHECK(checker_require_range_u32(10, 10, 20) == CHECKER_OK);
    CHECK(checker_require_range_u32(20, 10, 20) == CHECKER_OK);
}

static void test_range_check_reports_low_high_and_invalid_bounds(void) {
    printf("Checker: range check reports low high and invalid bounds\n");
    CHECK(checker_require_range_u32(9, 10, 20) == CHECKER_ERR_BELOW_MIN);
    CHECK(checker_require_range_u32(21, 10, 20) == CHECKER_ERR_ABOVE_MAX);
    CHECK(checker_require_range_u32(10, 20, 10) == CHECKER_ERR_INCONSISTENT_FIELDS);
}

static void test_length_check_rejects_length_beyond_capacity(void) {
    printf("Checker: length check rejects length beyond capacity\n");
    CHECK(checker_require_length_u32(4, 4) == CHECKER_OK);
    CHECK(checker_require_length_u32(5, 4) == CHECKER_ERR_INVALID_LENGTH);
}

static void test_checksum_check_detects_changed_words(void) {
    printf("Checker: checksum check detects changed words\n");
    const uint32_t words[] = { 1, 2, 3, 4 };
    const uint32_t checksum =
        checker_checksum_words_u32(words, sizeof(words) / sizeof(words[0]));

    CHECK(checker_require_checksum_u32(
        checksum,
        words,
        sizeof(words) / sizeof(words[0])) == CHECKER_OK);

    const uint32_t changed[] = { 1, 2, 3, 5 };
    CHECK(checker_require_checksum_u32(
        checksum,
        changed,
        sizeof(changed) / sizeof(changed[0])) == CHECKER_ERR_INVALID_CHECKSUM);
}

static void test_sample_tag_check_rejects_unknown_tag_values(void) {
    printf("Checker: sample tag check rejects unknown tag values\n");
    CHECK(checker_require_sample_tag(CHECKER_TAG_COMMAND) == CHECKER_OK);
    CHECK(checker_require_sample_tag(99) == CHECKER_ERR_INVALID_TAG);
}

static void test_checked_record_validates_clean_state(void) {
    printf("Checker: checked record validates clean state\n");
    const checker_record_t record =
        checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 3, 8);
    CHECK(checker_record_validate(&record) == CHECKER_OK);
}

static void test_checked_record_detects_semantic_field_failures_before_checksum(void) {
    printf("Checker: checked record detects semantic field failures before checksum\n");
    checker_record_t record =
        checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 3, 8);

    record.value = 101;
    CHECK(checker_record_validate(&record) == CHECKER_ERR_ABOVE_MAX);

    record = checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 9, 8);
    CHECK(checker_record_validate(&record) == CHECKER_ERR_INVALID_LENGTH);

    record = checker_record_init(CHECKER_TAG_SAMPLE, 50, 100, 10, 3, 8);
    CHECK(checker_record_validate(&record) == CHECKER_ERR_INCONSISTENT_FIELDS);
}

static void test_checked_record_detects_checksum_only_corruption(void) {
    printf("Checker: checked record detects checksum-only corruption\n");
    checker_record_t record =
        checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 3, 8);
    record.checksum ^= 0x10;
    CHECK(checker_record_validate(&record) == CHECKER_ERR_INVALID_CHECKSUM);
}

static void test_checked_record_can_refresh_checksum_after_valid_mutation(void) {
    printf("Checker: checked record can refresh checksum after valid mutation\n");
    checker_record_t record =
        checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 3, 8);
    record.value = 60;
    CHECK(checker_record_validate(&record) == CHECKER_ERR_INVALID_CHECKSUM);

    checker_record_refresh_checksum(&record);
    CHECK(checker_record_validate(&record) == CHECKER_OK);
}

int main(void) {
    test_status_codes_are_stable_abi_values();
    test_range_check_accepts_inclusive_bounds();
    test_range_check_reports_low_high_and_invalid_bounds();
    test_length_check_rejects_length_beyond_capacity();
    test_checksum_check_detects_changed_words();
    test_sample_tag_check_rejects_unknown_tag_values();
    test_checked_record_validates_clean_state();
    test_checked_record_detects_semantic_field_failures_before_checksum();
    test_checked_record_detects_checksum_only_corruption();
    test_checked_record_can_refresh_checksum_after_valid_mutation();

    return test_finish("checker");
}
