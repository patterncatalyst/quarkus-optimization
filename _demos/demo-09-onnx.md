---
title: "Demo 09 — AI Inference: LangChain4j + ONNX + Panama"
demo_number: "09"
session: bonus
runtime: "Quarkus 3.33.1 / JDK 25 LTS"
time: "~10 min"
demo_dir: "quarkus-demo-09-onnx"
run_command: "./demo.sh"
jdk25: true
prev_url: "/demos/demo-08-panama/"
prev_title: "Demo 08 — Panama"
---

In-process AI inference via LangChain4j → ONNX Runtime → Panama FFM → native `.so`. The all-MiniLM-L6-v2 sentence embedding model (~25MB) runs in the JVM. No Python sidecar. No gRPC. No subprocess.

## The stack

```
Quarkus REST → LangChain4j EmbeddingModel
  → ONNX Runtime Java (OrtSession)
    → Panama FFM (MethodHandle + Arena)
      → native libonnxruntime.so
        → optimised BLAS inference kernels
```

## Single Maven dependency

```xml
<!-- Bundles: model + ONNX Runtime + Panama bindings — no download at runtime -->
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-embeddings-all-minilm-l6-v2</artifactId>
    <version>0.36.2</version>
</dependency>
```

## Endpoints

```bash
# 384-dimension float vector
curl "http://localhost:8080/embed?text=OutOfMemoryError+heap+space"

# Cosine similarity — related (~0.85) vs unrelated (~0.15)
curl "http://localhost:8080/similarity?a=JVM+OOM&b=heap+exhausted"

# Classify an alert into ops category
curl "http://localhost:8080/classify?alert=Pod+OOMKilled+exit+code+137"

# Rank past incidents by similarity — foundation of incident-aware RAG
curl -X POST http://localhost:8080/rank \
  -H "Content-Type: application/json" \
  -d '{"reference":"Quarkus OOMKilled","candidates":["heap exhausted","DB timeout","CPU throttle"]}'
```

> **First run:** Downloads ~300MB (ONNX Runtime + model). Subsequent runs use Podman layer cache.

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-09-onnx)
- [LangChain4j ONNX embeddings](https://docs.langchain4j.dev/integrations/embedding-models/in-process)
- [all-MiniLM-L6-v2 on HuggingFace](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
