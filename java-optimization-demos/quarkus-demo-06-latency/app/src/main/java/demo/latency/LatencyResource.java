package demo.latency;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Demo 06 — Low-Latency JVM Tuning
 *
 * Two instances of this same app run side-by-side:
 *   G1GC  → port 8080  (-XX:+UseG1GC)
 *   ZGC   → port 8081  (-XX:+UseZGC -XX:+ZGenerational)
 *
 * Same code. Same heap. Same load. Different GC algorithm.
 * The p99 latency difference under /pressure load is the demo.
 */
@Path("/")
@Produces(MediaType.APPLICATION_JSON)
public class LatencyResource {

    private static final long START_MS = System.currentTimeMillis();

    /** GC info snapshot */
    record GcInfo(String name, long collectionCount, long collectionTimeMs) {}

    /** Response from /info */
    record InfoResponse(
        String gcAlgorithm,
        long heapUsedMb,
        long heapMaxMb,
        long uptimeMs,
        List<GcInfo> gcCollectors,
        String jvmVersion
    ) {}

    /** Response from /pressure */
    record PressureResponse(
        int allocatedMb,
        int iterations,
        long durationMs,
        long gcPauseMs,
        String gcAlgorithm
    ) {}

    @GET
    @Path("/info")
    public InfoResponse info() {
        var rt   = Runtime.getRuntime();
        var bean = ManagementFactory.getRuntimeMXBean();

        long usedMb = (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
        long maxMb  = rt.maxMemory() / (1024 * 1024);

        var gcs = ManagementFactory.getGarbageCollectorMXBeans()
            .stream()
            .map(gc -> new GcInfo(gc.getName(), gc.getCollectionCount(), gc.getCollectionTime()))
            .toList();

        String gcName = gcs.isEmpty() ? "unknown" : gcs.get(0).name();

        return new InfoResponse(gcName, usedMb, maxMb,
            System.currentTimeMillis() - START_MS, gcs, bean.getVmVersion());
    }

    /**
     * Allocate mb megabytes of objects, repeat for iterations.
     * Each allocation fills the objects with data so the JVM can't optimise them away.
     * This triggers real GC pressure so we can measure actual pause times.
     *
     * The key measurement: gcPauseMs before vs after.
     * G1GC will show large jumps. ZGC will show near-zero increments.
     */
    @GET
    @Path("/pressure")
    public PressureResponse pressure(
            @QueryParam("mb")         @DefaultValue("50")  int mb,
            @QueryParam("iterations") @DefaultValue("10")  int iterations) {

        long gcTimeBefore = totalGcTime();
        long start        = System.currentTimeMillis();

        for (int i = 0; i < iterations; i++) {
            allocate(mb);
        }

        long duration    = System.currentTimeMillis() - start;
        long gcPauseMs   = totalGcTime() - gcTimeBefore;

        String gcName = ManagementFactory.getGarbageCollectorMXBeans()
            .stream().findFirst().map(GarbageCollectorMXBean::getName).orElse("unknown");

        return new PressureResponse(mb * iterations, iterations, duration, gcPauseMs, gcName);
    }

    /** Return current GC stats for monitoring */
    @GET
    @Path("/gc-stats")
    public Map<String, Object> gcStats() {
        long totalCount = 0, totalTime = 0;
        var details = new ArrayList<Map<String, Object>>();

        for (var gc : ManagementFactory.getGarbageCollectorMXBeans()) {
            totalCount += Math.max(0, gc.getCollectionCount());
            totalTime  += Math.max(0, gc.getCollectionTime());
            details.add(Map.of(
                "name",  gc.getName(),
                "count", Math.max(0, gc.getCollectionCount()),
                "timeMs", Math.max(0, gc.getCollectionTime())
            ));
        }

        var rt     = Runtime.getRuntime();
        long usedMb = (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
        long maxMb  = rt.maxMemory() / (1024 * 1024);

        return Map.of(
            "totalGcCount",  totalCount,
            "totalGcTimeMs", totalTime,
            "heapUsedMb",    usedMb,
            "heapMaxMb",     maxMb,
            "heapUsedPct",   maxMb > 0 ? Math.round(usedMb * 100.0 / maxMb) : 0,
            "collectors",    details
        );
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private long totalGcTime() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream()
            .mapToLong(gc -> Math.max(0, gc.getCollectionTime()))
            .sum();
    }

    /** Allocate mbToAllocate megabytes of byte arrays and touch them */
    private void allocate(int mbToAllocate) {
        int chunkSize  = 1024 * 512; // 512 KB per chunk
        int chunks     = (mbToAllocate * 1024 * 1024) / chunkSize;
        var references = new ArrayList<byte[]>(chunks);

        for (int i = 0; i < chunks; i++) {
            byte[] chunk = new byte[chunkSize];
            // Touch the memory so the JVM can't skip allocation
            chunk[0]             = (byte) i;
            chunk[chunkSize - 1] = (byte) i;
            references.add(chunk);
        }
        // references goes out of scope here → eligible for collection
    }
}
