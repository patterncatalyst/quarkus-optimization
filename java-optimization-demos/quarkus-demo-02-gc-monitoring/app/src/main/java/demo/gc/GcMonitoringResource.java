package demo.gc;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Demo 02 — GC Monitoring with Prometheus + OpenTelemetry
 * Quarkus 3.33.1 LTS / Java 21
 *
 * Key Quarkus vs Spring Boot differences:
 *   @Path + @GET          vs @RestController + @GetMapping
 *   @QueryParam           vs @RequestParam
 *   @DefaultValue         vs defaultValue = "..."
 *   @RunOnVirtualThread   vs spring.threads.virtual.enabled=true
 *   @WithSpan             vs Observation.createNotStarted(...)
 *   /q/metrics            vs /actuator/prometheus
 *   /q/health             vs /actuator/health
 *   CDI @ApplicationScoped vs Spring @Component
 *
 * Java 21 features: records, var, switch expressions,
 *                   Stream.toList(), text blocks, ProcessHandle
 */
@Path("/")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class GcMonitoringResource {

    // ── Java 21 records — immutable, type-safe API responses ─────────
    record AllocResponse(long allocatedMB, int iterations, long gcCount,
                         long gcTimeMs, long durationMs, long heapUsedMB,
                         long heapMaxMB, String activeGC) {}

    record JvmSummary(long heapUsedMB, long heapMaxMB, long heapCommittedMB,
                      double heapUtilizationPct, int processors,
                      int liveThreads, String jvmVersion,
                      List<GcInfo> gcBeans, String containerLimit) {}

    record GcInfo(String name, long collectionCount, long collectionTimeMs) {}

    record VirtualThreadResult(long taskCount, long durationMs,
                               long peakPlatformThreads, String executor,
                               String message) {}

    // ── Micrometer injection (Quarkus Arc CDI) ───────────────────────
    @Inject
    MeterRegistry registry;

    private final AtomicLong peakPlatformThreads = new AtomicLong(0);

    // Lazy initialise metrics to avoid startup ordering issues
    private Counter allocCounter() {
        return Counter.builder("demo.allocations.total")
            .description("Total MB allocated through demo endpoints")
            .register(registry);
    }

    private Timer requestTimer() {
        return Timer.builder("demo.request.duration")
            .description("Demo endpoint processing time")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(registry);
    }

    // ── Endpoints ────────────────────────────────────────────────────

    @GET
    @Path("/")
    public Map<String, String> home() {
        return Map.of(
            "app",      "quarkus-gc-monitoring-demo",
            "quarkus",  "3.33.1 LTS",
            "java",     System.getProperty("java.version"),
            "status",   "running",
            "metrics",  "/q/metrics        (Prometheus scrape endpoint)",
            "health",   "/q/health         (SmallRye Health)",
            "devui",    "/q/dev            (Quarkus Dev UI — dev mode only)",
            "traces",   "http://localhost:16686 (Jaeger UI)"
        );
    }

    /**
     * Allocate garbage to drive measurable GC events.
     * Quarkus OTel auto-instruments this endpoint — trace visible in Jaeger.
     *
     * GET /allocate?mb=50&iterations=5
     */
    @GET
    @Path("/allocate")
    @io.quarkus.vertx.http.runtime.devmode.NotFoundRouteDescription
    // Quarkus 3.x: @RunOnVirtualThread moves execution to a Virtual Thread (JEP 444)
    // No property needed — just annotate the resource method
    @io.smallrye.common.annotation.RunOnVirtualThread
    @WithSpan("demo.allocate")  // Creates a child OTel span for Jaeger
    public AllocResponse allocate(
            @QueryParam("mb")         @DefaultValue("20") int mb,
            @QueryParam("iterations") @DefaultValue("3")  int iterations) {

        long startNs     = System.nanoTime();
        long gcsBefore   = totalGCCount();
        long gcTimeBefore = totalGCTime();

        for (int i = 0; i < iterations; i++) {
            @SuppressWarnings("unused")
            var garbage = new ArrayList<byte[]>(mb);
            for (int j = 0; j < mb; j++) garbage.add(new byte[1024 * 1024]);
            allocCounter().increment(mb);
            try { Thread.sleep(50); } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }

        long durationMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs);
        requestTimer().record(durationMs, TimeUnit.MILLISECONDS);

        return new AllocResponse(
            (long) mb * iterations, iterations,
            totalGCCount() - gcsBefore,
            totalGCTime()  - gcTimeBefore,
            durationMs, heapUsedMB(), heapMaxMB(), activeGCName()
        );
    }

    /**
     * Sustained allocation rounds.
     * GET /load?mb=10&delayMs=300&rounds=20
     */
    @GET
    @Path("/load")
    @io.smallrye.common.annotation.RunOnVirtualThread
    public Map<String, Object> load(
            @QueryParam("mb")      @DefaultValue("10")  int mb,
            @QueryParam("delayMs") @DefaultValue("500") long delayMs,
            @QueryParam("rounds")  @DefaultValue("20")  int rounds)
            throws InterruptedException {

        long total = 0;
        for (int i = 0; i < rounds; i++) {
            @SuppressWarnings("unused")
            var data = new ArrayList<byte[]>(mb);
            for (int j = 0; j < mb; j++) data.add(new byte[1024 * 1024]);
            total += (long) mb * 1024 * 1024;
            allocCounter().increment(mb);
            Thread.sleep(delayMs);
        }
        return Map.of(
            "totalAllocatedMB", total / (1024 * 1024),
            "rounds", rounds,
            "heapUsedMB", heapUsedMB(),
            "heapMaxMB",  heapMaxMB()
        );
    }

    /**
     * Java 21 Virtual Threads demo — JEP 444.
     * Quarkus uses @RunOnVirtualThread on resource methods instead of
     * Spring Boot's spring.threads.virtual.enabled=true property.
     *
     * GET /virtual-threads?tasks=500&workMs=5
     */
    @GET
    @Path("/virtual-threads")
    @io.smallrye.common.annotation.RunOnVirtualThread
    @WithSpan("demo.virtual-threads")
    public VirtualThreadResult virtualThreads(
            @QueryParam("tasks")  @DefaultValue("500") int tasks,
            @QueryParam("workMs") @DefaultValue("5")   long workMs) throws Exception {

        long startMs = System.currentTimeMillis();
        var threadMx = ManagementFactory.getThreadMXBean();

        // Java 21 virtual thread executor — one VT per task, no pool sizing
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var futures = new ArrayList<Future<Long>>(tasks);
            for (int i = 0; i < tasks; i++) {
                futures.add(executor.submit(() -> {
                    Thread.sleep(workMs); // Blocking but carrier thread is NOT blocked
                    long current = threadMx.getThreadCount();
                    peakPlatformThreads.updateAndGet(p -> Math.max(p, current));
                    return Thread.currentThread().threadId();
                }));
            }
            for (var f : futures) f.get();
        }

        long durationMs = System.currentTimeMillis() - startMs;

        // Java 15+ text block for multi-line message
        String msg = """
            %d virtual threads completed in %d ms.
            Peak platform (carrier) threads: %d
            Quarkus VT: annotate with @RunOnVirtualThread — no property needed.
            All /allocate and /load endpoints also run on virtual threads.
            """.formatted(tasks, durationMs, peakPlatformThreads.get());

        return new VirtualThreadResult(
            tasks, durationMs, peakPlatformThreads.get(),
            "Executors.newVirtualThreadPerTaskExecutor() — Java 21 JEP 444",
            msg
        );
    }

    /**
     * Full JVM summary using Java 21 records.
     * GET /jvm/memory
     */
    @GET
    @Path("/jvm/memory")
    public JvmSummary jvmMemory() {
        var memBean = ManagementFactory.getMemoryMXBean();
        var heap    = memBean.getHeapMemoryUsage();
        final long MB = 1024 * 1024L;
        long used = heap.getUsed(), max = heap.getMax();

        // Java 16+ Stream.toList()
        var gcInfoList = ManagementFactory.getGarbageCollectorMXBeans().stream()
            .map(gc -> new GcInfo(gc.getName(), gc.getCollectionCount(), gc.getCollectionTime()))
            .toList();

        return new JvmSummary(
            used / MB, max / MB, heap.getCommitted() / MB,
            max > 0 ? (used * 100.0 / max) : 0,
            Runtime.getRuntime().availableProcessors(),
            ManagementFactory.getThreadMXBean().getThreadCount(),
            System.getProperty("java.vm.name") + " " + System.getProperty("java.version"),
            gcInfoList,
            readContainerLimit()
        );
    }

    // ── Private helpers ───────────────────────────────────────────────

    private long totalGCCount() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().mapToLong(GarbageCollectorMXBean::getCollectionCount).sum();
    }

    private long totalGCTime() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().mapToLong(GarbageCollectorMXBean::getCollectionTime).sum();
    }

    private long heapUsedMB() {
        var rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
    }

    private long heapMaxMB() {
        return Runtime.getRuntime().maxMemory() / (1024 * 1024);
    }

    private String activeGCName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().map(GarbageCollectorMXBean::getName).findFirst().orElse("Unknown");
    }

    /** Read container memory limit via cgroup — no com.sun.* internals */
    private String readContainerLimit() {
        try {
            var v2 = Path.of("/sys/fs/cgroup/memory.max");
            if (Files.exists(v2)) {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return "%,d MB".formatted(Long.parseLong(s) / (1024 * 1024));
            }
            var v1 = Path.of("/sys/fs/cgroup/memory/memory.limit_in_bytes");
            if (Files.exists(v1)) {
                long limit = Long.parseLong(Files.readString(v1).strip());
                if (limit < Long.MAX_VALUE / 2) return "%,d MB".formatted(limit / (1024 * 1024));
            }
        } catch (Exception ignored) {}
        return "not detected";
    }
}
