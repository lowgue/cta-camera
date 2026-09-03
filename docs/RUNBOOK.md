# Runbook — Sistema de Vigia do Laboratório (Raspberry Pi)

> Guia completo para deixar o sistema 100% pronto, faltando apenas conectar a
> câmera física no Raspberry Pi. Execute os passos na ordem. Cada seção indica
> como validar antes de seguir.

---

## Objetivo Final

Ao terminar este runbook, o sistema deve:

1. Ligar sozinho no boot do Raspberry Pi.
2. Detectar a câmera automaticamente assim que ela for conectada.
3. Publicar o vídeo ao vivo em RTSP, HLS e WebRTC na rede local.
4. Estar acessível remotamente apenas por dispositivos autorizados via Tailscale
   (sem exposição pública à internet).
5. Reiniciar sozinho qualquer serviço que cair.
6. Estar pronto para, na etapa seguinte, receber o Frigate para detecção de
   pessoa e gravação por evento.

---

## 1. Pré-requisitos

| Requisito | Detalhes |
|---|---|
| **Hardware** | Raspberry Pi 4 ou 5 (mínimo 2 GB RAM) |
| **Sistema** | Raspberry Pi OS Lite (64-bit) instalado |
| **Acesso** | SSH habilitado |
| **Rede** | Conexão com internet (para instalação de pacotes e Tailscale) |
| **Câmera** | Ainda **não** precisa estar conectada |

---

## 2. Atualizar o Sistema

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

**Validação:** após o reboot, reconecte via SSH e confirme que
`sudo apt update` não mostra pacotes pendentes.

---

## 3. Habilitar Suporte a Câmera CSI (Camera Module)

Mesmo sem a câmera conectada, deixe a interface habilitada:

```bash
sudo raspi-config nonint do_camera 0
sudo reboot
```

> **Nota:** se a câmera usada for **USB (webcam)**, este passo não é
> necessário — o Linux reconhece automaticamente como `/dev/videoX` ao
> conectar.

**Validação:** após o reboot, `sudo raspi-config nonint get_camera` deve
retornar `0` (habilitado).

---

## 4. Instalação Automatizada

Para simplificar o setup, o repositório conta com um script que baixa o MediaMTX,
instala as dependências, copia as configurações e cria os serviços systemd
automaticamente.

Execute na pasta raiz do repositório clonado:

```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

**O que o script faz:**
1. Instala `ffmpeg` (ferramentas auxiliares), `v4l-utils`, e `libcamera-apps`.
2. Baixa e instala a versão correta do MediaMTX para sua arquitetura em `/opt/cta-camera/bin`.
3. Copia `mediamtx.yml` para `/opt/cta-camera/config/`.
4. Cria e inicia o serviço systemd (`mediamtx.service`).

> ⚠️ **IMPORTANTE (Após a instalação):** 
> Edite o arquivo `/opt/cta-camera/config/mediamtx.yml` caso precise ajustar
> parâmetros como resolução. Após editar, reinicie o serviço com:
> `sudo systemctl restart mediamtx`

---

## 9. Instalar e Configurar o Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

1. O comando gera um **link de login** — abra em um navegador para autorizar
   o Raspberry Pi na sua conta Tailscale.
2. Após autorizar, o Pi ganha um **IP privado fixo** (tipo `100.x.x.x`) que
   só aparelhos autorizados na sua rede Tailscale conseguem acessar.
3. **Não é necessário** abrir portas no roteador nem usar ngrok/Cloudflare.

**Validação:**

```bash
tailscale ip -4      # deve mostrar um IP 100.x.x.x
tailscale status     # deve mostrar o Pi conectado ao Tailnet
```

---

## 10. Checklist Final (Antes de Plugar a Câmera)

Execute todos os comandos abaixo e confirme os resultados esperados:

```bash
# 1. MediaMTX rodando
sudo systemctl status mediamtx
# Esperado: "active (running)"

