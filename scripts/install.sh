#!/bin/bash
###############################################
# install.sh
# Script de instalação automatizada - CTA-Camera
###############################################

set -euo pipefail

echo "========================================="
echo " CTA-Camera — Instalação Automatizada"
echo "========================================="
echo ""

# 1. Checagem de root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Por favor, execute este script como root (sudo ./scripts/install.sh)"
  exit 1
fi

# 2. Diretórios base
INSTALL_DIR="/opt/cta-camera"
BIN_DIR="$INSTALL_DIR/bin"
CONFIG_DIR="$INSTALL_DIR/config"

echo "[1/5] Criando estrutura de diretórios em $INSTALL_DIR..."
mkdir -p "$BIN_DIR" "$CONFIG_DIR"

# 3. Instalando dependências
echo "[2/5] Instalando dependências do sistema..."
apt-get update -y
apt-get install -y ffmpeg v4l-utils libcamera-apps curl jq tar

# 4. Baixando e Instalando MediaMTX
echo "[3/5] Baixando e instalando MediaMTX..."
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then PKG="arm64v8"; else PKG="armv7"; fi

# Pegar a URL de download correta da última release
echo "  -> Buscando última versão..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest | jq -r ".assets[] | select(.name | test(\"linux_${PKG}.tar.gz$\")) | .browser_download_url" | head -n 1)

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
  echo "⚠️ Falha ao obter a URL pela API, usando link estático de fallback (v1.9.0)..."
  DOWNLOAD_URL="https://github.com/bluenviron/mediamtx/releases/download/v1.9.0/mediamtx_v1.9.0_linux_${PKG}.tar.gz"
fi

echo "  -> Baixando: $DOWNLOAD_URL"
curl -L -s -o /tmp/mediamtx.tar.gz "$DOWNLOAD_URL"

# Verifica se o arquivo baixado é realmente um gzip
if ! file /tmp/mediamtx.tar.gz | grep -q "gzip compressed data"; then
  echo "❌ Erro: O arquivo baixado não é um pacote válido (provavelmente erro 404). URL acessada: $DOWNLOAD_URL"
  exit 1
fi

tar -xzf /tmp/mediamtx.tar.gz -C "$BIN_DIR" mediamtx
rm -f /tmp/mediamtx.tar.gz
chmod +x "$BIN_DIR/mediamtx"

# 5. Copiando arquivos do projeto
echo "[4/5] Configurando arquivos e scripts..."
cp config/mediamtx.yml "$CONFIG_DIR/mediamtx.yml"

# 6. Configurando systemd
echo "[5/5] Instalando serviços systemd..."
cp systemd/mediamtx.service /etc/systemd/system/

# Ajustando caminhos nos arquivos systemd para a nova estrutura (garantia)
sed -i "s|/home/pi/mediamtx|$BIN_DIR/mediamtx|g" /etc/systemd/system/mediamtx.service
sed -i "s|/home/pi/mediamtx.yml|$CONFIG_DIR/mediamtx.yml|g" /etc/systemd/system/mediamtx.service
sed -i "s|WorkingDirectory=/home/pi|WorkingDirectory=$INSTALL_DIR|g" /etc/systemd/system/mediamtx.service

# Removendo referência hardcoded do usuário 'pi' caso ele não exista ou para usar root no serviço
sed -i '/User=pi/d' /etc/systemd/system/mediamtx.service

# Acesso ao grupo video (necessário para o rpiCamera nativo)
if ! grep -q "SupplementaryGroups=video" /etc/systemd/system/mediamtx.service; then
  sed -i '/\[Service\]/a SupplementaryGroups=video' /etc/systemd/system/mediamtx.service
fi

# Ativando os serviços
systemctl daemon-reload
systemctl enable mediamtx
systemctl restart mediamtx

echo ""
echo "========================================="
echo "✅ Instalação concluída com sucesso!"
echo "========================================="
echo "Os serviços estão rodando em background."
echo "Para ver os logs, use:"
echo "  sudo journalctl -u mediamtx -f"
echo ""
echo "Não esqueça de editar as configurações (se necessário) em:"
echo "  $CONFIG_DIR/mediamtx.yml"
echo "E então reinicie o serviço:"
echo "  sudo systemctl restart mediamtx"
