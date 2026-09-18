#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE=vllm-coder

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./scripts/setup.sh" >&2
  exit 1
fi

# Rootless Docker reads a different daemon.json and never loads the nvidia
# runtime, so this setup only targets the system daemon.
CTX="$(docker context show 2>/dev/null || true)"
if [[ "${CTX}" != "default" ]]; then
  echo "WARNING: active docker context is '${CTX}', not 'default'. This setup" >&2
  echo "         targets the system daemon; rootless docker won't work." >&2
fi

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# 2. NVIDIA Container Toolkit (needed for --runtime nvidia)
if ! docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
  echo "Installing NVIDIA Container Toolkit..."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  apt-get update
  apt-get install -y nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
fi

# 3. Verify the runtime actually loaded. The daemon must have restarted since
#    daemon.json was written, otherwise the container fails to start with
#    "unknown or invalid runtime name: nvidia".
if ! docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
  echo "ERROR: nvidia runtime is not loaded. Check /etc/docker/daemon.json, then:" >&2
  echo "       nvidia-ctk runtime configure --runtime=docker && systemctl restart docker" >&2
  exit 1
fi

# 4. systemd unit: starts on boot, restarts on failure
sed "s|__REPO_DIR__|${REPO_DIR}|g" "${REPO_DIR}/systemd/${SERVICE}.service" \
  > "/etc/systemd/system/${SERVICE}.service"
systemctl daemon-reload
systemctl enable --now "${SERVICE}"

echo "Done. Model downloads on first start (~16 GB), then serving at http://localhost:8000"
