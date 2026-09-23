<!--
  The SVGs in this post are inline and animated (SMIL). They render in any
  browser. If you publish somewhere that strips inline SVG from Markdown
  (GitHub renders them as text), export each block to an .svg file or use a
  renderer that allows raw HTML.
-->

# From Ollama to vLLM on an RTX 5090

I run a couple of DGX Sparks with DeepSeek via vLLM and Ray. The RTX 5090 box (kintsugi) was still on Ollama. That split stopped making sense once my agent workflows outgrew what Ollama does well.

## Why I left Ollama

Ollama is fine for one user and one chat. My multi-agent workflows fire dozens of concurrent requests, and Ollama serializes them behind a single model slot. Queues form, latency climbs, and agents stall waiting on each other.

vLLM does continuous batching. Requests arrive, get packed into the same forward pass, and everyone gets a turn. Same GPU, but the pipeline stays busy.

<svg viewBox="0 0 760 420" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Ollama queues requests, vLLM batches them">
  <rect width="760" height="420" fill="#ffffff"/>
  <text x="24" y="28" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="14" font-weight="600" fill="#24292f">Multi-agent load</text>

  <!-- Ollama panel -->
  <rect x="24" y="44" width="336" height="340" rx="12" fill="#fafbfc" stroke="#24292f" stroke-width="1.5"/>
  <text x="192" y="70" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="14" font-weight="600" fill="#d1242f">Ollama</text>

  <g font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" text-anchor="middle" fill="#24292f">
    <rect x="44" y="96" width="110" height="30" rx="6" fill="#ffffff" stroke="#d1242f" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="0.4s" dur="0.3s" fill="freeze"/></rect><text x="99" y="116" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="0.4s" dur="0.3s" fill="freeze"/>req 1</text>
    <rect x="44" y="136" width="110" height="30" rx="6" fill="#ffffff" stroke="#d1242f" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="1.0s" dur="0.3s" fill="freeze"/></rect><text x="99" y="156" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="1.0s" dur="0.3s" fill="freeze"/>req 2</text>
    <rect x="44" y="176" width="110" height="30" rx="6" fill="#ffffff" stroke="#d1242f" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="1.6s" dur="0.3s" fill="freeze"/></rect><text x="99" y="196" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="1.6s" dur="0.3s" fill="freeze"/>req 3</text>
    <rect x="44" y="216" width="110" height="30" rx="6" fill="#ffffff" stroke="#d1242f" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="2.2s" dur="0.3s" fill="freeze"/></rect><text x="99" y="236" opacity="0"><animate attributeName="opacity" from="0" to="1" begin="2.2s" dur="0.3s" fill="freeze"/>req 4</text>
  </g>
  <text x="99" y="268" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">queue grows</text>

  <path d="M 154 200 H 208" stroke="#d1242f" stroke-width="2" stroke-dasharray="6 4" fill="none"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.8s" repeatCount="indefinite"/></path>

  <rect x="208" y="140" width="136" height="120" rx="10" fill="#ffffff" stroke="#d1242f" stroke-width="2"/>
  <text x="276" y="186" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">model slot</text>
  <text x="276" y="206" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">one at a time</text>
  <text x="276" y="240" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#d1242f">1 / N served</text>

  <!-- vLLM panel -->
  <rect x="400" y="44" width="336" height="340" rx="12" fill="#fafbfc" stroke="#24292f" stroke-width="1.5"/>
  <text x="568" y="70" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="14" font-weight="600" fill="#1a7f37">vLLM</text>

  <g font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" text-anchor="middle" fill="#24292f">
    <rect x="420" y="96" width="110" height="30" rx="6" fill="#ffffff" stroke="#1a7f37"/><text x="475" y="116">req 1</text>
    <rect x="420" y="136" width="110" height="30" rx="6" fill="#ffffff" stroke="#1a7f37"/><text x="475" y="156">req 2</text>
    <rect x="420" y="176" width="110" height="30" rx="6" fill="#ffffff" stroke="#1a7f37"/><text x="475" y="196">req 3</text>
  </g>
  <text x="475" y="240" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">in parallel</text>

  <path d="M 530 111 C 552 111 552 140 560 140" stroke="#1a7f37" stroke-width="2" stroke-dasharray="6 4" fill="none"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.6s" repeatCount="indefinite"/></path>
  <path d="M 530 151 C 552 151 552 160 560 160" stroke="#1a7f37" stroke-width="2" stroke-dasharray="6 4" fill="none"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.6s" repeatCount="indefinite"/></path>
  <path d="M 530 191 C 552 191 552 180 560 180" stroke="#1a7f37" stroke-width="2" stroke-dasharray="6 4" fill="none"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.6s" repeatCount="indefinite"/></path>

  <rect x="560" y="130" width="160" height="120" rx="10" fill="#ffffff" stroke="#1a7f37" stroke-width="2"/>
  <text x="640" y="176" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">engine</text>
  <text x="640" y="196" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">batch</text>
  <rect x="578" y="212" width="124" height="8" rx="4" fill="#d0d7de"/>
  <rect x="578" y="212" width="20" height="8" rx="4" fill="#1a7f37"><animate attributeName="width" values="20;124;20" dur="2.5s" repeatCount="indefinite"/></rect>
  <text x="640" y="240" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#1a7f37">3 / 3 concurrent</text>
