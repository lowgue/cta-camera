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

# Função para iniciar streaming
iniciar_streaming() {
  echo "Iniciando transmissão..."
  echo ""

  # Tentativa 1: libcamera (rpicam-vid)
  # Novo padrão no Raspberry Pi OS (Bullseye/Bookworm) para módulos oficiais CSI
  if command -v rpicam-vid &> /dev/null; then
    echo "Usando rpicam-vid (libcamera) para melhor performance nativa..."
    # --inline injeta cabeçalhos SPS/PPS no stream de bytes H264 (necessário p/ RTSP)
    rpicam-vid -t 0 --inline --width 1280 --height 720 --framerate "$FRAMERATE" -o - | \
      ffmpeg -f h264 -i - -c:v copy -f rtsp "$RTSP_URL"
    return $?
  fi

  # Tentativa 2: libcamera-vid (versões antigas do libcamera)
  if command -v libcamera-vid &> /dev/null; then
    echo "Usando libcamera-vid para melhor performance nativa..."
    libcamera-vid -t 0 --inline --width 1280 --height 720 --framerate "$FRAMERATE" -o - | \
      ffmpeg -f h264 -i - -c:v copy -f rtsp "$RTSP_URL"
    return $?
  fi

  # Tentativa 3: V4L2 nativo assumindo saída H264
  # (Webcams USB compatíveis ou setup antigo)
  echo "Fazendo fallback para v4l2 com cópia H264..."
  ffmpeg \
    -f v4l2 \
    -input_format h264 \
    -video_size "$RESOLUTION" \
    -framerate "$FRAMERATE" \
    -i "$DEVICE" \
    -c:v copy \
    -f rtsp \
    "$RTSP_URL" || \
  
  # Tentativa 4: V4L2 recodificando por software (último caso)
  echo "Fazendo fallback para v4l2 com recodificação de software..."
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
}

# ── Fluxo principal ──────────────────────────
while true; do
  # Se rpicam-vid ou libcamera-vid estiverem presentes, não precisamos estritamente aguardar /dev/video0,
  # mas aguardamos a câmera ser detectada via libcamera-hello.
  if command -v rpicam-hello &> /dev/null; then
    echo "Procurando câmera via rpicam-hello..."
    if rpicam-hello --list-cameras | grep -q "Available cameras"; then
       echo "Câmera libcamera detectada!"
       iniciar_streaming || echo "Falha na transmissão, reiniciando..."
    else
       sleep "$RETRY_INTERVAL"
    fi
  else
    # Fallback para aguardar dispositivo v4l2
    echo "Aguardando câmera em $DEVICE..."
    if [ -e "$DEVICE" ]; then
      echo "Câmera detectada em $DEVICE!"
      iniciar_streaming || echo "Falha na transmissão, reiniciando..."
    else
      sleep "$RETRY_INTERVAL"
    fi
  fi
  sleep "$RETRY_INTERVAL"
done
