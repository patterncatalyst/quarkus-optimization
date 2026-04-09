import java.lang.management.*;
import java.nio.file.*;
import java.util.List;

/**
 * Demo 01 — Container-Aware JVM Heap Sizing
 * Java 21 LTS: standard APIs only (no com.sun.* internals),
 * text blocks, records, var, switch expressions, pattern matching.
 *
 * Compile: javac --release 21 HeapInfo.java
 * Run:     java HeapInfo [--keep-alive]
 */
public class HeapInfo {

    /** Immutable value type — Java 16+ record */
    record MemoryRegion(String name, long usedBytes, long maxBytes) {
        double utilizationPct() {
            return maxBytes > 0 ? (usedBytes * 100.0 / maxBytes) : 0;
        }
        String usedMB() { return "%,d MB".formatted(usedBytes  / (1024 * 1024)); }
        String maxMB()  { return maxBytes > 0
            ? "%,d MB".formatted(maxBytes / (1024 * 1024)) : "unlimited"; }
    }

    public static void main(String[] args) throws Exception {
        var memBean    = ManagementFactory.getMemoryMXBean();
        var heapUsage  = memBean.getHeapMemoryUsage();
        var nonHeap    = memBean.getNonHeapMemoryUsage();
        var runtime    = ManagementFactory.getRuntimeMXBean();
        var gcBeans    = ManagementFactory.getGarbageCollectorMXBeans();
        var threadBean = ManagementFactory.getThreadMXBean();
        final long MB  = 1024 * 1024L;

        // Read cgroup memory limit with no internal APIs (cgroup v2 + v1)
        long cgroupLimit = readCgroupMemoryLimit();
        String containerLimit = cgroupLimit > 0
            ? "%,d MB".formatted(cgroupLimit / MB)
            : "not detected (outside container or unlimited)";

        String sep = "-".repeat(60);

        System.out.println();
        System.out.println("=".repeat(62));
        System.out.println("  JVM HEAP REPORT  —  Java " + System.getProperty("java.version"));
        System.out.println("=".repeat(62));

        // --- Container context ----------------------------------------
        System.out.println("\n  CONTAINER CONTEXT");
        System.out.println("  " + sep);
        System.out.printf("  cgroup memory limit:   %s%n", containerLimit);
        System.out.printf("  Visible processors:    %d%n",
                          Runtime.getRuntime().availableProcessors());
        System.out.printf("  JVM PID:               %d%n",
                          ProcessHandle.current().pid());  // Java 9+ API

        // --- Heap -------------------------------------------------------
        System.out.println("\n  HEAP MEMORY");
        System.out.println("  " + sep);
        var heap = new MemoryRegion("Heap", heapUsage.getUsed(), heapUsage.getMax());
        System.out.printf("  Used:        %s%n", heap.usedMB());
        System.out.printf("  Committed:   %,d MB%n", heapUsage.getCommitted() / MB);
        System.out.printf("  Max (Xmx):   %s%n", heap.maxMB());

        if (cgroupLimit > 0) {
            double ratio = (double) heapUsage.getMax() / cgroupLimit * 100;
            System.out.printf("  Heap / container limit:  %.1f%%%n", ratio);

            // Java 21 switch expression with pattern-inspired ranges
            String verdict = switch ((int)(ratio / 10)) {
                case 0, 1, 2, 3, 4 ->
                    "WARNING: Heap very small — JVM may be ignoring container limit!";
                case 5, 6, 7 ->
                    "OK: Good ratio — room for Metaspace, threads, and JIT code cache";
                case 8 ->
                    "WARNING: Heap >80% of container — risk of OOMKill during GC surge";
                default ->
                    "CRITICAL: Heap >90% — OOMKill imminent during garbage collection!";
            };
            System.out.println("  Verdict:     " + verdict);

            if (heapUsage.getMax() > cgroupLimit * 2) {
                System.out.println();
                System.out.println("  *** JVM max heap EXCEEDS container limit by >2x ***");
                System.out.println("      JVM is reading HOST memory, not the cgroup limit!");
                System.out.println("      Fix: java -XX:MaxRAMPercentage=75.0 (UseContainerSupport");
                System.out.println("           is on by default in Java 21)");
            }
        }

        // --- Memory Pools -----------------------------------------------
        System.out.println("\n  MEMORY POOLS");
        System.out.println("  " + sep);
        ManagementFactory.getMemoryPoolMXBeans().forEach(pool -> {
            var u = pool.getUsage();
            if (u != null) {
                System.out.printf("  %-28s  used=%5,d MB  max=%s%n",
                    pool.getName(), u.getUsed() / MB,
                    u.getMax() > 0 ? "%,d MB".formatted(u.getMax() / MB) : "n/a");
            }
        });

        // --- Threads — Virtual Thread awareness -------------------------
        System.out.println("\n  THREADS  (Java 21 Virtual Threads)");
        System.out.println("  " + sep);
        System.out.printf("  Live platform threads:  %d%n", threadBean.getThreadCount());
        System.out.printf("  Peak platform threads:  %d%n", threadBean.getPeakThreadCount());
        System.out.println("  Virtual threads: use heap (not thread stacks) — no -Xss cost");
        System.out.println("  Enable: spring.threads.virtual.enabled=true (Spring Boot 4.0)");

        // --- GC ---------------------------------------------------------
        System.out.println("\n  GARBAGE COLLECTORS");
        System.out.println("  " + sep);
        gcBeans.forEach(gc -> System.out.printf(
            "  %-28s  collections=%d  time=%dms%n",
            gc.getName(), gc.getCollectionCount(), gc.getCollectionTime()));

        // --- Active JVM flags (using Java 16 Stream.toList()) -----------
        System.out.println("\n  ACTIVE JVM FLAGS");
        System.out.println("  " + sep);
        var flags = runtime.getInputArguments().stream()
            .filter(a -> a.startsWith("-XX") || a.startsWith("-Xm") || a.startsWith("-Xss"))
            .toList();    // Java 16+ Stream.toList() — unmodifiable
        if (flags.isEmpty()) {
            System.out.println("  (none set — using JVM defaults)");
            System.out.println("  Recommended for containers:");
            System.out.println("    -XX:MaxRAMPercentage=75.0");
            System.out.println("    -XX:+UseZGC -XX:+ZGenerational");
        } else {
            flags.forEach(f -> System.out.println("  " + f));
        }

        System.out.printf("%n  Runtime: %s %s%n",
            System.getProperty("java.vm.name"), System.getProperty("java.version"));
        System.out.printf("  Uptime:  %,d ms%n%n", runtime.getUptime());

        if (args.length > 0 && args[0].equals("--keep-alive")) {
            System.out.println("  [Keeping alive — use jcmd to explore:]");
            System.out.println("  docker exec -it <container> jcmd 1 VM.native_memory summary");
            System.out.println("  docker exec -it <container> jcmd 1 GC.heap_info");
            System.out.println("  docker exec -it <container> jcmd 1 Thread.print");
            Thread.sleep(Long.MAX_VALUE);
        }
    }

    /**
     * Reads the container memory limit from cgroup v2 or v1 using
     * standard Java NIO — no com.sun.* or internal APIs required.
     */
    private static long readCgroupMemoryLimit() {
        // cgroup v2 (RHEL 9, OCP 4.14+, modern Docker Desktop)
        var v2 = Path.of("/sys/fs/cgroup/memory.max");
        if (Files.exists(v2)) {
            try {
                var s = Files.readString(v2).strip();
                if (!"max".equals(s)) return Long.parseLong(s);
            } catch (Exception ignored) {}
        }
        // cgroup v1 (RHEL 8, older OCP)
        var v1 = Path.of("/sys/fs/cgroup/memory/memory.limit_in_bytes");
        if (Files.exists(v1)) {
            try {
                long limit = Long.parseLong(Files.readString(v1).strip());
                if (limit < Long.MAX_VALUE / 2) return limit;
            } catch (Exception ignored) {}
        }
        return -1L;
    }
}
