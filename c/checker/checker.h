#ifndef CHECKER_H
#define CHECKER_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
    CHECKER_OK = 0,
    CHECKER_ERR_BELOW_MIN = 1,
    CHECKER_ERR_ABOVE_MAX = 2,
    CHECKER_ERR_INVALID_LENGTH = 3,
    CHECKER_ERR_INVALID_CHECKSUM = 4,
    CHECKER_ERR_INCONSISTENT_FIELDS = 5,
    CHECKER_ERR_INVALID_TAG = 6,
} checker_status_t;

typedef enum {
    CHECKER_TAG_IDLE = 0,
    CHECKER_TAG_SAMPLE = 1,
    CHECKER_TAG_COMMAND = 2,
} checker_sample_tag_t;

typedef struct {
    uint32_t tag;
    uint32_t value;
    uint32_t min;
    uint32_t max;
    uint32_t length;
    uint32_t capacity;
    uint32_t checksum;
} checker_record_t;

static inline int checker_passed(checker_status_t status) {
    return status == CHECKER_OK;
}

static inline uint32_t checker_status_code(checker_status_t status) {
    return (uint32_t)status;
}

static inline checker_status_t checker_require_range_u32(
    uint32_t value,
    uint32_t min,
    uint32_t max) {
    if (min > max) {
        return CHECKER_ERR_INCONSISTENT_FIELDS;
    }
    if (value < min) {
        return CHECKER_ERR_BELOW_MIN;
    }
    if (value > max) {
        return CHECKER_ERR_ABOVE_MAX;
    }
    return CHECKER_OK;
}

static inline checker_status_t checker_require_length_u32(
    uint32_t length,
    uint32_t capacity) {
    if (length > capacity) {
        return CHECKER_ERR_INVALID_LENGTH;
    }
    return CHECKER_OK;
}

static inline checker_status_t checker_require_equal_u32(
    uint32_t actual,
    uint32_t expected) {
    if (actual != expected) {
        return CHECKER_ERR_INCONSISTENT_FIELDS;
    }
    return CHECKER_OK;
}

static inline uint32_t checker_rotl_u32(uint32_t value, unsigned shift) {
    return (value << shift) | (value >> (32u - shift));
}

static inline uint32_t checker_checksum_words_u32(
    const uint32_t *words,
    size_t len) {
    uint32_t hash = 0x811c9dc5u;

    for (size_t i = 0; i < len; ++i) {
        hash ^= words[i];
        hash *= 0x01000193u;
        hash = checker_rotl_u32(hash, 5);
    }

    return hash;
}

static inline checker_status_t checker_require_checksum_u32(
    uint32_t expected,
    const uint32_t *words,
    size_t len) {
    if (checker_checksum_words_u32(words, len) != expected) {
        return CHECKER_ERR_INVALID_CHECKSUM;
    }
    return CHECKER_OK;
}

static inline checker_status_t checker_require_sample_tag(uint32_t raw) {
    switch (raw) {
    case CHECKER_TAG_IDLE:
    case CHECKER_TAG_SAMPLE:
    case CHECKER_TAG_COMMAND:
        return CHECKER_OK;
    default:
        return CHECKER_ERR_INVALID_TAG;
    }
}

static inline uint32_t checker_record_compute_checksum(
    const checker_record_t *self) {
    const uint32_t words[] = {
        self->tag,
        self->value,
        self->min,
        self->max,
        self->length,
        self->capacity,
    };
    return checker_checksum_words_u32(words, sizeof(words) / sizeof(words[0]));
}

static inline void checker_record_refresh_checksum(checker_record_t *self) {
    self->checksum = checker_record_compute_checksum(self);
}

static inline checker_record_t checker_record_init(
    checker_sample_tag_t tag,
    uint32_t value,
    uint32_t min,
    uint32_t max,
    uint32_t length,
    uint32_t capacity) {
    checker_record_t self = {
        (uint32_t)tag,
        value,
        min,
        max,
        length,
        capacity,
        0,
    };
    checker_record_refresh_checksum(&self);
    return self;
}

static inline checker_status_t checker_record_validate(
    const checker_record_t *self) {
    const checker_status_t tag_status = checker_require_sample_tag(self->tag);
    if (!checker_passed(tag_status)) {
        return tag_status;
    }

    const checker_status_t range_status =
        checker_require_range_u32(self->value, self->min, self->max);
    if (!checker_passed(range_status)) {
        return range_status;
    }

    const checker_status_t length_status =
        checker_require_length_u32(self->length, self->capacity);
    if (!checker_passed(length_status)) {
        return length_status;
    }

    const uint32_t words[] = {
        self->tag,
        self->value,
        self->min,
        self->max,
        self->length,
        self->capacity,
    };
    return checker_require_checksum_u32(
        self->checksum,
        words,
        sizeof(words) / sizeof(words[0]));
}

#endif
