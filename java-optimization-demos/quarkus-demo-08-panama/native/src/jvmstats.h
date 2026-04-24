#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * jvmstats — native JVM workload analysis library
 * C++20 implementation, C ABI for Panama FFM compatibility
 *
 * All functions use C linkage (extern "C") so Panama's Linker
 * can locate and call them by symbol name. The C++20 features
 * (std::span, std::ranges, structured bindings) live in the .cpp
 * implementation — the header exposes a clean C ABI.
 */

/**
 * Analyse an array of GC pause times (in ms) and recommend a GC algorithm.
 *
 * @param pauses_ms   pointer to array of pause durations in milliseconds
 * @param count       number of elements in the array
 * @param out_p50     output: 50th percentile pause (median)
 * @param out_p99     output: 99th percentile pause
 * @param out_max     output: maximum observed pause
 * @return GC recommendation: 0=G1GC, 1=Shenandoah, 2=ZGC
 */
int jvmstats_recommend_gc(
    const double* pauses_ms,
    int32_t       count,
    double*       out_p50,
    double*       out_p99,
    double*       out_max);

/**
 * Compute CPU utilisation statistics over a time window.
 *
 * @param samples     array of CPU utilisation samples (0.0–100.0)
 * @param count       number of samples
 * @param out_mean    output: arithmetic mean
 * @param out_stddev  output: standard deviation
 * @param out_p95     output: 95th percentile
 * @return 1 if the profile looks GC-dominated (p95/mean ratio > 3), 0 otherwise
 */
int jvmstats_cpu_profile(
    const double* samples,
    int32_t       count,
    double*       out_mean,
    double*       out_stddev,
    double*       out_p95);

/**
 * Estimate right-sized memory request from observed RSS samples.
 *
 * Applies p99 + 25% headroom, rounded to nearest 64MB, with a
 * minimum floor of 256MB.
 *
 * @param rss_mb_samples  array of RSS observations in megabytes
 * @param count           number of observations
 * @return recommended memory request in megabytes
 */
int32_t jvmstats_recommend_memory_mb(
    const double* rss_mb_samples,
    int32_t       count);

#ifdef __cplusplus
} // extern "C"
#endif
