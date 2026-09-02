# CTA-Camera — Sistema de Vigia do Laboratório

Sistema de videomonitoramento para o laboratório, rodando em **Raspberry Pi 4/5**
com acesso remoto exclusivo via **Tailscale** (zero exposição pública).

## Arquitetura

```
┌──────────────┐      ┌──────────────────┐      ┌───────────────────────┐
│  Câmera CSI  │─────▶│  start_camera.sh │─────▶│  MediaMTX (streaming) │
│  ou USB      │      │  (ffmpeg)        │      │  RTSP · HLS · WebRTC  │
└──────────────┘      └──────────────────┘      └───────────┬───────────┘
                                                            │
                                                  ┌─────────▼─────────┐
                                                  │     Tailscale     │
                                                  │  (rede privada)   │
                                                  └─────────┬─────────┘
                                                            │
                                                  ┌─────────▼─────────┐
                                                  │ Dispositivos      │
                                                  │ autorizados       │
                                                  └───────────────────┘
```

### Componentes

| Componente | Função |
|---|---|
| **MediaMTX** | Servidor de streaming multi-protocolo (RTSP, HLS, WebRTC) |
| **FFmpeg** | Captura o vídeo da câmera e publica no MediaMTX via RTSP |
| **start_camera.sh** | Script que aguarda a câmera aparecer e inicia o FFmpeg |
| **systemd** | Gerencia os serviços com auto-start no boot e auto-restart |
| **Tailscale** | VPN mesh para acesso remoto seguro sem abrir portas |

## Status do Projeto

- [x] Scripts de captura e streaming
- [x] Configuração do MediaMTX (HLS + WebRTC + autenticação)
- [x] Serviços systemd (auto-start + auto-restart)
- [x] Runbook completo de instalação (Etapa 1)
- [x] Frigate NVR — config + runbook (Etapa 2)
- [ ] Câmera física conectada
- [ ] Reconhecimento facial + mapeamento de permanência

## Quick Start

Consulte o **[Runbook de Instalação](docs/RUNBOOK.md)** para o guia passo a passo
completo.

Resumo rápido (após clonar no Raspberry Pi):

```bash
# 1. Copiar os arquivos de configuração
cp config/mediamtx.yml ~/mediamtx.yml
cp scripts/start_camera.sh ~/start_camera.sh
chmod +x ~/start_camera.sh

# 2. Instalar os serviços systemd
sudo cp systemd/mediamtx.service /etc/systemd/system/
sudo cp systemd/camera.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mediamtx camera
sudo systemctl start mediamtx camera

# 3. Verificar
sudo systemctl status mediamtx camera
```

> ⚠️ **Antes de usar:** edite `mediamtx.yml` e `start_camera.sh` para trocar
> as senhas de exemplo (`TROCAR_SENHA_FORTE`).

## Acesso ao Stream

Após conectar a câmera e com Tailscale ativo:

| Protocolo | URL | Uso |
|---|---|---|
| **HLS** | `http://<IP_TAILSCALE>:8888/lab` | Navegador (compatibilidade) |
| **WebRTC** | `http://<IP_TAILSCALE>:8889/lab` | Navegador (menor latência) |
| **RTSP** | `rtsp://usuario:SENHA@<IP_TAILSCALE>:8554/lab` | VLC, apps de câmera |

## Estrutura do Repositório

```
cta-camera/
├── README.md                  # Este arquivo
├── docker-compose.yml         # Docker Compose do Frigate NVR
├── docs/
│   ├── RUNBOOK.md             # Etapa 1 — Streaming (MediaMTX + Tailscale)
│   ├── RUNBOOK-FRIGATE.md     # Etapa 2 — Detecção (Frigate NVR)
│   └── SECURITY.md            # Notas de segurança e LGPD
├── config/
│   ├── mediamtx.yml           # Configuração do MediaMTX
│   └── frigate.yml            # Configuração do Frigate NVR
├── scripts/
│   └── start_camera.sh        # Script de captura da câmera
├── storage/                   # Gravações e snapshots (não commitado)
└── systemd/
    ├── mediamtx.service       # Serviço systemd do MediaMTX
    └── camera.service         # Serviço systemd da câmera
```

## Etapas

| Etapa | Runbook | Descrição |
|---|---|---|
| **1 — Streaming** | [RUNBOOK.md](docs/RUNBOOK.md) | MediaMTX + câmera + Tailscale |
| **2 — Detecção** | [RUNBOOK-FRIGATE.md](docs/RUNBOOK-FRIGATE.md) | Frigate NVR + detecção de pessoa + gravação |

### Próxima Etapa

- Reconhecimento facial — identificar quem é a pessoa
- Mapeamento de permanência — tempo de cada pessoa no lab
- Alertas — notificações via Telegram/email

## Segurança

Consulte [docs/SECURITY.md](docs/SECURITY.md) para notas sobre:
- Gestão de senhas
- Isolamento de rede via Tailscale
- Conformidade LGPD para captação de imagens em ambiente de trabalho

## Licença

Uso interno — Laboratório CTA.