package demo.panama;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.DoubleStream;

import static java.lang.foreign.ValueLayout.*;

/**
 * Demo 08 — Project Panama: Calling C++20 from Quarkus via FFM
 *
 * Uses the Foreign Function & Memory API (finalized in JDK 22, stable in JDK 25)
 * to call a native C++20 shared library without any JNI wrapper code.
 *
 * Key Panama concepts demonstrated:
 *   SymbolLookup  — find a C function by name in a loaded shared library
 *   Linker        — create a MethodHandle that bridges Java → native calling convention
 *   FunctionDescriptor — describes the C function signature to Panama
 *   Arena         — scoped lifetime for native memory allocations
 *   MemorySegment — typed pointer into native memory
 */
@Path("/")
@Produces(MediaType.APPLICATION_JSON)
public class PanamaResource {

    // ── Panama setup — loaded once at startup ─────────────────────────────────

    private static final Linker LINKER = Linker.nativeLinker();

    /** Load the compiled C++ shared library */
    private static final SymbolLookup JVMSTATS_LIB = SymbolLookup.libraryLookup(
        System.mapLibraryName("jvmstats"),   // "libjvmstats.so" on Linux, ".dylib" on Mac
        Arena.global()
    );

    /**
     * MethodHandle for: int jvmstats_recommend_gc(double*, int32, double*, double*, double*)
     *
     * FunctionDescriptor maps Java types to C types:
     *   JAVA_INT      → int32_t (return value)
     *   ADDRESS       → const double* (pointer)
     *   JAVA_INT      → int32_t (count)
     *   ADDRESS       → double* (output pointer)
     */
    private static final MethodHandle RECOMMEND_GC = LINKER.downcallHandle(
        JVMSTATS_LIB.find("jvmstats_recommend_gc").orElseThrow(),
        FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT, ADDRESS, ADDRESS, ADDRESS)
    );

    /** MethodHandle for: int jvmstats_cpu_profile(double*, int32, double*, double*, double*) */
    private static final MethodHandle CPU_PROFILE = LINKER.downcallHandle(
        JVMSTATS_LIB.find("jvmstats_cpu_profile").orElseThrow(),
        FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT, ADDRESS, ADDRESS, ADDRESS)
    );

    /** MethodHandle for: int32_t jvmstats_recommend_memory_mb(double*, int32) */
    private static final MethodHandle RECOMMEND_MEMORY = LINKER.downcallHandle(
        JVMSTATS_LIB.find("jvmstats_recommend_memory_mb").orElseThrow(),
        FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT)
    );

    // ── GC name lookup ────────────────────────────────────────────────────────

    private static final String[] GC_NAMES = { "G1GC", "Shenandoah", "ZGC" };

    // ── REST endpoints ────────────────────────────────────────────────────────

    record GcRecommendation(
        String recommendation,
        String flag,
        double p50Ms,
        double p99Ms,
        double maxMs,
        int sampleCount
    ) {}

    record CpuProfile(
        double meanPct,
        double stddevPct,
        double p95Pct,
        boolean gcDominated,
        String analysis
    ) {}

    record MemoryRecommendation(
        double p99RssMb,
        int recommendedRequestMb,
        String rationale
    ) {}

    record DemoResult(
        String message,
        GcRecommendation gcRecommendation,
        CpuProfile cpuProfile,
        MemoryRecommendation memoryRecommendation
    ) {}

    /**
     * Full demo — generates synthetic workload data and runs all three
     * native C++ analyses via Panama FFM.
     *
     * Illustrates the Arena lifecycle: one Arena opened, multiple allocations
     * made, all freed atomically when the try-with-resources block closes.
     */
    @GET
    @Path("/demo")
    public DemoResult fullDemo() throws Throwable {
        // Synthetic GC pause data: G1GC-shaped distribution
        double[] gcPauses = generateGcPauses(500, 45.0, 150.0);
        // Synthetic CPU samples: GC spike pattern (mostly low, occasional spike)
        double[] cpuSamples = generateCpuSamples(200, 15.0, 85.0);
        // Synthetic RSS observations
        double[] rssSamples = generateRssSamples(200, 1200.0, 1800.0);

        try (Arena arena = Arena.ofConfined()) {
            // ── 1. GC recommendation ──────────────────────────────────────
            MemorySegment gcPauseSeg  = arena.allocateFrom(JAVA_DOUBLE, gcPauses);
            MemorySegment outP50      = arena.allocate(JAVA_DOUBLE);
            MemorySegment outP99      = arena.allocate(JAVA_DOUBLE);
            MemorySegment outMax      = arena.allocate(JAVA_DOUBLE);

            int gcCode = (int) RECOMMEND_GC.invoke(
                gcPauseSeg, gcPauses.length, outP50, outP99, outMax);

            GcRecommendation gcRec = new GcRecommendation(
                GC_NAMES[gcCode],
                gcFlag(gcCode),
                outP50.get(JAVA_DOUBLE, 0),
                outP99.get(JAVA_DOUBLE, 0),
                outMax.get(JAVA_DOUBLE, 0),
                gcPauses.length
            );

            // ── 2. CPU profile ────────────────────────────────────────────
            MemorySegment cpuSeg    = arena.allocateFrom(JAVA_DOUBLE, cpuSamples);
            MemorySegment outMean   = arena.allocate(JAVA_DOUBLE);
            MemorySegment outStddev = arena.allocate(JAVA_DOUBLE);
            MemorySegment outP95    = arena.allocate(JAVA_DOUBLE);

            int gcDom = (int) CPU_PROFILE.invoke(
                cpuSeg, cpuSamples.length, outMean, outStddev, outP95);

            CpuProfile cpuProf = new CpuProfile(
                outMean.get(JAVA_DOUBLE, 0),
                outStddev.get(JAVA_DOUBLE, 0),
                outP95.get(JAVA_DOUBLE, 0),
                gcDom == 1,
                gcDom == 1
                    ? "GC-dominated spike pattern: use p95 (not p99) for CPU request"
                    : "Normal distribution: use p99 for CPU request"
            );

            // ── 3. Memory recommendation ──────────────────────────────────
            MemorySegment rssSeg = arena.allocateFrom(JAVA_DOUBLE, rssSamples);

            int recMb = (int) RECOMMEND_MEMORY.invoke(rssSeg, rssSamples.length);

            double rssP99 = Arrays.stream(rssSamples).sorted()
                .skip((long)(rssSamples.length * 0.99)).findFirst().orElse(0);

            MemoryRecommendation memRec = new MemoryRecommendation(
                rssP99, recMb,
                String.format("p99 RSS %.0fMB × 1.25 headroom, rounded to 64MB = %dMB", rssP99, recMb)
            );

            // All native memory freed here when arena closes
            return new DemoResult(
                "Panama FFM called C++20 library — no JNI, no wrapper code",
                gcRec, cpuProf, memRec
            );
        }
    }

    /** Analyse custom GC pause data */
    @POST
    @Path("/gc-recommend")
    @Consumes(MediaType.APPLICATION_JSON)
    public GcRecommendation analyseGcPauses(double[] pausesMs) throws Throwable {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment seg    = arena.allocateFrom(JAVA_DOUBLE, pausesMs);
            MemorySegment outP50 = arena.allocate(JAVA_DOUBLE);
            MemorySegment outP99 = arena.allocate(JAVA_DOUBLE);
            MemorySegment outMax = arena.allocate(JAVA_DOUBLE);

            int gcCode = (int) RECOMMEND_GC.invoke(seg, pausesMs.length, outP50, outP99, outMax);

            return new GcRecommendation(
                GC_NAMES[gcCode], gcFlag(gcCode),
                outP50.get(JAVA_DOUBLE, 0),
                outP99.get(JAVA_DOUBLE, 0),
                outMax.get(JAVA_DOUBLE, 0),
                pausesMs.length
            );
        }
    }

    record InfoResponse(String javaVersion, String vendor, String panamaStatus) {}

    @GET
    @Path("/info")
    public InfoResponse info() {
        return new InfoResponse(
            System.getProperty("java.version"),
            System.getProperty("java.vendor"),
            "Foreign Function & Memory API — JEP 454, finalized JDK 22"
        );
    }

    // ── Data generators ───────────────────────────────────────────────────────

    private static double[] generateGcPauses(int n, double typicalMs, double spikeMs) {
        var rng = ThreadLocalRandom.current();
        return DoubleStream.generate(() ->
            rng.nextDouble() < 0.05
                ? spikeMs + rng.nextGaussian() * 30   // 5% spikes
                : typicalMs * rng.nextDouble() * 0.8 + typicalMs * 0.2
        ).limit(n).toArray();
    }

    private static double[] generateCpuSamples(int n, double baseline, double spike) {
        var rng = ThreadLocalRandom.current();
        return DoubleStream.generate(() ->
            rng.nextDouble() < 0.08
                ? spike + rng.nextGaussian() * 10
                : baseline + rng.nextGaussian() * 5
        ).limit(n).map(v -> Math.max(0, Math.min(100, v))).toArray();
    }

    private static double[] generateRssSamples(int n, double min, double max) {
        var rng = ThreadLocalRandom.current();
        return DoubleStream.generate(() ->
            min + rng.nextDouble() * (max - min) + rng.nextGaussian() * 50
        ).limit(n).map(v -> Math.max(min, v)).toArray();
    }

    private static String gcFlag(int code) {
        return switch (code) {
            case 2 -> "-XX:+UseZGC -XX:+ZGenerational";
            case 1 -> "-XX:+UseShenandoahGC -XX:ShenandoahGCHeuristics=adaptive";
            default -> "-XX:+UseG1GC -XX:MaxGCPauseMillis=200";
        };
    }
}
