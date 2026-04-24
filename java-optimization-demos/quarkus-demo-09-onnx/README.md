# Demo 09 — AI Inference: LangChain4j + ONNX + Panama

**Quarkus 3.33.1 LTS / JDK 25 LTS / all-MiniLM-L6-v2**

Demonstrates in-process AI inference using LangChain4j's ONNX embedding
integration — which uses **Panama FFM** under the covers to call native
ONNX Runtime inference kernels. No Python sidecar, no gRPC, no subprocess.
The model runs in the same JVM.

---

## Run the Demo

```bash
chmod +x demo.sh
./demo.sh
```

> **First run:** Downloads ~300MB (ONNX Runtime + MiniLM model) during the
> Maven build. Subsequent runs use the Podman layer cache and are fast.

**Prerequisites:** `podman` only.

---

## What's Running

```
┌──────────────────────────────────────────────────────────────────┐
│  Quarkus REST app  →  http://localhost:8080                      │
│                                                                  │
│  Stack (bottom to top):                                          │
│  MiniLM-L6-v2 ONNX model  (~25MB, bundled in Maven dep)         │
│      ↑                                                           │
│  Panama FFM  (calls native .so — no JNI, no subprocess)          │
│      ↑                                                           │
│  ONNX Runtime Java  (OrtSession, OrtTensor)                      │
│      ↑                                                           │
│  LangChain4j API  (EmbeddingModel, CosineSimilarity)             │
│      ↑                                                           │
│  Quarkus REST endpoints  (/embed, /similarity, /classify, /rank) │
└──────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
quarkus-demo-09-onnx/
├── demo.sh                              ← Run this
├── Dockerfile                           ← Two-stage build (no C++ needed)
│
└── app/
    ├── pom.xml                          ← langchain4j-embeddings-all-minilm-l6-v2
    └── src/main/java/demo/onnx/
        ├── EmbeddingModelProducer.java  ← CDI @Produces for the model
        └── OnnxResource.java            ← REST endpoints
```

---

## The Model — all-MiniLM-L6-v2

A sentence transformer model that converts text into a **384-dimension float
vector** (embedding). Sentences with similar meaning produce vectors that are
close together in the 384-dimensional space; unrelated sentences produce
vectors far apart. Distance is measured as cosine similarity (1.0 = identical
meaning, 0.0 = unrelated, -1.0 = opposite).

| Property | Value |
|----------|-------|
| Model name | all-MiniLM-L6-v2 |
| Embedding dimensions | 384 |
| Model format | ONNX |
| Model size | ~25MB |
| Bundled in | `langchain4j-embeddings-all-minilm-l6-v2` Maven dep |
| No download at runtime | Model is in the JAR — no network access needed |
| First inference latency | ~200ms (model initialisation) |
| Subsequent inference | ~5–20ms per sentence |

**No model download at runtime.** The ONNX model file is bundled inside the
Maven dependency JAR. The container image is self-contained.

---

## The Panama Connection

You do not write any Panama code in this demo. It happens transparently:

```
Your code
  → LangChain4j EmbeddingModel.embed(text)
      → ONNX Runtime Java (OrtSession.run())
          → Panama FFM (SymbolLookup + MethodHandle + Arena)
              → native libonnxruntime.so
                  → BLAS/OpenMP optimised inference kernels
```

Panama is what makes this possible without a Python sidecar. Without it,
ONNX Runtime Java would need JNI wrappers — one C file per platform,
compiled separately, bundled as platform-specific artifacts. Panama lets
ONNX Runtime Java ship a single JAR that calls the native library directly.

---

## Dependencies

```xml
<!-- Bundles: MiniLM model + ONNX Runtime Java + Panama bindings -->
<!-- Single dependency — no separate model download -->
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-embeddings-all-minilm-l6-v2</artifactId>
    <version>0.36.2</version>
</dependency>

<!-- LangChain4j core (Embedding, CosineSimilarity types) -->
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-core</artifactId>
    <version>0.36.2</version>
</dependency>
```

