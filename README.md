[![Build Status](https://github.com/dashaun/rtx5090-vllm/actions/workflows/validate.yml/badge.svg)](https://github.com/dashaun/rtx5090-vllm/actions/workflows/validate.yml)
[![Docker Size](https://img.shields.io/docker/image-size/vllm/vllm-openai/latest)](https://hub.docker.com/r/vllm/vllm-openai)
[![License](https://img.shields.io/github/license/dashaun/rtx5090-vllm)](https://github.com/dashaun/rtx5090-vllm/blob/main/LICENSE)
[![NVIDIA GPU](https://img.shields.io/badge/GPU-RTX_5090%2F4090-blue)](https://www.nvidia.com/en-us/geforce/rtx-5090/)
[![vLLM](https://img.shields.io/badge/vLLM-OpenAI_API-green)](https://github.com/vllm-project/vllm)

# rtx5090-vllm

vLLM serving Qwen3.8-27B on an RTX 5090 via Docker. OpenAI-compatible API with vision, auto-restarts on boot. This is the Ollama replacement for that box: one model, no swap logic, no keep-alive tuning.

## Why this model

- `nvidia/Qwen3.8-27B-NVFP4`, served as `qwen3.8-27b`
- 27B dense, mixed NVFP4/FP8 quantization (NVIDIA Model Optimizer): NVFP4 on MLP + lm_head, FP8 on attention. ~22 GB download, ~20.4 GiB VRAM once loaded
- Native Blackwell (sm_120) NVFP4 support, so no special quantization flags
- VLM: text, image, and video input (`Qwen3_5ForConditionalGeneration` with a vision tower)
- Hybrid attention: 16 of 64 layers are full attention, the rest linear. With `--kv-cache-dtype fp8_e4m3` that is ~32 KiB of KV per token, so 131072 context costs ~4.3 GiB and fits with ~4 GiB headroom at 0.92 utilization. Native max is 262144, which does not fit on 32 GB
- Apache-2.0, not gated, no `HF_TOKEN` needed

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

First start downloads ~22 GB of weights. Give it a few minutes before the port opens. The systemd unit waits for the `/health` endpoint before reporting the service as active, and the container exposes a Docker healthcheck, so a half-loaded model never counts as "up".

## Verify

```bash
curl localhost:8000/v1/models

curl -s localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3.8-27b", "messages": [{"role": "user", "content": "Write a fibonacci function in rust"}]}'
```

Point any OpenAI client at `http://<host>:8000/v1` with `model=qwen3.8-27b`.

## Restart on reboot

Two layers of protection:
- systemd unit starts the stack at boot and restarts it if it fails
- the container also has `restart: unless-stopped`, so Docker brings it back even if you manage it by hand

## Managing it

```bash
sudo systemctl status vllm    # logs + status
sudo systemctl restart vllm
sudo systemctl stop vllm
docker compose logs -f              # vLLM engine logs
```

## Config

Everything lives in `docker-compose.yml`:

- **Swap the model**: change the `--model` line. HF models are auto-detected; add `--quantization awq` for AWQ repos.
- **Context length**: adjust `--max-model-len`. vLLM reserves the KV cache from `--gpu-memory-utilization` either way, so this only caps a single request. It must fit in the `GPU KV cache size` from the startup log (`docker compose logs | grep "KV cache size"`). Your client (Cline, Qwen Code) has its own context setting; match it, leaving room for `max_tokens`.
- **Gated models**: copy `.env.example` to `.env`, set `HF_TOKEN` (needed for Llama 3.x or Qwen's official AWQ build).
- **Tool calling**: already enabled for agentic coding setups (Cline, Qwen Code) via `--enable-auto-tool-choice` and `--tool-call-parser qwen3_coder`, per the NVIDIA model card.
- **Reasoning**: `--reasoning-parser qwen3` separates the thinking tokens from the answer in the OpenAI-compatible output and returns them as `reasoning_content`.

Model weights cache to `<repo>/.cache/huggingface` on the host (gitignored), regardless of which user runs compose. Delete it to force a fresh download.

## Troubleshooting

- `unknown or invalid runtime name: nvidia`: the daemon didn't load the runtime. Check `/etc/docker/daemon.json`, then `sudo systemctl restart docker`. If you're on rootless Docker, switch back to the system context (this setup doesn't support rootless).
- `Quantization method specified in the model config (compressed-tensors) does not match ... (awq)`: the model is compressed-tensors, not AWQ. Don't pass `--quantization awq`; let vLLM auto-detect.
- `Failed to initialize NVML: Driver/library version mismatch`: the NVIDIA driver was updated but the box wasn't rebooted. Reboot.

## Links

- Blog: [From Ollama to vLLM on an RTX 5090](https://dashaun.com/posts/ollama-to-vllm-on-rtx-5090/)
- Demo: [YouTube Short](https://www.youtube.com/shorts/WQBXhzKN2KM)

## License

Apache-2.0
