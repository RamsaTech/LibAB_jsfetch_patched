/*
 * Minimal stdbit.h shim for compilers/libc that lack C23 <stdbit.h>.
 * Provides stdc_count_ones and stdc_trailing_zeros using compiler builtins.
 */
#ifndef STDBIT_SHIM_H
#define STDBIT_SHIM_H

#include <limits.h>

/* stdc_count_ones: count the number of 1-bits (popcount) */
#define stdc_count_ones(x)                                                     \
  _Generic((x),                                                                \
      unsigned int: __builtin_popcount,                                        \
      unsigned long: __builtin_popcountl,                                      \
      unsigned long long: __builtin_popcountll)(x)

/* stdc_trailing_zeros: count trailing zero bits */
#define stdc_trailing_zeros(x)                                                 \
  _Generic((x),                                                                \
      unsigned int: __builtin_ctz,                                             \
      unsigned long: __builtin_ctzl,                                           \
      unsigned long long: __builtin_ctzll)(x)

/* stdc_leading_zeros: count leading zero bits */
#define stdc_leading_zeros(x)                                                  \
  _Generic((x),                                                                \
      unsigned int: __builtin_clz,                                             \
      unsigned long: __builtin_clzl,                                           \
      unsigned long long: __builtin_clzll)(x)

#endif /* STDBIT_SHIM_H */
