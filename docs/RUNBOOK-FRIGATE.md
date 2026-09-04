# Runbook — Etapa 2: Frigate NVR (Detecção de Pessoa + Gravação por Evento)

> **Pré-requisito:** a Etapa 1 (docs/RUNBOOK.md) deve estar completa — MediaMTX
> rodando, câmera transmitindo, e Tailscale configurado.

---

## Objetivo

Ao terminar esta etapa, o sistema deve:

1. Rodar o **Frigate NVR** em container Docker no Raspberry Pi.
2. **Detectar pessoas** automaticamente no campo de visão da câmera.
3. **Gravar apenas quando há movimento** (sem desperdiçar espaço).
4. **Reter gravações por 7 dias** e **eventos de pessoa por 14 dias**.
5. **Tirar snapshots** automáticos de cada evento detectado.
6. Disponibilizar uma **interface web** para visualizar ao vivo, eventos e
   snapshots.

---

## 1. Instalar Docker no Raspberry Pi

```bash
curl -fsSL https://get.docker.com | sh
```

Adicione o usuário `pi` ao grupo `docker` (para rodar sem `sudo`):

```bash
sudo usermod -aG docker pi
```

Faça logout e login novamente (ou reinicie) para o grupo ter efeito:

```bash
exit
# reconecte via SSH
```

**Validação:**

```bash
docker --version       # deve imprimir a versão do Docker
docker compose version # deve imprimir a versão do Compose
docker run hello-world # deve baixar e rodar o container de teste
```

---

## 2. Clonar ou Atualizar o Repositório

Se ainda não clonou o repositório no Pi:

```bash
cd ~
git clone https://github.com/lowgue/cta-camera.git
cd cta-camera
git checkout feat/frigate-nvr
```

Se já tem o repositório:

```bash
cd ~/cta-camera
git fetch origin
git checkout feat/frigate-nvr
git pull origin feat/frigate-nvr
```

---

## 3. Criar Diretórios de Armazenamento

As gravações e snapshots são salvos fora do container para persistência:

```bash
cd ~/cta-camera
mkdir -p storage/recordings storage/snapshots
```

> ⚠️ **IMPORTANTE — Armazenamento:**
> O SD card do Raspberry Pi tem espaço limitado e vida útil que se degrada
> com muitas escritas. Para uso sério, é **fortemente recomendado** montar
> um **HD/SSD externo via USB** e apontar `storage/` para ele.
>
> Exemplo com HD externo montado em `/mnt/hd_externo`:
> ```bash
> mkdir -p /mnt/hd_externo/frigate/recordings /mnt/hd_externo/frigate/snapshots
> ln -sf /mnt/hd_externo/frigate/recordings storage/recordings
> ln -sf /mnt/hd_externo/frigate/snapshots storage/snapshots
> ```

---

## 4. Configurar Credenciais

Edite o arquivo de configuração do Frigate para usar as mesmas credenciais
de leitura do MediaMTX:

```bash
nano config/frigate.yml
```

No bloco `cameras.lab.ffmpeg.inputs`, se você ativou a autenticação no `mediamtx.yml`, troque a URL para incluir as credenciais:

```yaml
- path: rtsp://usuario:SUA_SENHA_REAL@host.docker.internal:8554/lab
```

> **Nota:** O endereço `host.docker.internal` é usado em vez de `localhost` para que o container do Frigate acesse o serviço do MediaMTX rodando no sistema host. Se você **não** ativou senha no MediaMTX (que é o padrão), basta manter `rtsp://host.docker.internal:8554/lab`.

---

## 5. Iniciar o Frigate

```bash
cd ~/cta-camera
docker compose up -d
```

A primeira execução pode demorar **vários minutos** pois precisa baixar a
imagem do Frigate (~1 GB comprimida).

**Validação:**

```bash
# Verificar se o container está rodando
docker compose ps
# Esperado: "frigate" com status "Up" e "(healthy)"

# Verificar logs
docker compose logs -f frigate
# Esperado: logs de inicialização sem erros,
# mensagem de conexão ao stream RTSP
```

> 💡 Se o container reiniciar em loop, verifique os logs com
> `docker compose logs frigate --tail=50` para identificar o problema.

---

## 6. Acessar a Interface Web do Frigate

### Na rede local (Tailscale)

A interface web do Frigate fica na porta `5000`:

| Acesso | URL |
|---|---|
| **Rede local** | `http://<IP_DO_PI>:5000` |
| **Via Tailscale** | `http://<IP_TAILSCALE>:5000` |

### Acesso público via Tailscale Funnel (opcional)

Se quiser que o pessoal do lab acesse a interface do Frigate sem instalar
Tailscale:

```bash
sudo tailscale funnel 5000
```

> ⚠️ A interface web do Frigate **não tem autenticação própria**. Se expor
> via Funnel, qualquer pessoa com o link poderá acessar. Considere colocar
> um proxy reverso (ex: Caddy ou nginx) com autenticação na frente.

### O que você verá na interface

- **Live view** — vídeo ao vivo com as detecções em tempo real
- **Events** — lista de todos os eventos (pessoa detectada) com snapshots
- **Recordings** — gravações organizadas por data/hora
- **Config** — editor de configuração integrado

