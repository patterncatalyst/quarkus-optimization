package demo.leyden;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.management.ManagementFactory;
import java.nio.file.*;
import java.util.*;

/**
 * Demo 04 — Quarkus + Project Leyden AOT Cache
 * Quarkus 3.33.1 LTS / JDK 25 LTS
 *
 * How the AOT cache is generated (the Quarkus way):
 *   application.properties: quarkus.package.jar.aot.enabled=true
 *   Build:   ./mvnw verify
 *            → Quarkus Maven plugin starts the packaged app
 *            → runs @QuarkusIntegrationTest suite as training workload
 *            → JVM records class loading + JIT profiles
 *            → writes target/quarkus-app/app.aot
 *
 *   Runtime: java -XX:AOTCache=app.aot -jar quarkus-run.jar
 *            (Quarkus passes this flag automatically via quarkus-run.jar)
 *
 * Java 21 features used: records, var, switch expressions,
 *                        text blocks, ProcessHandle, Stream.toList()
 */
@Path("/")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class LeydenResource {

    // Java 21 records for type-safe API responses
    record StartupInfo(
        long startupMs,
        String jvmVersion,
        long pid,
        String aotCacheStatus,
        String gcName,
        String containerMemoryLimit,
        Map<String, String> leydenJeps
    ) {}

    record JvmFlags(
        List<String> aotFlags,
        List<String> gcFlags,
        List<String> containerFlags,
        boolean leydenCacheActive
    ) {}

    // Captured at class-init time — the key startup measurement
    private static final long JVM_START_MS =
        ManagementFactory.getRuntimeMXBean().getStartTime();
    private static final long READY_MS = System.currentTimeMillis();

    static {
        // Java 15+ text block
        System.out.printf("""

            ╔═══════════════════════════════════════════════════════════╗
            ║  Quarkus 3.33.1 + Project Leyden AOT Cache               ║
            ║  Startup time: %d ms                                   ║
            ║  JDK: %-52s║
            ╚═══════════════════════════════════════════════════════════╝
            %n""",
            READY_MS - JVM_START_MS,
            System.getProperty("java.version"));
    }

    @GET
    @Path("/")
    public Map<String, Object> home() {
        return Map.of(
            "app",           "quarkus-leyden-demo",
            "quarkus",       "3.33.1 LTS",
            "java",          System.getProperty("java.version"),
            "startupMs",     READY_MS - JVM_START_MS,
            "aotCache",      aotCacheStatus(),
            "endpoints",     List.of("/startup", "/jvm/flags", "/q/health/live")
        );
    }

    /**
     * The primary demo endpoint — shows startup time and AOT cache status.
     * The @QuarkusIntegrationTest hits this endpoint during the training run
     * so the JVM records it as a hot code path.
     */
    @GET
    @Path("/startup")
    public StartupInfo startup() {
        return new StartupInfo(
            READY_MS - JVM_START_MS,
            System.getProperty("java.vm.name") + " " + System.getProperty("java.version"),
            ProcessHandle.current().pid(),
            aotCacheStatus(),
            activeGcName(),
            containerMemoryLimit(),
            leydenJepAvailability()
        );
    }

    /**
     * Shows active JVM flags — audience can see -XX:AOTCache in action.
     */
    @GET
    @Path("/jvm/flags")
    public JvmFlags flags() {
        // Java 16+ Stream.toList()
        var all = ManagementFactory.getRuntimeMXBean().getInputArguments();
        return new JvmFlags(
            all.stream().filter(f -> f.contains("AOT") || f.contains("Xshare")).toList(),
            all.stream().filter(f -> f.contains("GC") || f.contains("GarbageCollector")).toList(),
            all.stream().filter(f -> f.contains("Container") || f.contains("RAMPercentage")).toList(),
            all.stream().anyMatch(f -> f.contains("AOTCache="))
        );
    }

    // ── Private helpers ───────────────────────────────────────────

    private String aotCacheStatus() {
        var flags = ManagementFactory.getRuntimeMXBean().getInputArguments();
        // Java 21 switch expression
        boolean hasCache    = flags.stream().anyMatch(f -> f.contains("AOTCache="));
        boolean hasOutput   = flags.stream().anyMatch(f -> f.contains("AOTCacheOutput"));
        return switch (0) {
            default -> {
                if (hasOutput) yield "TRAINING — writing AOT cache (mvn verify in progress)";
                else if (hasCache) yield "ACTIVE — Leyden AOT cache loaded (JEP 483+515)";
                else yield "NONE — cold start (no -XX:AOTCache flag)";
            }
        };
    }

    private Map<String, String> leydenJepAvailability() {
        int v = Runtime.version().feature();
        return Map.of(
            "JEP_483_class_loading",   v >= 24 ? "✅ available" : "❌ requires JDK 24+",
            "JEP_514_ergonomics",      v >= 25 ? "✅ available" : "❌ requires JDK 25 LTS",
            "JEP_515_method_profiling", v >= 25 ? "✅ available" : "❌ requires JDK 25 LTS",
            "JEP_516_any_gc_zgc",      v >= 26 ? "✅ available" : "⚠️  requires JDK 26",
            "running_jdk",             String.valueOf(v)
        );
    }

    private String activeGcName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().findFirst().map(gc -> gc.getName()).orElse("unknown");
    }

    private String containerMemoryLimit() {
        try {
            var v2 = Path.of("/sys/fs/cgroup/memory.max");
            if (Files.exists(v2)) {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return "%,d MB".formatted(Long.parseLong(s) / (1024 * 1024));
            }
        } catch (Exception ignored) {}
        return "not detected";
    }
}
