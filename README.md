# rtx5090-vllm

vLLM serving Qwen3-Coder-30B-A3B on an RTX 5090 via Docker. OpenAI-compatible API, auto-restarts on boot. This is the Ollama replacement for that box: one model, no swap logic, no keep-alive tuning.

## Why this model

- `cyankiwi/Qwen3-Coder-30B-A3B-Instruct-AWQ-4bit`, served as `qwen3-coder`
- 30B total / 3.3B active (MoE), so it stays responsive on a single consumer GPU
- INT4 quantized (compressed-tensors, despite "AWQ" in the name), ~16 GB download, ~16-18 GB VRAM once loaded
- 32768 token context. Native is 262144, but that leaves no room for KV cache in 32 GB

The official Qwen AWQ build is gated behind an HF license, and the official FP8 build is ~30.5 GB with no headroom left for a 32 GB card. This one is open and auto-detected by vLLM as compressed-tensors, so no `--quantization` flag needed.

## Prerequisites

- Linux, an NVIDIA card (tested on RTX 5090, sm_120), driver >= 570
- Docker. The setup script installs it and the NVIDIA Container Toolkit if missing
- This targets the **system** Docker daemon (context `default`). Rootless Docker is not supported: it reads a different `daemon.json` and never loads the `nvidia` runtime. See Troubleshooting.

## Setup

```bash
git clone <this repo> && cd rtx5090-vllm
sudo ./scripts/setup.sh
```

What the script does:
1. Installs Docker if missing, enables it on boot
2. Installs the NVIDIA Container Toolkit, writes the `nvidia` runtime to `/etc/docker/daemon.json`, restarts Docker
3. Verifies the runtime actually loaded
4. Installs a systemd unit pinned to this clone path
5. Runs `docker compose up -d`

First start downloads ~16 GB of weights. Give it a few minutes before the port opens.

## Verify

```bash
curl localhost:8000/v1/models

curl -s localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-coder", "messages": [{"role": "user", "content": "Write a fibonacci function in rust"}]}'
```

Point any OpenAI client at `http://<host>:8000/v1` with `model=qwen3-coder`.

## Restart on reboot

Two layers of protection:
- systemd unit starts the stack at boot and restarts it if it fails
- the container also has `restart: unless-stopped`, so Docker brings it back even if you manage it by hand

## Managing it

```bash
sudo systemctl status vllm-coder    # logs + status
sudo systemctl restart vllm-coder
sudo systemctl stop vllm-coder
docker compose logs -f              # vLLM engine logs
```

## Config

Everything lives in `docker-compose.yml`:

- **Swap the model**: change the `--model` line. HF models are auto-detected; add `--quantization awq` for AWQ repos.
- **Context length**: adjust `--max-model-len`. Larger context eats more of the 32 GB.
- **Gated models**: copy `.env.example` to `.env`, set `HF_TOKEN` (needed for Llama 3.x or Qwen's official AWQ build).
- **Tool calling**: already enabled for agentic coding setups (Cline, Qwen Code) via `--enable-auto-tool-choice` and `--tool-call-parser qwen3_coder`.

Model weights cache to `<repo>/.cache/huggingface` on the host (gitignored), regardless of which user runs compose. Delete it to force a fresh download.

## Troubleshooting

- `unknown or invalid runtime name: nvidia` — the daemon didn't load the runtime. Check `/etc/docker/daemon.json`, then `sudo systemctl restart docker`. If you're on rootless Docker, switch back to the system context (this setup doesn't support rootless).
- `Quantization method specified in the model config (compressed-tensors) does not match ... (awq)` — the model is compressed-tensors, not AWQ. Don't pass `--quantization awq`; let vLLM auto-detect.
- `Failed to initialize NVML: Driver/library version mismatch` — the NVIDIA driver was updated but the box wasn't rebooted. Reboot.