---

## 7. Testar a Detecção

Com a câmera ativa e o Frigate rodando:

1. Passe na frente da câmera.
2. Na interface web (`http://<IP>:5000`), vá na aba **Events**.
3. Você deve ver um evento com:
   - Snapshot da detecção
   - Tipo: `person`
   - Score de confiança (>70%)
   - Clip da gravação

**Validação via linha de comando:**

```bash
# Ver os últimos eventos detectados
curl -s http://localhost:5000/api/events?limit=5 | python3 -m json.tool

# Ver estatísticas do detector
curl -s http://localhost:5000/api/stats | python3 -m json.tool
```

---

## 8. Configurar Auto-start no Boot

O `docker compose` com `restart: unless-stopped` já garante que o Frigate
reinicie automaticamente se o Pi for reiniciado. Para confirmar:

```bash
sudo reboot
# Após o reboot, reconecte via SSH e verifique:
docker compose -f ~/cta-camera/docker-compose.yml ps
```

O container `frigate` deve estar com status `Up` e `(healthy)`.

---

## 9. Ajuste Fino (Pós-instalação)

Após confirmar que tudo funciona, ajuste conforme necessidade:

### Sensibilidade da detecção

Em `config/frigate.yml`, no bloco `objects.filters.person`:

```yaml
min_score: 0.5       # baixar = mais sensível (mais falsos positivos)
threshold: 0.7       # baixar = confirma detecções com menos certeza
min_area: 5000       # baixar = detecta pessoas mais distantes
```

### Retenção de gravações

Em `config/frigate.yml`, no bloco `record.retain`:

```yaml
days: 7              # aumente se tiver espaço em disco
```

### Definir zonas de interesse

Acesse a interface web do Frigate, observe o campo de visão da câmera e
defina zonas em `config/frigate.yml` (seção `zones`). Isso permite:

- Alertar apenas quando alguém entra em uma área específica
- Ignorar áreas com muito tráfego irrelevante

### Após qualquer alteração na configuração

```bash
cd ~/cta-camera
docker compose restart frigate
```

---

## 10. Monitoramento e Manutenção

### Verificar uso de disco

```bash
du -sh storage/recordings/ storage/snapshots/
df -h /  # espaço total do SD card / HD externo
```

### Ver logs do Frigate

```bash
docker compose logs -f frigate --tail=100
```

### Atualizar o Frigate

```bash
cd ~/cta-camera
docker compose pull frigate
docker compose up -d frigate
```

---

## 11. Checklist de Verificação

```bash
# 1. Container rodando e saudável
docker compose ps
# Esperado: frigate "Up (healthy)"

# 2. Stream RTSP sendo consumido
docker compose logs frigate 2>&1 | grep -i "lab"
# Esperado: mensagem de conexão ao stream

# 3. Detecção funcionando
curl -s http://localhost:5000/api/stats | python3 -m json.tool
# Esperado: "detection_fps" > 0

# 4. Gravações sendo salvas
ls -la storage/recordings/
# Esperado: diretórios com arquivos .mp4

# 5. Interface web acessível
curl -s -o /dev/null -w "%{http_code}" http://localhost:5000
# Esperado: 200
```

---

## 12. Próxima Etapa

Com a detecção de pessoa e gravação por evento funcionando, os próximos
passos possíveis são:

- **Reconhecimento facial** — identificar quem é a pessoa detectada
- **Mapeamento de permanência** — quanto tempo cada pessoa ficou no lab
- **Alertas** — notificações via Telegram/email quando alguém é detectado
  fora do horário de expediente
- **Integração MQTT + Home Assistant** — automação de ações baseadas em
  presença (ligar luzes, acionar alarme, etc.)

---

## Troubleshooting

### Container não inicia

```bash
# Ver logs completos
docker compose logs frigate --tail=100

# Problemas comuns:
# - Memória insuficiente: aumente shm_size no docker-compose.yml
# - Permissão negada: verifique se o usuário está no grupo docker
# - Imagem não encontrada: execute "docker compose pull"
```

### Frigate não conecta ao stream RTSP

```bash
# 1. Verificar se o MediaMTX está rodando
sudo systemctl status mediamtx

# 2. Testar o stream RTSP manualmente
ffplay rtsp://usuario:SENHA@localhost:8554/lab

# 3. Verificar se as credenciais no frigate.yml batem com mediamtx.yml
```

### Detecção muito lenta (< 2 FPS)

```bash
# Verificar uso de CPU
htop

# Soluções:
# - Reduza detect.fps de 5 para 3 em frigate.yml
# - Reduza a resolução de detecção para 640x480
# - Considere adquirir um Google Coral USB Accelerator
```

### Espaço em disco esgotando

```bash
# Verificar espaço
df -h

# Reduzir retenção no frigate.yml:
# record.retain.days: 3  (era 7)
# events.retain.default: 7  (era 14)

# Limpar gravações antigas manualmente:
# find storage/recordings/ -mtime +3 -delete
```

---

*Última atualização: setembro 2026*
