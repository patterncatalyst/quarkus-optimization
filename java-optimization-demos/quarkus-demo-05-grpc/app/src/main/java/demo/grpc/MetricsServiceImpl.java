package demo.grpc;

import demo.grpc.proto.MetricsRequest;
import demo.grpc.proto.MetricsResponse;
import demo.grpc.proto.MutinyMetricsServiceGrpc;
import io.quarkus.grpc.GrpcService;
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;

import java.lang.management.ManagementFactory;
import java.time.Duration;

/**
 * Demo 05 — gRPC service implementation
 *
 * Quarkus generates MutinyMetricsServiceGrpc from metrics.proto at mvn compile.
 * @GrpcService registers this as the handler — zero XML, zero config.
 *
 * Two RPC methods:
 *   GetJvmMetrics  — unary (equivalent to REST GET /metrics)
 *   StreamMetrics  — server streaming (no REST equivalent without SSE/WebSocket)
 */
@GrpcService
public class MetricsServiceImpl extends MutinyMetricsServiceGrpc.MetricsServiceImplBase {

    @Override
    public Uni<MetricsResponse> getJvmMetrics(MetricsRequest request) {
        return Uni.createFrom().item(this::buildMetrics);
    }

    /**
     * Server streaming — two modes depending on the request:
     *
     *   count == 0  → live mode: pushes a new snapshot every second indefinitely
     *                 Used in the demo "watch the stream" step
     *
     *   count  > 0  → benchmark mode: pushes N messages as fast as possible then stops
     *                 Used in the streaming throughput comparison vs REST polling
     *
     * In both cases: one HTTP/2 connection, zero per-message round-trip overhead.
     * The REST equivalent requires count separate HTTP requests.
     */
    @Override
    public Multi<MetricsResponse> streamMetrics(MetricsRequest request) {
        int count = request.getCount();
        if (count > 0) {
            // Benchmark mode — emit N items as fast as possible
            return Multi.createFrom().range(0, count)
                    .map(i -> buildMetrics());
        }
        // Live mode — one update per second
        return Multi.createFrom().ticks().every(Duration.ofSeconds(1))
                .map(tick -> buildMetrics());
    }

    private MetricsResponse buildMetrics() {
        var rt   = Runtime.getRuntime();
        var bean = ManagementFactory.getRuntimeMXBean();
        var gcs  = ManagementFactory.getGarbageCollectorMXBeans();

        long usedBytes = rt.totalMemory() - rt.freeMemory();
        long maxBytes  = rt.maxMemory();
        long usedMb    = usedBytes / (1024 * 1024);
        long maxMb     = maxBytes  / (1024 * 1024);
        double pct     = maxBytes > 0 ? (usedBytes * 100.0 / maxBytes) : 0;
        String gcName  = gcs.isEmpty() ? "unknown" : gcs.get(0).getName();

        return MetricsResponse.newBuilder()
                .setHeapUsedMb(usedMb)
                .setHeapMaxMb(maxMb)
                .setHeapUsedPct(Math.round(pct * 10.0) / 10.0)
                .setTimestamp(System.currentTimeMillis())
                .setJvmVersion(bean.getVmVersion())
                .setGcName(gcName)
                .setUptimeMs(bean.getUptime())
                .build();
    }
}
