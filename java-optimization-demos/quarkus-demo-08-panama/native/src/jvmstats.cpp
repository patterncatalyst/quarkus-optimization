/**
 * jvmstats.cpp — JVM workload analysis library
 * C++20: std::span, std::ranges, structured bindings, concepts
 *
 * Compiled to a shared library (.so / .dylib) and called from
 * Quarkus via the Java Foreign Function & Memory API (Panama FFM).
 * No JNI, no wrapper code — Panama handles the ABI bridging.
 */

#include "jvmstats.h"

#include <algorithm>
#include <cmath>
#include <numeric>
#include <span>
#include <vector>
#include <ranges>

// ── C++20 helpers ────────────────────────────────────────────────────────────

namespace {

/**
 * Compute a percentile value from a sorted vector.
 * Uses nearest-rank method — consistent with Java's Micrometer.
 */
double percentile(const std::vector<double>& sorted, double pct) {
    if (sorted.empty()) return 0.0;
    size_t idx = static_cast<size_t>(std::ceil(pct * sorted.size())) - 1;
    idx = std::min(idx, sorted.size() - 1);
    return sorted[idx];
}

/**
 * Sort a span into a new vector.
 * C++20: std::span as parameter, std::ranges::sort.
 */
std::vector<double> sorted_copy(std::span<const double> data) {
    std::vector<double> v(data.begin(), data.end());
    std::ranges::sort(v);
    return v;
}

/**
 * Compute mean and standard deviation over a span.
 * C++20: structured binding, std::reduce.
 */
std::pair<double, double> mean_stddev(std::span<const double> data) {
    if (data.empty()) return {0.0, 0.0};

    const double n    = static_cast<double>(data.size());
    const double mean = std::reduce(data.begin(), data.end(), 0.0) / n;
    const double variance = std::transform_reduce(
        data.begin(), data.end(), 0.0,
        std::plus<double>{},
        [mean](double x) { return (x - mean) * (x - mean); }
    ) / n;

    return { mean, std::sqrt(variance) };
}

} // anonymous namespace

// ── Public C API ─────────────────────────────────────────────────────────────

extern "C" {

int jvmstats_recommend_gc(
        const double* pauses_ms,
        int32_t       count,
        double*       out_p50,
        double*       out_p99,
        double*       out_max) {

    if (!pauses_ms || count <= 0) return 0;

    // C++20: construct span from raw pointer + count
    std::span<const double> data{pauses_ms, static_cast<size_t>(count)};
    auto sorted = sorted_copy(data);

    *out_p50 = percentile(sorted, 0.50);
    *out_p99 = percentile(sorted, 0.99);
    *out_max = sorted.back();

    // Recommendation thresholds (ms):
    //   ZGC:        p99 < 1ms   — sub-millisecond SLA
    //   Shenandoah: p99 < 20ms  — low-latency, Red Hat default
    //   G1GC:       otherwise   — general purpose
    if (*out_p99 < 1.0)  return 2;  // ZGC
    if (*out_p99 < 20.0) return 1;  // Shenandoah
    return 0;                        // G1GC
}

int jvmstats_cpu_profile(
        const double* samples,
        int32_t       count,
        double*       out_mean,
        double*       out_stddev,
        double*       out_p95) {

    if (!samples || count <= 0) return 0;

    std::span<const double> data{samples, static_cast<size_t>(count)};
    auto [mean, stddev] = mean_stddev(data);  // C++17 structured binding
    auto sorted         = sorted_copy(data);

    *out_mean   = mean;
    *out_stddev = stddev;
    *out_p95    = percentile(sorted, 0.95);

    // GC-dominated profile: p95 is more than 3× the mean
    // (indicates short high-CPU spikes, not sustained load)
    return (*out_p95 > 0.0 && *out_p95 / mean > 3.0) ? 1 : 0;
}

int32_t jvmstats_recommend_memory_mb(
        const double* rss_mb_samples,
        int32_t       count) {

    if (!rss_mb_samples || count <= 0) return 256;

    std::span<const double> data{rss_mb_samples, static_cast<size_t>(count)};
    auto sorted = sorted_copy(data);

    const double p99     = percentile(sorted, 0.99);
    const double with_hw = p99 * 1.25;   // 25% headroom

    // Round up to nearest 64 MB, minimum 256 MB
    const int32_t rounded = static_cast<int32_t>(
        std::ceil(with_hw / 64.0) * 64.0);
    return std::max(rounded, 256);
}

} // extern "C"
