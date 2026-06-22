# Local Model Runtime

Ollama hosts the local model runtime. The default lecture model is `qwen2.5:0.5b` because it is small enough for laptops and quick demos.

The ollama-init container pulls the configured model after Ollama becomes healthy. This keeps first startup explicit and repeatable.

The model can be changed through `OLLAMA_MODEL` and `LITELLM_OLLAMA_MODEL` in the local environment file.
