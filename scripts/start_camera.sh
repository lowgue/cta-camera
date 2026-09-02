#!/bin/bash
###############################################
# start_camera.sh
# Script de captura da câmera para o MediaMTX
# Sistema de Vigia do Laboratório (CTA)
#
# Este script aguarda a câmera aparecer em
# /dev/video0 e então inicia a transmissão
# via FFmpeg para o MediaMTX.
#
# Pode ser iniciado ANTES de plugar a câmera.
###############################################

set -euo pipefail

# ── Configuração ─────────────────────────────
DEVICE="/dev/video0"
RTSP_URL="rtsp://publicador:TROCAR_SENHA_FORTE@localhost:8554/lab"
RESOLUTION="1280x720"
FRAMERATE="30"
RETRY_INTERVAL=3   # segundos entre verificações da câmera

# ── Aguardar câmera ──────────────────────────
echo "========================================="
echo " CTA-Camera — Captura de Vídeo"
echo "========================================="
echo ""
echo "Aguardando câmera em $DEVICE..."

while [ ! -e "$DEVICE" ]; do
  sleep "$RETRY_INTERVAL"
done

echo "Câmera detectada em $DEVICE!"
echo "Iniciando transmissão..."
echo ""

# ── Iniciar transmissão ──────────────────────

# Tenta primeiro assumindo saída H264 nativa
# (Camera Module v2/v3 / algumas webcams USB)
# Isso é mais eficiente pois não precisa recodificar
ffmpeg \
  -f v4l2 \
  -input_format h264 \
  -video_size "$RESOLUTION" \
  -framerate "$FRAMERATE" \
  -i "$DEVICE" \
  -c:v copy \
  -f rtsp \
  "$RTSP_URL" \
|| \
# Fallback: câmera sem H264 nativo
# Recodifica via software (usa mais CPU)
ffmpeg \
  -f v4l2 \
  -video_size "$RESOLUTION" \
  -framerate "$FRAMERATE" \
  -i "$DEVICE" \
  -c:v libx264 \
  -preset ultrafast \
  -tune zerolatency \
  -f rtsp \
  "$RTSP_URL"
