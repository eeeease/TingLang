"""Build assets/providers/catalog.v1.json from LiteLLM's model catalog.

LiteLLM (MIT, Copyright (c) 2023 Berri AI, https://github.com/BerriAI/litellm)
maintains `model_prices_and_context_window.json`: per-model provider, context
window, prices and capability flags. Tinglang keeps the chat models of the
providers below, with the fields it shows (context, $/1M tokens, structured
output support). Base URLs follow LiteLLM's own defaults.

Usage:
  curl -L -o /tmp/litellm.json \
    https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
  python3 tools/build_provider_catalog.py /tmp/litellm.json [YYYY-MM-DD]
"""
import json, re, sys, datetime

# id, label, protocol, base URL, LiteLLM provider key (None: models come from
# the server's /models), needs a key.
PROVIDERS = [
    ("anthropic", "Anthropic (Claude)", "anthropic", "https://api.anthropic.com/v1", "anthropic", True),
    ("openai", "OpenAI", "openai", "https://api.openai.com/v1", "openai", True),
    ("deepseek", "DeepSeek", "openai", "https://api.deepseek.com/v1", "deepseek", True),
    ("dashscope", "Alibaba DashScope (Qwen)", "openai", "https://dashscope.aliyuncs.com/compatible-mode/v1", "dashscope", True),
    ("moonshot", "Moonshot (Kimi)", "openai", "https://api.moonshot.ai/v1", "moonshot", True),
    ("zai", "Z.ai (GLM)", "openai", "https://api.z.ai/api/paas/v4", "zai", True),
    ("volcengine", "Volcengine Ark (Doubao)", "openai", "https://ark.cn-beijing.volces.com/api/v3", "volcengine", True),
    ("minimax", "MiniMax", "openai", "https://api.minimax.io/v1", "minimax", True),
    ("gemini", "Google Gemini", "openai", "https://generativelanguage.googleapis.com/v1beta/openai", "gemini", True),
    ("xai", "xAI (Grok)", "openai", "https://api.x.ai/v1", "xai", True),
    ("mistral", "Mistral", "openai", "https://api.mistral.ai/v1", "mistral", True),
    ("groq", "Groq", "openai", "https://api.groq.com/openai/v1", "groq", True),
    ("together", "Together AI", "openai", "https://api.together.ai/v1", "together_ai", True),
    ("fireworks", "Fireworks AI", "openai", "https://api.fireworks.ai/inference/v1", "fireworks_ai", True),
    ("openrouter", "OpenRouter", "openai", "https://openrouter.ai/api/v1", None, True),
    ("litellm", "LiteLLM Proxy", "openai", "http://localhost:4000/v1", None, False),
    ("ollama", "Ollama", "openai", "http://localhost:11434/v1", None, False),
    ("lmstudio", "LM Studio", "openai", "http://localhost:1234/v1", None, False),
]

# Suggested model per provider (must exist in the catalog). Anthropic uses
# Claude Opus 5.5, the current default Claude model.
DEFAULTS = {
    "anthropic": "claude-opus-5-5", "openai": "gpt-5-mini", "deepseek": "deepseek-v4-flash",
    "dashscope": "qwen-plus", "moonshot": "kimi-k2.6", "zai": "glm-5.1",
    "volcengine": "doubao-seed-2-1-pro-260915", "minimax": "MiniMax-M3", "gemini": "gemini-2.5-flash",
    "xai": "grok-4.5", "mistral": "mistral-medium-latest", "groq": "openai/gpt-oss-120b",
    "together": "deepseek-ai/DeepSeek-V4.1-Flash",
}

def per_million(v):
    return None if v is None else round(float(v) * 1e6, 4)

def main(path, today):
    src = json.load(open(path))
    models = {}
    for pid, _, _, _, key, _ in PROVIDERS:
        if key is None:
            continue
        rows = {}
        for name, spec in src.items():
            if not isinstance(spec, dict) or spec.get("litellm_provider") != key or spec.get("mode") != "chat":
                continue
            if (spec.get("deprecation_date") or "9999") < today:
                continue
            mid = name.split("/", 1)[1] if name.startswith(key + "/") else name
            if mid.startswith("ft:") or spec.get("input_cost_per_token") is None:
                continue  # fine-tunes and entries without a price
            rows.setdefault(mid, [
                mid,
                spec.get("max_input_tokens") or spec.get("max_tokens"),
                per_million(spec.get("input_cost_per_token")),
                per_million(spec.get("output_cost_per_token")),
                1 if spec.get("supports_response_schema") else 0,
            ])
        # Drop dated snapshots when the undated alias is listed too.
        for mid in list(rows):
            alias = re.sub(r"-\d{8}$", "", mid)
            if alias != mid and alias in rows:
                del rows[mid]
        models[pid] = sorted(rows.values(), key=lambda r: r[0])
    out = {
        "meta": {
            "source": "LiteLLM model_prices_and_context_window.json",
            "license": "MIT, Copyright (c) 2023 Berri AI",
            "url": "https://github.com/BerriAI/litellm",
            "built": today,
            "model_fields": ["id", "context", "input_usd_per_mtok", "output_usd_per_mtok", "json_schema"],
        },
        "providers": [
            {"id": pid, "label": label, "protocol": proto, "base_url": url, "needs_key": key_needed,
             "default_model": DEFAULTS.get(pid, "")}
            for pid, label, proto, url, _, key_needed in PROVIDERS
        ],
        "models": models,
    }
    raw = json.dumps(out, ensure_ascii=False, separators=(",", ":"))
    with open("assets/providers/catalog.v1.json", "w") as f:
        f.write(raw + "\n")
    print(f"{len(PROVIDERS)} providers, {sum(len(v) for v in models.values())} models, {len(raw)//1024} KB")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else datetime.date.today().isoformat())
