package demo.gc;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationRegistry;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Demo 02 — GC Monitoring with Prometheus + OpenTelemetry
 * Spring Boot 4.0.5 / Java 21 LTS
 *
 * Key Java 21 features used:
 *   - Records (JEP 395) for structured API responses
 *   - Virtual Threads (JEP 444) via spring.threads.virtual.enabled=true
 *   - Text blocks (JEP 378) for multi-line strings
 *   - Switch expressions (JEP 361)
 *   - Stream.toList() (Java 16)
 *   - var (Java 10)
 *
 * Observability stack:
 *   - Micrometer → Prometheus (metrics via /actuator/prometheus)
 *   - Micrometer Observation + OTel → Jaeger (distributed traces)
 */
@SpringBootApplication
@RestController
public class GcMonitoringApp {

    // ── Java 21 records for type-safe, immutable API responses ───────
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

    // ── Dependencies ─────────────────────────────────────────────────
    private final MeterRegistry registry;
    private final ObservationRegistry observationRegistry;  // Spring Boot 4.0 OTel bridge
    private final Counter allocCounter;
    private final Timer requestTimer;
    private final AtomicLong peakPlatformThreads = new AtomicLong(0);

    public GcMonitoringApp(MeterRegistry registry, ObservationRegistry observationRegistry) {
        this.registry = registry;
        this.observationRegistry = observationRegistry;
        this.allocCounter = Counter.builder("demo.allocations.total")
                .description("Total MB allocated through demo endpoints")
                .register(registry);
        this.requestTimer = Timer.builder("demo.request.duration")
                .description("Demo request processing time")
                .publishPercentiles(0.5, 0.95, 0.99)
                .register(registry);
    }

    public static void main(String[] args) {
        SpringApplication.run(GcMonitoringApp.class, args);
    }

    // ── Endpoints ────────────────────────────────────────────────────

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of(
            "app",       "gc-monitoring-demo",
            "java",      System.getProperty("java.version"),
            "boot",      "4.0.5",
            "status",    "running",
            "endpoints", "/allocate  /load  /jvm/memory  /virtual-threads  /actuator/prometheus",
            "traces",    "http://localhost:16686 (Jaeger UI)"
        );
    }

    /**
     * Allocate garbage to drive GC events — traced via OTel observation.
     * GET /allocate?mb=50&iterations=5
     *
     * Each call creates a span visible in Jaeger under service "gc-monitoring-demo".
     */
    @GetMapping("/allocate")
    public AllocResponse allocate(
            @RequestParam(defaultValue = "20") int mb,
            @RequestParam(defaultValue = "3")  int iterations) {

        // Wrap in an Observation — Spring Boot 4.0 bridges this to an OTel span automatically
        return Observation.createNotStarted("demo.allocate", observationRegistry)
            .lowCardinalityKeyValue("gc.type", activeGCName())
            .lowCardinalityKeyValue("mb", String.valueOf(mb))
            .observe(() -> doAllocate(mb, iterations));
    }

    private AllocResponse doAllocate(int mb, int iterations) {
        long startNs     = System.nanoTime();
        long gcsBefore   = totalGCCount();
        long gcTimeBefore = totalGCTime();

        for (int i = 0; i < iterations; i++) {
            @SuppressWarnings("unused")
            var garbage = new ArrayList<byte[]>(mb);
            for (int j = 0; j < mb; j++) garbage.add(new byte[1024 * 1024]);
            allocCounter.increment(mb);
            try { Thread.sleep(50); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        }

        long durationMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs);
        requestTimer.record(durationMs, TimeUnit.MILLISECONDS);

        return new AllocResponse(
            (long) mb * iterations, iterations,
            totalGCCount() - gcsBefore, totalGCTime() - gcTimeBefore,
            durationMs, heapUsedMB(), heapMaxMB(), activeGCName()
        );
    }

    /**
     * Sustained load — rounds of allocation with configurable delay.
     * GET /load?mb=10&delayMs=300&rounds=20
     */
    @GetMapping("/load")
    public Map<String, Object> load(
            @RequestParam(defaultValue = "10")  int mb,
            @RequestParam(defaultValue = "500") long delayMs,
            @RequestParam(defaultValue = "20")  int rounds) throws InterruptedException {

        long total = 0;
        for (int i = 0; i < rounds; i++) {
            @SuppressWarnings("unused")
            var data = new ArrayList<byte[]>(mb);
            for (int j = 0; j < mb; j++) data.add(new byte[1024 * 1024]);
            total += (long) mb * 1024 * 1024;
            allocCounter.increment(mb);
            Thread.sleep(delayMs);
        }
        return Map.of(
            "totalAllocatedMB", total / (1024 * 1024),
            "rounds", rounds, "heapUsedMB", heapUsedMB(), "heapMaxMB", heapMaxMB()
        );
    }

    /**
     * Java 21 Virtual Threads demo — JEP 444.
     * Spawns N virtual threads doing simulated I/O-bound work.
     * GET /virtual-threads?tasks=500&workMs=5
     *
     * Shows: massive concurrency with tiny platform thread overhead.
     * Traces visible in Jaeger as child spans under the parent request.
     */
    @GetMapping("/virtual-threads")
    public VirtualThreadResult virtualThreads(
            @RequestParam(defaultValue = "500") int tasks,
            @RequestParam(defaultValue = "5")   long workMs) throws Exception {

        long startMs = System.currentTimeMillis();

        return Observation.createNotStarted("demo.virtual-threads", observationRegistry)
            .lowCardinalityKeyValue("tasks", String.valueOf(tasks))
            .observe(() -> {
                try {
                    // Java 21: one virtual thread per task, no pool sizing needed
                    try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
                        var futures = new ArrayList<Future<Long>>(tasks);
                        for (int i = 0; i < tasks; i++) {
                            futures.add(executor.submit(() -> {
                                // Blocking sleep — virtual thread yields, not blocks carrier
                                Thread.sleep(workMs);
                                long current = ManagementFactory.getThreadMXBean().getThreadCount();
                                peakPlatformThreads.updateAndGet(p -> Math.max(p, current));
                                return Thread.currentThread().threadId();
                            }));
                        }
                        for (var f : futures) f.get();
                    }
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }

                long durationMs = System.currentTimeMillis() - startMs;
                // Java 15+ text block
                String msg = """
                    %d virtual threads finished in %d ms.
                    Peak platform threads: %d (JVM carrier pool, not one per task).
                    Enable in Spring Boot 4.0: spring.threads.virtual.enabled=true
                    """.formatted(tasks, durationMs, peakPlatformThreads.get());

                return new VirtualThreadResult(
                    tasks, durationMs, peakPlatformThreads.get(),
                    "Executors.newVirtualThreadPerTaskExecutor() — Java 21 JEP 444", msg);
            });
    }

    /**
     * Full JVM memory summary.
     * GET /jvm/memory
     */
    @GetMapping("/jvm/memory")
    public JvmSummary jvmMemory() {
        var memBean = ManagementFactory.getMemoryMXBean();
        var heap    = memBean.getHeapMemoryUsage();
        final long MB = 1024 * 1024L;
        long used = heap.getUsed(), max = heap.getMax();

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

    private long heapMaxMB() { return Runtime.getRuntime().maxMemory() / (1024 * 1024); }

    private String activeGCName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().map(GarbageCollectorMXBean::getName).findFirst().orElse("Unknown");
    }

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
