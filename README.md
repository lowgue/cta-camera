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
- [x] Runbook completo de instalação
- [ ] Câmera física conectada
- [ ] Frigate NVR (detecção de pessoa + gravação por evento)
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
├── docs/
│   ├── RUNBOOK.md             # Guia completo de instalação
│   └── SECURITY.md            # Notas de segurança e LGPD
├── config/
│   └── mediamtx.yml           # Configuração do MediaMTX
├── scripts/
│   └── install.sh             # Script de instalação automatizada
└── systemd/
    └── mediamtx.service       # Serviço systemd do MediaMTX
```

## Próxima Etapa

Instalar o **Frigate NVR** apontando para o stream RTSP local
(`rtsp://localhost:8554/lab`) para:

- Detecção de pessoa via IA
- Gravação automática por evento
- Base para reconhecimento facial e mapeamento de permanência

## Segurança

Consulte [docs/SECURITY.md](docs/SECURITY.md) para notas sobre:
- Gestão de senhas
- Isolamento de rede via Tailscale
- Conformidade LGPD para captação de imagens em ambiente de trabalho

## Licença

Uso interno — Laboratório CTA.