# 2. Tailscale conectado
tailscale status
# Esperado: Pi listado e online
```

Se tudo estiver correto, o sistema está **pronto para receber a câmera**.

---

## 11. Ao Conectar a Câmera

Assim que a câmera física for plugada:

1. O MediaMTX detecta a câmera **automaticamente** via API libcamera e inicia 
   a transmissão local no momento em que alguém acessa (ou de imediato, caso 
   configure acesso constante).

2. Acesse o live via qualquer dispositivo dentro da rede Tailscale:

| Protocolo | URL | Uso |
|---|---|---|
| **HLS** | `http://<IP_TAILSCALE>:8888/lab` | Navegador (compatibilidade ampla) |
| **WebRTC** | `http://<IP_TAILSCALE>:8889/lab` | Navegador (menor latência) |
| **RTSP** | `rtsp://<IP_TAILSCALE>:8554/lab` | VLC, apps de câmera |

**Validação:**

# Verificar que a câmera foi detectada pelo sistema
v4l2-ctl --list-devices
libcamera-hello --list-cameras

# Verificar logs do serviço MediaMTX
journalctl -u mediamtx -f
# Esperado: "rtsp server created" e acesso a /lab
```

---

## 12. Acesso Público Seguro (Tailscale Funnel)

Se você quiser que outras pessoas do laboratório acessem o vídeo pelo
navegador, **sem precisarem instalar o Tailscale**, use o Tailscale Funnel
para criar um link HTTPS público.

1. **Ative o Funnel na sua conta:**
   - Acesse o [Tailscale Admin Console](https://login.tailscale.com/admin/acls).
   - Na aba "Access Controls", garanta que o nó `nodeAttrs` permite o Funnel.
     (Normalmente já vem uma opção na interface web para ativar o Funnel).

2. **Ative no Raspberry Pi:**
   Vamos expor a porta 8889 (WebRTC) para a internet:
   ```bash
   sudo tailscale funnel 8889
   ```

3. **Compartilhe o Link:**
   O comando acima manterá o túnel aberto e exibirá a URL pública, algo como:
   👉 `https://raspberrypi.sua-rede.ts.net`

4. **Como Acessar:**
   - Envie a URL gerada (acrescentada de `/lab`) para o pessoal do laboratório:
     `https://raspberrypi.sua-rede.ts.net/lab`
   - Ao acessar, o navegador pedirá um **Usuário** e **Senha**.
   - Eles devem digitar as credenciais de leitura (`readUser` e `readPass`)
     configuradas no `mediamtx.yml`. O vídeo aparecerá em seguida!

> 💡 Dica: Para rodar o funnel em background e iniciar junto com o sistema,
> execute: `sudo tailscale serve https / http://127.0.0.1:8889`

---

## 13. Troubleshooting

### A câmera não é detectada

```bash
# Listar dispositivos de vídeo
ls -la /dev/video*
v4l2-ctl --list-devices

# Se for câmera CSI, verificar com libcamera
libcamera-hello --list-cameras
```

### O stream não inicia

```bash
# Ver logs detalhados do MediaMTX
journalctl -u mediamtx -n 50 --no-pager

# Verificar se a câmera está ocupada por outro processo
lsof /dev/video0
```

### Não consigo acessar remotamente

```bash
# Verificar se Tailscale está ativo
tailscale status

# Testar conectividade de outro dispositivo na Tailnet
ping <IP_TAILSCALE_DO_PI>

# Verificar se as portas estão escutando
ss -tlnp | grep -E '8554|8888|8889'
```

### Serviço reiniciando em loop

```bash
# Ver últimas 100 linhas de log
journalctl -u mediamtx -n 100 --no-pager
```

---

## 14. Próxima Etapa (Fora Deste Runbook)

Com o live estável, o próximo passo é instalar o **Frigate NVR** apontando
para este mesmo stream RTSP (`rtsp://localhost:8554/lab`), para adicionar:

- Detecção de pessoa via IA
- Gravação automática a partir do momento em que detecta alguém
- Base para reconhecimento facial e mapeamento de tempo de permanência

---

*Última atualização: setembro 2026*
