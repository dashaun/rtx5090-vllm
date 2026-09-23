# Script: rtx5090-vllm

- Target: ~60 seconds (~150 words at a normal speaking pace)
- Visuals: kintsugi box / RTX 5090, terminal running setup.sh, curl hitting :8000, the GitHub repo

---

Ollama is great when it's one user, one chat.
My multi-agent workflows with Spring AI were hammering it.
Agents firing dozens of requests at once,
and Ollama just queued them up and increased latency, killing performance.
So I switched to vLLM, the same inference engine running DeepSeek on my DGX Spark boxes,
and it handles the concurrency my multi-agent workflows actually need.

This repo runs vLLM on an RTX 5090 in Docker.
One command sets it up,
a systemd unit brings it back on reboot or failure,
and you get a drop-in OpenAI-compatible endpoint.

Point Spring AI or your favorite agent harness at port 8000 and you're done.
The repo ships configured for Qwen3-Coder 30B, a MoE that fits a single 5090 and stays fast under load.

If you've outgrown Ollama, clone the repo, run the setup script, and point your agents at it.

The GitHub Repo is linked below.