</svg>

## The box before

kintsugi ran Ollama with eleven models: a few Qwen sizes, Llama 3.x, Phi-4, Granite, an embedding model, and two FLUX diffusion models. The FLUX models moved to a 4090 / M4 because vLLM does not serve diffusion image models. It serves LLMs.

## Picking a model

For a 32 GB card the sweet spot is a MoE with sparse active params: fast because only a slice of the network runs per token, small enough to quantize into the card. That pointed at Qwen3-Coder-30B-A3B (30B total, 3.3B active).

Then the quantization decision.

<svg viewBox="0 0 760 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Model quantization decision">
  <rect width="760" height="300" fill="#ffffff"/>
  <text x="24" y="28" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="14" font-weight="600" fill="#24292f">Qwen3-Coder-30B-A3B on 32 GB</text>
  <text x="24" y="48" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#57606a">30B total · 3.3B active · MoE</text>

  <!-- row 1: official AWQ -->
  <rect x="24" y="66" width="580" height="56" rx="10" fill="#fafbfc" stroke="#d0d7de" stroke-width="1.5"/>
  <text x="48" y="90" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">Official AWQ</text>
  <text x="48" y="110" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#57606a">gated · needs HF token and license</text>
  <text x="668" y="102" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="20" font-weight="600" fill="#d1242f">✗</text>

  <!-- row 2: official FP8 -->
  <rect x="24" y="134" width="580" height="56" rx="10" fill="#fafbfc" stroke="#d0d7de" stroke-width="1.5"/>
  <text x="48" y="158" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">Official FP8</text>
  <text x="48" y="178" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#57606a">~30.5 GB weights · no KV cache headroom in 32 GB</text>
  <text x="668" y="170" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="20" font-weight="600" fill="#d1242f">✗</text>

  <!-- row 3: chosen -->
  <rect x="24" y="202" width="580" height="56" rx="10" fill="#f6fff8" stroke="#1a7f37" stroke-width="2"/>
  <text x="48" y="226" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">cyankiwi INT4</text>
  <text x="48" y="246" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" fill="#57606a">open · ~16 GB · auto-detected (compressed-tensors)</text>
  <rect x="620" y="214" width="96" height="28" rx="14" fill="#1a7f37"/>
  <text x="668" y="233" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="600" fill="#ffffff">chosen</text>
  <path d="M 648 270 l 12 12 l 22 -22" fill="none" stroke="#1a7f37" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" pathLength="1" stroke-dasharray="1 1" stroke-dashoffset="1"><animate attributeName="stroke-dashoffset" from="1" to="0" dur="0.5s" begin="1s" fill="freeze"/></path>
</svg>

I serve one model, no swap logic. vLLM keeps weights in VRAM for the life of the process, so unlike Ollama there is no load and unload. With one model that is exactly what I want.

## How it runs

The repo is self-contained: a compose file, a setup script, and a systemd unit. `sudo ./scripts/setup.sh` installs Docker and the NVIDIA Container Toolkit if missing, wires the nvidia runtime, installs the unit, and starts the stack. The unit plus `restart: unless-stopped` mean the box comes back serving after a reboot.

```bash
git clone https://github.com/dashaun/rtx5090-vllm
cd rtx5090-vllm
sudo ./scripts/setup.sh
curl localhost:8000/v1/models
```