---

## CDI Configuration

The embedding model is injected as an `@ApplicationScoped` CDI bean:

```java
@ApplicationScoped
public class EmbeddingModelProducer {

    @Produces
    @ApplicationScoped
    public EmbeddingModel embeddingModel() {
        // Loads model on first call (~200ms)
        // Subsequent calls reuse the same instance
        return new AllMiniLmL6V2EmbeddingModel();
    }
}
```

Inject anywhere with `@Inject EmbeddingModel model`.

---

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/info` | GET | Model name, dimensions, Panama note, JVM version |
| `/embed` | GET | Embed a sentence → 384-dimension float vector |
| `/similarity` | GET | Cosine similarity between two sentences |
| `/classify` | GET | Classify an alert against runbook categories |
| `/rank` | POST | Rank a list of past incidents by similarity |
| `/q/health/live` | GET | Liveness probe |

### Query parameters

| Endpoint | Parameter | Default | Example |
|----------|-----------|---------|---------|
| `/embed` | `text` | "Hello world" | `?text=OutOfMemoryError+heap+space` |
| `/similarity` | `a`, `b` | (preset) | `?a=JVM+OOM&b=heap+exhausted` |
| `/classify` | `alert` | (preset) | `?alert=Pod+OOMKilled+exit+code+137` |

---

## Example Requests

### Check model and Panama info

```bash
curl -s http://localhost:8080/info | python3 -m json.tool
```

```json
{
  "model": "all-MiniLM-L6-v2",
  "dimensions": 384,
  "panamaNote": "ONNX Runtime uses Panama FFM to call native inference kernels — no Python sidecar, no subprocess, in-process at JVM speed",
  "javaVersion": "25.0.1"
}
```

### Embed a sentence

```bash
curl -s "http://localhost:8080/embed?text=OutOfMemoryError+in+heap+space" \
  | python3 -m json.tool
```

Returns the text, dimension count (384), and the float vector. The vector
itself is what gets stored in a vector database for semantic search.

### Semantic similarity — related vs unrelated

```bash
# Related sentences → HIGH similarity (~0.80-0.90)
curl -s "http://localhost:8080/similarity\
?a=OutOfMemoryError+heap+space\
&b=JVM+ran+out+of+memory+GC+overhead+limit+exceeded"

# Unrelated sentences → LOW similarity (~0.10-0.25)
curl -s "http://localhost:8080/similarity\
?a=OutOfMemoryError+heap+space\
&b=database+connection+pool+exhausted"
```

### Classify an alert

```bash
curl -s "http://localhost:8080/classify\
?alert=Pod+OOMKilled+exit+code+137+memory+limit+exceeded" \
  | python3 -m json.tool
```

Compares the alert against five embedded runbook category descriptions:
- GC / Memory
- CPU / Threads
- Network / Latency
- Deployment
- Database

Returns the best matching category with a confidence score and all category scores.

### Rank past incidents by similarity

```bash
curl -s -X POST http://localhost:8080/rank \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "Quarkus service restarted with OOMKilled status",
    "candidates": [
      "Pod terminated due to memory limit exceeded in payment namespace",
      "JVM heap exhausted during peak load causing restart",
      "Database connection pool at maximum capacity",
      "CPU throttling detected on order-processor containers",
      "Kubernetes node ran out of memory and evicted several pods"
    ]
  }' | python3 -m json.tool
```

Returns the candidates ranked by cosine similarity to the reference — most
similar first.

---

## Similarity Score Interpretation

| Score | Meaning |
|-------|---------|
| 0.90 – 1.00 | Very high — nearly identical meaning |
| 0.75 – 0.90 | High — strongly related |
| 0.50 – 0.75 | Moderate — somewhat related |
| 0.25 – 0.50 | Low — loosely related |
| 0.00 – 0.25 | Very low — unrelated |

---

## Practical Use Case — Incident-Aware RAG

This demo shows the foundation of a semantic incident retrieval system:

```
1. At index time:
   → Embed each past incident description
   → Store (embedding vector, incident ID) in a vector database

