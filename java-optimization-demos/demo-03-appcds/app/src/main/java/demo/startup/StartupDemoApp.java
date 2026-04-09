package demo.startup;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;

import java.lang.management.ManagementFactory;
import java.nio.file.*;
import java.util.Map;

/**
 * Demo 03 — AppCDS Startup Time Acceleration
 * Java 21 LTS: records, var, switch expressions, text blocks,
 * Stream.toList(), ProcessHandle.
 *
 * Measures and reports startup time — the key metric for this demo.
 */
@SpringBootApplication
@RestController
public class StartupDemoApp {

    /** Immutable startup timing snapshot — Java 16+ record */
    record StartupMetrics(
        long jvmStartEpochMs,
        long appReadyEpochMs,
        long totalStartupMs,
        String jvmVersion,
        long pid,
        String cdsStatus,
        String gcName,
        String containerLimit,
        String virtualThreadsEnabled
    ) {}

    // Capture the moment the JVM process started (milliseconds since epoch)
    private static final long JVM_START_MS =
        ManagementFactory.getRuntimeMXBean().getStartTime();

    // Capture when the Spring context finished initialisation
    private static final long APP_READY_MS = System.currentTimeMillis();

    public static void main(String[] args) {
        SpringApplication.run(StartupDemoApp.class, args);
        long total = System.currentTimeMillis() - JVM_START_MS;
        // Java 15+ text block in a print statement
        System.out.println("""
            ┌─────────────────────────────────────────────────┐
            │  Spring context ready!                          │
            │  Total JVM + Spring startup: %5d ms           │
            └─────────────────────────────────────────────────┘
            """.formatted(total));
    }

    @GetMapping("/")
    public Map<String, Object> home() {
        return Map.of(
            "app",         "startup-demo",
            "status",      "ready",
            "startupMs",   APP_READY_MS - JVM_START_MS,
            "java",        System.getProperty("java.version"),
            "metrics",     "/startup-time"
        );
    }

    /**
     * Full startup timing breakdown — this is what the demo script reads
     * to compare baseline vs AppCDS runs.
     */
    @GetMapping("/startup-time")
    public StartupMetrics startupTime() {
        return new StartupMetrics(
            JVM_START_MS,
            APP_READY_MS,
            APP_READY_MS - JVM_START_MS,
            System.getProperty("java.vm.name") + " " + System.getProperty("java.version"),
            ProcessHandle.current().pid(),
            detectCdsStatus(),
            activeGcName(),
            readContainerLimit(),
            detectVirtualThreads()
        );
    }

    /**
     * Detect whether AppCDS shared archive is active.
     * The JVM logs "Opened archive" to stderr during startup when CDS is on.
     * We check the active flags as a proxy.
     */
    private String detectCdsStatus() {
        var flags = ManagementFactory.getRuntimeMXBean().getInputArguments();

        // Java 21 switch expression with pattern matching
        boolean xshareOn  = flags.stream().anyMatch(f -> f.startsWith("-Xshare:on"));
        boolean xshareAuto = flags.stream().anyMatch(f -> f.startsWith("-Xshare:auto"));
        boolean xshareOff  = flags.stream().anyMatch(f -> f.startsWith("-Xshare:off"));
        boolean hasArchive = flags.stream().anyMatch(f -> f.contains("SharedArchiveFile"));

        return switch (0) {  // Java 21 switch expression
            default -> {
                if (xshareOff)                  yield "DISABLED (-Xshare:off)";
                else if (xshareOn && hasArchive) yield "ACTIVE   (-Xshare:on + archive present)";
                else if (xshareAuto)             yield "AUTO     (-Xshare:auto — active if archive found)";
                else                             yield "DEFAULT  (Java 21 base CDS active; no AppCDS archive)";
            }
        };
    }

    private String activeGcName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream()
            .map(gc -> gc.getName())
            .findFirst()
            .orElse("unknown");
    }

    private String detectVirtualThreads() {
        // Spring Boot 4.0 sets this property when virtual threads are enabled
        var prop = System.getProperty("spring.threads.virtual.enabled", "");
        return "true".equalsIgnoreCase(prop) ? "enabled (JEP 444)" : "disabled (add spring.threads.virtual.enabled=true)";
    }

    private String readContainerLimit() {
        try {
            // cgroup v2 (RHEL 9, OCP 4.14+)
            var v2 = Path.of("/sys/fs/cgroup/memory.max");
            if (Files.exists(v2)) {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return "%,d MB".formatted(Long.parseLong(s) / (1024 * 1024));
            }
            // cgroup v1 (RHEL 8, older OCP)
            var v1 = Path.of("/sys/fs/cgroup/memory/memory.limit_in_bytes");
            if (Files.exists(v1)) {
                long limit = Long.parseLong(Files.readString(v1).strip());
                if (limit < Long.MAX_VALUE / 2) return "%,d MB".formatted(limit / (1024 * 1024));
            }
        } catch (Exception ignored) {}
        return "not detected";
    }
}