<svg viewBox="0 0 760 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="kintsugi architecture">
  <rect width="760" height="400" fill="#ffffff"/>
  <text x="24" y="28" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="14" font-weight="600" fill="#24292f">Agents</text>

  <g font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12">
    <rect x="24" y="44" width="130" height="56" rx="8" fill="#f6f8fa" stroke="#24292f" stroke-width="1.5"/>
    <text x="89" y="68" text-anchor="middle" font-weight="600" fill="#24292f">Agent</text>
    <text x="89" y="86" text-anchor="middle" fill="#57606a">Cline</text>
    <rect x="24" y="116" width="130" height="56" rx="8" fill="#f6f8fa" stroke="#24292f" stroke-width="1.5"/>
    <text x="89" y="140" text-anchor="middle" font-weight="600" fill="#24292f">Agent</text>
    <text x="89" y="158" text-anchor="middle" fill="#57606a">LangChain</text>
    <rect x="24" y="188" width="130" height="56" rx="8" fill="#f6f8fa" stroke="#24292f" stroke-width="1.5"/>
    <text x="89" y="212" text-anchor="middle" font-weight="600" fill="#24292f">Agent</text>
    <text x="89" y="230" text-anchor="middle" fill="#57606a">Qwen Code</text>
  </g>

  <g stroke="#0969da" stroke-width="2" stroke-dasharray="6 4" fill="none">
    <path d="M 154 72 H 300"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.8s" repeatCount="indefinite"/></path>
    <path d="M 154 144 H 300"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.8s" repeatCount="indefinite"/></path>
    <path d="M 154 216 H 300"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="0.8s" repeatCount="indefinite"/></path>
  </g>

  <rect x="300" y="40" width="250" height="320" rx="12" fill="#fafbfc" stroke="#24292f" stroke-width="1.5"/>
  <text x="425" y="66" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="13" font-weight="600" fill="#24292f">vLLM · Docker</text>

  <rect x="322" y="84" width="206" height="56" rx="8" fill="#ffffff" stroke="#0969da" stroke-width="1.5"/>
  <text x="425" y="106" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="600" fill="#0969da">API server</text>
  <text x="425" y="124" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">POST /v1/chat/completions</text>

  <rect x="322" y="164" width="206" height="64" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="1.5"/>
  <text x="425" y="186" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="600" fill="#24292f">Engine</text>
  <text x="425" y="204" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">continuous batching</text>
  <rect x="340" y="214" width="170" height="6" rx="3" fill="#d0d7de"/>
  <rect x="340" y="214" width="20" height="6" rx="3" fill="#0969da"><animate attributeName="width" values="20;170;20" dur="3s" repeatCount="indefinite"/></rect>

  <rect x="322" y="252" width="206" height="64" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="1.5"/>
  <text x="425" y="274" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="600" fill="#24292f">qwen3-coder</text>
  <text x="425" y="292" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">30B-A3B · INT4 · 16 GB</text>

  <g stroke="#24292f" stroke-width="2" fill="none">
    <path d="M 425 140 V 164"/>
    <path d="M 425 228 V 252"/>
    <path d="M 528 284 H 590"/>
  </g>

  <rect x="590" y="120" width="150" height="130" rx="12" fill="#f6f8fa" stroke="#24292f" stroke-width="1.5"/>
  <rect x="590" y="120" width="150" height="130" rx="12" fill="none" stroke="#0969da" stroke-width="2"><animate attributeName="opacity" values="0.3;1;0.3" dur="2s" repeatCount="indefinite"/></rect>
  <text x="665" y="146" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="600" fill="#24292f">RTX 5090</text>
  <g fill="#0969da">
    <rect x="612" y="162" width="20" height="20" rx="4"/>
    <rect x="640" y="162" width="20" height="20" rx="4"/>
    <rect x="668" y="162" width="20" height="20" rx="4"/>
    <rect x="612" y="190" width="20" height="20" rx="4"/>
    <rect x="640" y="190" width="20" height="20" rx="4"/>
    <rect x="668" y="190" width="20" height="20" rx="4"/>
  </g>
  <text x="665" y="238" text-anchor="middle" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">32 GB</text>

  <path d="M 590 300 C 500 340, 320 340, 154 240" fill="none" stroke="#1a7f37" stroke-width="2" stroke-dasharray="6 4"><animate attributeName="stroke-dashoffset" from="0" to="-20" dur="1.2s" repeatCount="indefinite"/></path>
  <text x="330" y="362" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#1a7f37">tokens back to agents</text>

  <text x="24" y="382" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" fill="#57606a">kintsugi · Ubuntu · systemd restarts it on boot</text>
</svg>

## What bit us

Everything looked simple until it ran. Four problems, each with a clear cause once we found it.

