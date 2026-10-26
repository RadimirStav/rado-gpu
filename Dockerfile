FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime



ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 UV_NO_CACHE=1 PYTHONUNBUFFERED=1 \

    HF_HUB_ENABLE_HF_TRANSFER=1 PATH=/root/.local/bin:$PATH



RUN apt-get update && apt-get install -y --no-install-recommends \

      git curl wget ffmpeg sox libsox-dev openssh-server ca-certificates tini && \

    rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh && \

    curl -LsSf https://astral.sh/uv/install.sh | sh



RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI /opt/ComfyUI && \

    cd /opt/ComfyUI/custom_nodes && \

    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \

    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes && \

    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper && \

    uv pip install --system --break-system-packages -r /opt/ComfyUI/requirements.txt \

      -r ComfyUI-VideoHelperSuite/requirements.txt -r ComfyUI-KJNodes/requirements.txt \

      -r ComfyUI-WanVideoWrapper/requirements.txt && \

    uv pip install --system --break-system-packages "transformers==4.51.3" "diffusers==0.39.0" "huggingface-hub>=0.34,<1.0" hf_transfer aiohttp && \

    python -c "import torch, transformers, diffusers.pipelines.pipeline_utils; print(torch.__version__, transformers.__version__)"



RUN ( uv venv --system-site-packages -p "$(command -v python)" /opt/ttsenv && \

      uv pip install -p /opt/ttsenv/bin/python qwen-tts num2words soundfile aiohttp && \

      /opt/ttsenv/bin/python -c "import qwen_tts; print('tts ok')" ) || { echo "TTS skipped"; rm -rf /opt/ttsenv; }



RUN echo "rado-gpu $(date -u +%Y-%m-%d)" > /opt/rado_image && \

    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config



CMD ["/bin/bash", "-c", "[ -n \"$PUBLIC_KEY\" ] && echo \"$PUBLIC_KEY\" >> /root/.ssh/authorized_keys; pgrep sshd >/dev/null || /usr/sbin/sshd; sleep infinity"]