2. When new alert fires:
   → Embed the alert description
   → Find top-N most similar past incidents (cosine similarity)
   → Retrieve their runbooks and resolution steps

3. Optional: feed similar incidents + runbooks into an LLM
   → Generate suggested remediation steps for the new alert
```

All of step 2 runs in-process in a Quarkus pod. No Python service. No
external embedding API call. No network round-trip for inference.

---

## Memory Sizing

The ONNX Runtime native library and MiniLM model load into the JVM process:

| Component | Size |
|-----------|------|
| MiniLM-L6-v2 ONNX model | ~25MB |
| ONNX Runtime native library | ~150MB |
| ONNX Runtime inference buffers | ~50MB |
| Total ONNX overhead | ~225MB |

**Recommended container memory limit:** 1GB minimum.
- 512MB heap (`MaxRAMPercentage=75.0` × 768MB container) → too tight
- 1GB container, 75% → ~768MB heap, leaving ~256MB for ONNX overhead ✅

```yaml
resources:
  requests:
    memory: "1Gi"
  limits:
    memory: "1Gi"
```

---

## Why Not a Python Sidecar?

Teams running AI inference in Java typically consider three patterns:

| Pattern | Latency | Complexity | Cost |
|---------|---------|------------|------|
| **In-process ONNX (this demo)** | ~5-20ms | Low — single JAR dep | None |
| Python sidecar (gRPC) | ~20-50ms | High — two deployments, gRPC contract, health checks for both | 2× pod resources |
| External API (OpenAI, etc.) | ~100-500ms | Medium — API key, rate limiting, network | Per-token pricing |

For latency-sensitive use cases (real-time alert classification, online
recommendation, semantic search) the in-process pattern wins decisively.
The Panama FFM bridge is what makes it practical — the native ONNX Runtime
uses the same optimised BLAS/OpenMP kernels that the Python ONNX Runtime uses,
accessed directly from Java without a process boundary.

---

## Quarkus Native Image Compatibility

LangChain4j ONNX + Quarkus builds to a native binary:

```bash
mvn package -Dnative \
  -Dquarkus.native.container-build=true \
  -Dquarkus.native.builder-image=quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21
```

Native binary characteristics:
- Startup: ~17ms
- RSS: ~60MB
- Full inference capability — model + ONNX Runtime bundled

---

## Common Issues

**`allocateArray()` compilation error**
The Panama `Arena.allocateArray()` method was renamed to `Arena.allocateFrom()`
in the JDK 22 GA release. All code in this demo uses the correct `allocateFrom()`.

**JAX-RS annotations on record declarations**
JAX-RS annotations cannot be placed on `record` type declarations — only on
methods. All records in this demo are plain data classes with no annotations.
Endpoint annotations appear only on the method that uses them.

**First request is slow (~200ms)**
The ONNX model initialises on the first call to `embeddingModel.embed()`.
Subsequent calls are fast (~5-20ms). This is expected behaviour — add a
startup warmup step in production by calling the model during application
startup rather than on the first user request.

**Out of memory during build**
The Maven build downloads ~300MB of ONNX Runtime dependencies. If the
container runs out of disk space, increase the Podman machine disk size:
```bash
podman machine stop
podman machine set --disk-size 60
podman machine start
```

---

## Reference

- LangChain4j ONNX embeddings: https://docs.langchain4j.dev/integrations/embedding-models/in-process
- LangChain4j GitHub: https://github.com/langchain4j/langchain4j
- ONNX Runtime Java: https://onnxruntime.ai/docs/get-started/with-java.html
- all-MiniLM-L6-v2 model: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- JEP 454 — Foreign Function & Memory API: https://openjdk.org/jeps/454
- Project Panama: https://openjdk.org/projects/panama/