<svg viewBox="0 0 760 500" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Deployment problems and fixes">
  <rect width="760" height="500" fill="#ffffff"/>
  <line x1="60" y1="80" x2="60" y2="440" stroke="#d0d7de" stroke-width="3" pathLength="1" stroke-dasharray="1 1" stroke-dashoffset="1"><animate attributeName="stroke-dashoffset" from="1" to="0" dur="1.6s" fill="freeze"/></line>

  <g font-family="ui-monospace,SFMono-Regular,Menlo,monospace">
    <!-- item 1 -->
    <circle cx="60" cy="96" r="16" fill="#24292f"/><text x="60" y="101" text-anchor="middle" font-size="13" font-weight="600" fill="#ffffff">1</text>
    <text x="96" y="88" font-size="13" font-weight="600" fill="#d1242f">nvidia-smi fails</text>
    <text x="96" y="108" font-size="12" fill="#57606a">cause: driver updated, kernel module stale, box up 10 days</text>
    <text x="96" y="126" font-size="12" fill="#1a7f37">fix: reboot</text>

    <!-- item 2 -->
    <circle cx="60" cy="196" r="16" fill="#24292f"/><text x="60" y="201" text-anchor="middle" font-size="13" font-weight="600" fill="#ffffff">2</text>
    <text x="96" y="188" font-size="13" font-weight="600" fill="#d1242f">unknown or invalid runtime name: nvidia</text>
    <text x="96" y="208" font-size="12" fill="#57606a">cause: rootless vs system Docker; daemon.json not reloaded</text>
    <text x="96" y="226" font-size="12" fill="#1a7f37">fix: target system daemon, systemctl restart docker</text>

    <!-- item 3 -->
    <circle cx="60" cy="296" r="16" fill="#24292f"/><text x="60" y="301" text-anchor="middle" font-size="13" font-weight="600" fill="#ffffff">3</text>
    <text x="96" y="288" font-size="13" font-weight="600" fill="#d1242f">compressed-tensors does not match awq</text>
    <text x="96" y="308" font-size="12" fill="#57606a">cause: model is INT4 compressed-tensors despite the AWQ name</text>
    <text x="96" y="326" font-size="12" fill="#1a7f37">fix: drop --quantization awq, let vLLM read the config</text>

    <!-- item 4 -->
    <circle cx="60" cy="396" r="16" fill="#24292f"/><text x="60" y="401" text-anchor="middle" font-size="13" font-weight="600" fill="#ffffff">4</text>
    <text x="96" y="388" font-size="13" font-weight="600" fill="#d1242f">17 GB of weights in a literal ~ dir</text>
    <text x="96" y="408" font-size="12" fill="#57606a">cause: Compose does not expand ~ in volume paths</text>
    <text x="96" y="426" font-size="12" fill="#1a7f37">fix: mount ./.cache/huggingface relative to the project</text>
  </g>
</svg>

1. `nvidia-smi` failed with a driver/library mismatch. The driver had been updated, the kernel module was stale, and the box had been up for ten days. Fix: reboot.

2. `docker compose up` died with "unknown or invalid runtime name: nvidia". The box runs rootless Docker as the user context, but the systemd unit talks to the system daemon. The daemon had a daemon.json declaring the nvidia runtime that it was not loading. Fix: restart Docker and target the system daemon. Rootless Docker is not supported by this setup, and that is now documented.

3. vLLM crashed on startup: the model config says compressed-tensors, and I had forced `--quantization awq`. The "AWQ" in the repo name lied. Fix: delete the flag and let vLLM read the config.

4. A few days in I found 17 GB of model weights inside a directory literally named `~`. Compose does not expand `~` in volume paths, so the cache mount created a literal directory. Fix: mount `./.cache/huggingface`, which Compose resolves relative to the project. The cache is gitignored, so the repo stays clean.

## Decisions that stuck

- System Docker, not rootless, for the service. The systemd unit runs compose as root, and rootless Docker ignores /etc/docker/daemon.json.
- compressed-tensors INT4 over a gated AWQ build and an FP8 build that does not fit.
- One model, no swap. A second model means a second compose service, not Ollama-style load and unload.
- Model cache in the repo under `.cache`, so `git pull` plus a restart updates the stack without re-downloading weights.

## Where it landed

Public repo: https://github.com/dashaun/rtx5090-vllm

An OpenAI-compatible endpoint at `http://kintsugi:8000/v1` serving `qwen3-coder`. Point LangChain, Cline, Qwen Code, or any agent framework at it. Ollama is uninstalled and its ~94 GB of models are gone from the box.

If you have outgrown Ollama, clone it and take it for a spin. The setup script is the whole story: one command, reboot safe.
