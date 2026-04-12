package demo.grpc;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import java.lang.management.ManagementFactory;
import java.util.Map;

/**
 * Demo 05 — REST endpoint for side-by-side comparison with gRPC.
 *
 * Same data as MetricsServiceImpl.buildMetrics() but:
 *   - JSON text (vs Protobuf binary)
 *   - HTTP/1.1 (vs HTTP/2)
 *   - New connection per request by default (vs persistent multiplexed channel)
 *   - No streaming mode (no equivalent of StreamMetrics without SSE boilerplate)
 *
 * Load test with:   hey -n 10000 -c 50 http://localhost:8080/metrics
 * Load test gRPC:   ghz --insecure --proto metrics.proto \
 *                       --call MetricsService/GetJvmMetrics \
 *                       -n 10000 -c 50 localhost:9000
 */
@Path("/metrics")
@Produces(MediaType.APPLICATION_JSON)
public class MetricsResource {

    @GET
    public Map<String, Object> getJvmMetrics() {
        var rt   = Runtime.getRuntime();
        var bean = ManagementFactory.getRuntimeMXBean();
        var gcs  = ManagementFactory.getGarbageCollectorMXBeans();

        long usedBytes = rt.totalMemory() - rt.freeMemory();
        long maxBytes  = rt.maxMemory();
        long usedMb    = usedBytes / (1024 * 1024);
        long maxMb     = maxBytes  / (1024 * 1024);
        double pct     = maxBytes > 0 ? (usedBytes * 100.0 / maxBytes) : 0;
        String gcName  = gcs.isEmpty() ? "unknown" : gcs.get(0).getName();

        return Map.of(
            "heapUsedMb",  usedMb,
            "heapMaxMb",   maxMb,
            "heapUsedPct", Math.round(pct * 10.0) / 10.0,
            "timestamp",   System.currentTimeMillis(),
            "jvmVersion",  bean.getVmVersion(),
            "gcName",      gcName,
            "uptimeMs",    bean.getUptime()
        );
    }
}
