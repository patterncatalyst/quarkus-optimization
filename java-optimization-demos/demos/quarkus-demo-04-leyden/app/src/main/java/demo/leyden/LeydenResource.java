package demo.leyden;

import io.quarkus.cache.CacheResult;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.util.*;

/**
 * Demo 04 — Quarkus + Project Leyden AOT Cache / JDK 25 LTS
 *
 * Extensions: smallrye-openapi + cache + scheduler load more classes
 * at startup, making the Leyden AOT cache improvement visible.
 * Same single property as AppCDS demo:
 *   quarkus.package.jar.aot.enabled=true
 */
@Path("/")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class LeydenResource {

    private static final long JVM_START_MS =
        ManagementFactory.getRuntimeMXBean().getStartTime();
    private static final long READY_MS = System.currentTimeMillis();

    record StartupInfo(
        long startupMs, String jvmVersion, long pid,
        String aotCacheStatus, String gcName,
        String containerMemoryLimit, Map<String, String> leydenJeps
    ) {}

    @GET @Path("/")
    public Map<String, Object> home() {
        return Map.of(
            "app",       "quarkus-leyden-demo",
            "quarkus",   "3.33.1 LTS",
            "java",      System.getProperty("java.version"),
            "startupMs", READY_MS - JVM_START_MS,
            "aotCache",  aotCacheStatus()
        );
    }

    @GET @Path("/startup")
    public StartupInfo startup() {
        return new StartupInfo(
            READY_MS - JVM_START_MS,
            System.getProperty("java.vm.name") + " " + System.getProperty("java.version"),
            ProcessHandle.current().pid(),
            aotCacheStatus(), activeGcName(),
            containerMemoryLimit(), leydenJepAvailability()
        );
    }

    @GET @Path("/cached-info")
    @CacheResult(cacheName = "startup-cache")
    public Map<String, Object> cachedInfo() {
        return Map.of(
            "jvmArgs",  ManagementFactory.getRuntimeMXBean().getInputArguments(),
            "uptime",   ManagementFactory.getRuntimeMXBean().getUptime(),
            "cachedAt", System.currentTimeMillis()
        );
    }


    @GET @Path("/jvm/flags")
    public Map<String, Object> jvmFlags() {
        var allFlags = ManagementFactory.getRuntimeMXBean().getInputArguments();
        return Map.of(
            "aotFlags",       allFlags.stream().filter(f -> f.contains("AOT")).toList(),
            "gcFlags",        allFlags.stream().filter(f -> f.contains("GC") || f.contains("Gc")).toList(),
            "containerFlags", allFlags.stream().filter(f -> f.contains("Container") || f.contains("RAM")).toList(),
            "all",            allFlags
        );
    }

    private String aotCacheStatus() {
        var flags = ManagementFactory.getRuntimeMXBean().getInputArguments();
        if (flags.stream().anyMatch(f -> f.contains("AOTCacheOutput")))
            return "TRAINING — writing AOT cache";
        if (flags.stream().anyMatch(f -> f.contains("AOTCache=")))
            return "ACTIVE — Leyden AOT cache loaded (JEP 483+515)";
        return "NONE — cold start";
    }

    private Map<String, String> leydenJepAvailability() {
        int v = Runtime.version().feature();
        return Map.of(
            "JEP_483", v >= 24 ? "available" : "requires JDK 24+",
            "JEP_514", v >= 25 ? "available" : "requires JDK 25 LTS",
            "JEP_515", v >= 25 ? "available" : "requires JDK 25 LTS",
            "JEP_516", v >= 26 ? "available" : "requires JDK 26",
            "running_jdk", String.valueOf(v)
        );
    }

    private String activeGcName() {
        return ManagementFactory.getGarbageCollectorMXBeans()
            .stream().findFirst().map(gc -> gc.getName()).orElse("unknown");
    }

    private String containerMemoryLimit() {
        try {
            var v2 = java.nio.file.Path.of("/sys/fs/cgroup/memory.max");
            if (Files.exists(v2)) {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return "%,d MB".formatted(Long.parseLong(s) / (1024 * 1024));
            }
        } catch (Exception ignored) {}
        return "not detected";
    }
}
