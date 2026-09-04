# CTA-Camera — Sistema de Vigia do Laboratório

Sistema de videomonitoramento para o laboratório, rodando em **Raspberry Pi 4/5**
com acesso remoto exclusivo via **Tailscale** (zero exposição pública).

## Arquitetura

```
┌──────────────┐      ┌───────────────────────┐
│  Câmera CSI  │─────▶│  MediaMTX (streaming) │
│  (rpicam)    │      │  RTSP · HLS · WebRTC  │
└──────────────┘      └───────────┬───────────┘
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
| **MediaMTX** | Servidor de streaming multi-protocolo. Captura a câmera via `rpicam` e disponibiliza RTSP, HLS, WebRTC |
| **systemd** | Gerencia o serviço com auto-start no boot e auto-restart |
| **Tailscale** | VPN mesh para acesso remoto seguro sem abrir portas |

## Status do Projeto

- [x] Streaming nativo via rpiCamera integrado
- [x] Configuração do MediaMTX (HLS + WebRTC)
- [x] Serviço systemd com integração Tailscale (auto-start + auto-restart)
- [x] Runbook completo de instalação (Etapa 1)
- [x] Frigate NVR — config + runbook (Etapa 2)
- [ ] Câmera física conectada
- [ ] Reconhecimento facial + mapeamento de permanência

## Quick Start

Consulte o **[Runbook de Instalação](docs/RUNBOOK.md)** para o guia passo a passo
completo.

Resumo rápido (após clonar no Raspberry Pi):

```bash
# Executar a instalação automatizada (baixa o MediaMTX e cria os serviços systemd)
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

> ⚠️ **Antes de usar:** edite `/opt/cta-camera/config/mediamtx.yml` caso precise
> ajustar senhas ou configurações de resolução. Após a alteração, rode `sudo systemctl restart mediamtx`.

## Acesso ao Stream

Após conectar a câmera e com Tailscale ativo:

| Protocolo | URL | Uso |
|---|---|---|
| **HLS** | `http://<IP_TAILSCALE>:8888/lab` | Navegador (compatibilidade) |
| **WebRTC** | `http://<IP_TAILSCALE>:8889/lab` | Navegador (menor latência) |
| **RTSP** | `rtsp://<IP_TAILSCALE>:8554/lab` | VLC, apps de câmera |

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
│   └── install.sh             # Script de instalação automatizada
├── storage/                   # Gravações e snapshots (não commitado)
└── systemd/
    └── mediamtx.service       # Serviço systemd do MediaMTX
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