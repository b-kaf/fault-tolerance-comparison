#ifndef TEST_H
#define TEST_H

#include <stdio.h>

static int g_failed = 0;
static int g_total = 0;

#define CHECK(expr) do {                                                       \
    g_total += 1;                                                              \
    if (!(expr)) {                                                             \
        g_failed += 1;                                                         \
        fprintf(stderr, "  FAIL: %s:%d: %s\n", __FILE__, __LINE__, #expr);     \
    }                                                                          \
} while (0)

static inline int test_finish(const char *label) {
    if (label != NULL && label[0] != '\0') {
        printf("\n%d/%d %s checks passed\n", g_total - g_failed, g_total, label);
    } else {
        printf("\n%d/%d checks passed\n", g_total - g_failed, g_total);
    }

    return g_failed == 0 ? 0 : 1;
}

#endif
