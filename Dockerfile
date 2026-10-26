# РАДО Студия — готовая сборка для арендованной видеокарты.
# Внутри уже стоит всё: ComfyUI + узлы для аватара и видео, голос (Qwen3-TTS), музыка ставится по запросу.
# Нейросети (веса) не кладём в образ — сервер качает их сам на старте, параллельно, это быстро.
FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 UV_NO_CACHE=1 PYTHONUNBUFFERED=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 PATH=/root/.local/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl wget ffmpeg sox libsox-dev openssh-server ca-certificates tini && \
    rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# ComfyUI и узлы (аватар InfiniteTalk, видео Wan, загрузка/склейка видео)
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI /opt/ComfyUI && \
    cd /opt/ComfyUI/custom_nodes && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    PY=$(command -v python) && \
    uv pip install --system --break-system-packages -r /opt/ComfyUI/requirements.txt \
      -r ComfyUI-VideoHelperSuite/requirements.txt -r ComfyUI-KJNodes/requirements.txt \
      -r ComfyUI-WanVideoWrapper/requirements.txt && \
    uv pip install --system --break-system-packages "transformers==4.51.3" huggingface_hub hf_transfer aiohttp && \
    python -c "import torch, transformers; print(torch.__version__, torch.version.cuda, transformers.__version__)"

# Голос: отдельное окружение поверх общего torch (своя версия transformers не мешает аватару)
RUN uv venv --system-site-packages -p $(command -v python) /opt/ttsenv && \
    uv pip install -p /opt/ttsenv/bin/python qwen-tts num2words soundfile aiohttp && \
    /opt/ttsenv/bin/python -c "import qwen_tts, transformers; print('tts ok', transformers.__version__)"

RUN echo "rado-gpu $(date -u +%Y-%m-%d)" > /opt/rado_image && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# Если gpu.nz не запустит свой ssh — поднимем свой; ключи берутся из PUBLIC_KEY, если он передан
CMD ["/bin/bash", "-c", "[ -n \"$PUBLIC_KEY\" ] && echo \"$PUBLIC_KEY\" >> /root/.ssh/authorized_keys; pgrep sshd >/dev/null || /usr/sbin/sshd; sleep infinity"]
