package demo.onnx;

import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;

/**
 * CDI producer for the ONNX embedding model.
 *
 * AllMiniLmL6V2EmbeddingModel bundles the all-MiniLM-L6-v2 ONNX model
 * (~25MB) inside the langchain4j-embeddings-all-minilm-l6-v2 dependency.
 * No external model download needed at runtime.
 *
 * Internally: LangChain4j → ONNX Runtime Java → Panama FFM → native .so
 */
@ApplicationScoped
public class EmbeddingModelProducer {

    @Produces
    @ApplicationScoped
    public EmbeddingModel embeddingModel() {
        // Loads and initialises the ONNX model — takes ~200ms on first call
        return new AllMiniLmL6V2EmbeddingModel();
    }
}
