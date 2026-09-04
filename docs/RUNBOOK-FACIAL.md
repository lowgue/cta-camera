# Runbook — Etapa 3: Reconhecimento Facial (Double-Take + DeepStack)

> **Pré-requisito:** a Etapa 2 (docs/RUNBOOK-FRIGATE.md) deve estar completa e com a detecção de pessoas (`person`) rodando corretamente no Frigate.

---

## Objetivo

Nesta etapa o sistema ganha a capacidade de **reconhecer quem é a pessoa** detectada pela câmera. Para isso adicionamos 3 componentes rodando localmente no Raspberry Pi:

1. **Mosquitto**: Mensageria rápida. Quando o Frigate vê uma pessoa, ele avisa o Mosquitto.
2. **Double-Take**: Escuta o Mosquitto, baixa a foto da pessoa do Frigate e manda para o motor de Inteligência Artificial.
3. **DeepStack (ARM64)**: O motor de IA. Analisa a foto, descobre quem é a pessoa, e devolve o nome.

---

## 1. Atualizar o Sistema (Docker Compose)

Você deve estar na pasta raiz do repositório (`~/cta-camera`).

```bash
cd ~/cta-camera
```

Se tudo foi atualizado corretamente nos arquivos de configuração, basta mandar o Docker iniciar os novos serviços:

```bash
docker compose up -d
```

> **Nota de Performance:** A imagem do DeepStack tem cerca de 2GB. O primeiro `up -d` vai demorar vários minutos baixando a imagem. Deixe rodar.

---

## 2. Validar os Serviços

Verifique se todos os serviços subiram sem erro:

```bash
docker compose ps
```

Você deve ver:
- `frigate` (Up)
- `mosquitto` (Up)
- `deepstack` (Up)
- `double-take` (Up)

---

## 3. Acessar a Interface do Double-Take

O Double-Take possui uma interface própria na porta **3000** onde você faz o "treinamento" dos rostos.

| Acesso | URL |
|---|---|
| **Rede local** | `http://<IP_DO_PI>:3000` |
| **Via Tailscale** | `http://<IP_TAILSCALE>:3000` |

Na página inicial, vá até **Matches / Unmatched**.

---

## 4. Como "Treinar" o Sistema (Ensinar Rostos)

1. Passe na frente da câmera (sem usar óculos de sol/máscara na primeira vez).
2. O Frigate vai detectar você como `person`.
3. Na interface do Double-Take, vá na aba **Unmatched** (Desconhecidos).
4. Você verá a sua foto. Clique nela.
5. Digite o seu **Nome** (ex: `Roma`) e salve.
6. A partir deste momento, o Double-Take usará essa foto como base. 
7. **Dica:** Treine umas 3 a 5 fotos suas (com luz diferente, de chapéu, de lado) para a IA ficar robusta. 

---

## 5. Visualizando no Frigate

Quando o sistema já sabe quem você é:

1. Acesse o Frigate (`http://<IP>:5000`).
2. Na aba **Events**, os eventos que antes eram chamados apenas de `person` agora terão uma etiqueta adicional com o seu **nome**!

---

## Troubleshooting (Problemas Comuns)

### O Double-Take não mostra nenhuma imagem

- O Frigate pode não estar conectando no Mosquitto. Olhe os logs do Frigate:
  `docker compose logs frigate --tail=50`
- Verifique se a opção `mqtt` está com `enabled: true` no arquivo `config/frigate.yml`.

### Reconhecimento muito lento (Delay alto)

O DeepStack não usa aceleração de GPU no Raspberry Pi, ele roda via CPU.
O normal é demorar cerca de 1 a 2 segundos para processar um rosto num Pi 4 (4GB). 
Se estiver travando demais:
- Reduza a `resolução` no arquivo do frigate (`detect: width: 640`).
- No `double-take.yml`, aumente o `timeout` se estiver dando erro de timeout do deepstack.

---

*Última atualização: setembro 2026*
