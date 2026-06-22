# LiteLLM Gateway

LiteLLM is the OpenAI-compatible gateway in this demo. Clients send chat completion requests to LiteLLM on port 4000.

The public model name is `local-chat`. LiteLLM routes `local-chat` to Ollama through the internal Docker network.

LiteLLM uses Postgres for persistent state and Redis for cache and routing state. Its metrics endpoint is enabled for VictoriaMetrics scraping.
