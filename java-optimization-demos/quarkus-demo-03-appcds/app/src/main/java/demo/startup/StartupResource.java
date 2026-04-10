package demo.startup;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.util.Map;

/**
 * Demo 03 — AppCDS Startup Acceleration
 * Quarkus 3.33.1 LTS / Java 21
 *
 * Key Quarkus startup facts:
 *   JVM mode baseline:  ~0.3 – 0.8s  (already 5-10x faster than Spring Boot!)
 *   JVM + AppCDS:       ~0.1 – 0.4s  (additional 30-50% improvement)
 *   Native mode:        ~0.01 – 0.05s (GraalVM — not this demo)
 *
 * Quarkus AppCDS advantage over Spring Boot:
 *   ONE property in application.properties:
 *     quarkus.package.jar.appcds.enabled=true
 *   The Quarkus Maven plugin runs the training pass and bundles the
 *   archive automatically during 'mvn package'. No manual steps needed.
 *
 * Java 21: records, var, text blocks, switch expressions,
 *          ProcessHandle, Stream.toList()
 */
@Path("/")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class StartupResource {

    /** Immutable startup timing snapshot — Java 21 record */
    record StartupMetrics(
        long jvmStartEpochMs,
        long appReadyEpochMs,
        long totalStartupMs,
        String jvmVersion,
        long pid,
        String cdsStatus,
        String gcName,
        String containerLimit,
        String framework
    ) {}

    // Captured at class-loading time — milliseconds from JVM process start
    private static final long JVM_START_MS =
        ManagementFactory.getRuntimeMXBean().getStartTime();

    // Captured when Quarkus has completed startup (CDI bean creation time)
    private static final long APP_READY_MS = System.currentTimeMillis();

    static {
        long total = APP_READY_MS - JVM_START_MS;
        // Java 15+ text block
        System.out.println("""
            ╔═════════════════════════════════════════════════╗
            ║  Quarkus 3.33.1 LTS ready!                     ║
            ║  JVM + Quarkus startup: %5d ms               ║
            ║  (Spring Boot equivalent: ~4000-8000 ms)        ║
            ╚═════════════════════════════════════════════════╝
            """.formatted(total));
    }

    @GET
    @Path("/")
    public Map<String, Object> home() {
        return Map.of(
            "app",         "quarkus-startup-demo",
            "framework",   "Quarkus 3.33.1 LTS",
            "java",        System.getProperty("java.version"),
            "status",      "ready",
            "startupMs",   APP_READY_MS - JVM_START_MS,
            "metrics",     "/startup-time"
        );
    }

    /**
     * Full startup timing report — what the demo script reads.
     * GET /startup-time
     */
    @GET
    @Path("/startup-time")
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
            "Quarkus 3.33.1 LTS"
        );
    }

    /** Detect CDS status from active JVM flags */
    private String detectCdsStatus() {
        var flags = ManagementFactory.getRuntimeMXBean().getInputArguments();
        boolean xshareOn   = flags.stream().anyMatch(f -> f.startsWith("-Xshare:on"));
        boolean xshareAuto = flags.stream().anyMatch(f -> f.startsWith("-Xshare:auto"));
        boolean xshareOff  = flags.stream().anyMatch(f -> f.startsWith("-Xshare:off"));
        boolean hasArchive = flags.stream().anyMatch(f -> f.contains("SharedArchiveFile"));

        // Java 21 switch expression
        return switch (0) {
            default -> {
                if (xshareOff)                   yield "DISABLED (-Xshare:off)";
                else if (xshareOn && hasArchive)  yield "ACTIVE — AppCDS archive loaded";
                else if (xshareAuto)              yield "AUTO — archive used if found";
                else                              yield "DEFAULT — base JDK CDS active";
            }
        };
    }

    private String activeGcName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().map(gc -> gc.getName()).findFirst().orElse("unknown");
    }

    private String readContainerLimit() {
        try {
            var v2 = java.nio.file.Path.of("/sys/fs/cgroup/memory.max");
            if (Files.exists(v2)) {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return "%,d MB".formatted(Long.parseLong(s) / (1024 * 1024));
            }
            var v1 = java.nio.file.Path.of("/sys/fs/cgroup/memory/memory.limit_in_bytes");
            if (Files.exists(v1)) {
                long limit = Long.parseLong(Files.readString(v1).strip());
                if (limit < Long.MAX_VALUE / 2) return "%,d MB".formatted(limit / (1024 * 1024));
            }
        } catch (Exception ignored) {}
        return "not detected";
    }
}
