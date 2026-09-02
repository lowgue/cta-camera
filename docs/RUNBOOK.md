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

## 3. Instalar Dependências

```bash
sudo apt update
sudo apt install -y ffmpeg v4l-utils libcamera-apps git curl
```

**Validação:**

```bash
ffmpeg -version     # deve imprimir a versão do FFmpeg
v4l2-ctl --version  # deve imprimir a versão do v4l-utils
```

---

## 4. Habilitar Suporte a Câmera CSI (Camera Module)

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

## 5. Instalar o MediaMTX

```bash
cd ~
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then PKG="arm64v8"; else PKG="armv7"; fi

curl -L -o mediamtx.tar.gz \
  "https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_linux_${PKG}.tar.gz"
tar -xzf mediamtx.tar.gz
rm mediamtx.tar.gz
```

**Validação:**

```bash
ls ~/mediamtx       # o binário deve existir
~/mediamtx --help   # deve imprimir a ajuda do MediaMTX
```

---

## 6. Configurar o MediaMTX

Copie o arquivo de configuração do repositório:

```bash
cp /caminho/do/repo/cta-camera/config/mediamtx.yml ~/mediamtx.yml
```

Ou crie manualmente:

```bash
nano ~/mediamtx.yml
```

> ⚠️ **IMPORTANTE:** edite o arquivo e troque **todas** as senhas de exemplo
> (`TROCAR_SENHA_FORTE`) por senhas fortes e únicas antes de prosseguir.

A configuração habilita:
- **RTSP** na porta `8554`
- **HLS** na porta `8888`
- **WebRTC** na porta `8889`
- **Autenticação** para publicação e leitura do stream

Consulte [config/mediamtx.yml](../config/mediamtx.yml) para ver o template
completo.

**Validação:**

```bash
# Inicie o MediaMTX manualmente para testar
~/mediamtx ~/mediamtx.yml &
# Deve imprimir logs de inicialização sem erros
# Depois pare com:
kill %1
```

---

## 7. Script de Captura da Câmera

Copie o script do repositório:

```bash
cp /caminho/do/repo/cta-camera/scripts/start_camera.sh ~/start_camera.sh
chmod +x ~/start_camera.sh
```

> ⚠️ **IMPORTANTE:** edite o script e troque a senha de publicação
> (`TROCAR_SENHA_FORTE`) pela mesma senha usada em `mediamtx.yml` para o
> campo `publishPass`.

O script funciona assim:

1. Fica em loop verificando se `/dev/video0` existe.
2. Quando a câmera é conectada, tenta capturar com H264 nativo (melhor
   desempenho para Camera Module e algumas webcams).
3. Se falhar, faz fallback para recodificação via `libx264` com preset
   `ultrafast` e `zerolatency`.

Consulte [scripts/start_camera.sh](../scripts/start_camera.sh) para ver o
script completo.

**Validação:** execute `~/start_camera.sh` manualmente — sem câmera, deve
imprimir `"Aguardando câmera em /dev/video0..."` em loop.

---

## 8. Criar os Serviços systemd

Copie os arquivos de serviço do repositório:

```bash
sudo cp /caminho/do/repo/cta-camera/systemd/mediamtx.service /etc/systemd/system/
sudo cp /caminho/do/repo/cta-camera/systemd/camera.service /etc/systemd/system/
```

Ative e inicie:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mediamtx camera
sudo systemctl start mediamtx camera
```

Os serviços garantem:

| Recurso | Descrição |
|---|---|
| **Auto-start** | Iniciam automaticamente no boot |
| **Auto-restart** | Reiniciam em 5 segundos se cairem |
| **Dependência** | `camera.service` só inicia após `mediamtx.service` |

**Validação:**

```bash
sudo systemctl status mediamtx   # deve estar "active (running)"
sudo systemctl status camera     # deve estar "active (running)"
```

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

# 2. Serviço de câmera em espera
sudo systemctl status camera
# Esperado: "active (running)"

# 3. Logs mostrando espera pela câmera
journalctl -u camera -f
# Esperado: "Aguardando câmera em /dev/video0..." repetindo

# 4. Tailscale conectado
tailscale status
# Esperado: Pi listado e online
```

Se tudo estiver correto, o sistema está **pronto para receber a câmera**.

---

## 11. Ao Conectar a Câmera

Assim que a câmera física for plugada:

1. O serviço `camera.service` detecta o `/dev/video0` **automaticamente** e
   inicia a transmissão sozinho (não precisa reiniciar nada).

2. Acesse o live via qualquer dispositivo dentro da rede Tailscale:

| Protocolo | URL | Uso |
|---|---|---|
| **HLS** | `http://<IP_TAILSCALE>:8888/lab` | Navegador (compatibilidade ampla) |
| **WebRTC** | `http://<IP_TAILSCALE>:8889/lab` | Navegador (menor latência) |
| **RTSP** | `rtsp://usuario:SENHA@<IP_TAILSCALE>:8554/lab` | VLC, apps de câmera |

**Validação:**

```bash
# Verificar que a câmera foi detectada
v4l2-ctl --list-devices

# Verificar que o FFmpeg está rodando
ps aux | grep ffmpeg

# Verificar logs do serviço
journalctl -u camera -f
# Esperado: "Câmera detectada. Iniciando transmissão..."
```

---

## 12. Troubleshooting

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
# Ver logs detalhados do FFmpeg
journalctl -u camera -n 50 --no-pager

# Testar FFmpeg manualmente
ffmpeg -f v4l2 -list_formats all -i /dev/video0
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
journalctl -u camera -n 100 --no-pager
```

---

## 13. Próxima Etapa (Fora Deste Runbook)

Com o live estável, o próximo passo é instalar o **Frigate NVR** apontando
para este mesmo stream RTSP (`rtsp://localhost:8554/lab`), para adicionar:

- Detecção de pessoa via IA
- Gravação automática a partir do momento em que detecta alguém
- Base para reconhecimento facial e mapeamento de tempo de permanência

---

*Última atualização: setembro 2026*
