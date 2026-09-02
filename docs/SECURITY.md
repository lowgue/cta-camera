# Segurança — Sistema de Vigia do Laboratório

## Gestão de Senhas

- **Troque TODAS as senhas de exemplo** (`TROCAR_SENHA_FORTE`) nos seguintes
  arquivos antes de colocar em produção:
  - `~/mediamtx.yml` — campos `publishPass` e `readPass`
  - `~/start_camera.sh` — URL RTSP com senha de publicação

- Use senhas fortes e únicas (mínimo 16 caracteres, com letras, números e
  símbolos).

- **Nunca commite senhas reais no repositório.** Os arquivos no repo contêm
  apenas placeholders (`TROCAR_SENHA_FORTE`).

---

## Isolamento de Rede via Tailscale

O sistema foi projetado para **nunca ser exposto publicamente na internet**.

### O que o Tailscale garante

- O Raspberry Pi recebe um IP privado fixo (`100.x.x.x`) acessível apenas
  por dispositivos autorizados na mesma rede Tailscale (Tailnet).
- **Não é necessário** abrir portas no roteador, usar DDNS, ngrok ou
  Cloudflare Tunnel.
- Todo o tráfego entre dispositivos é criptografado com WireGuard.

### Boas práticas

1. **Não abra portas no roteador** para as portas do MediaMTX (8554, 8888,
   8889).
2. **Use ACLs do Tailscale** para restringir quais dispositivos podem acessar
   o Pi dentro da Tailnet.
3. **Revise periodicamente** os dispositivos autorizados no painel do
   Tailscale Admin.
4. **Ative MFA** na conta Tailscale para proteção adicional.

---

## Conformidade LGPD

> **Este sistema envolve captação de imagem de pessoas em ambiente de
> trabalho.** Ao avançar para reconhecimento facial, é necessário observar a
> Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018).

### Recomendações

1. **Aviso visível:** coloque um aviso na porta do laboratório informando
   sobre a captação de imagens (ex: "Este ambiente é monitorado por câmeras
   de segurança").

2. **Dados biométricos são sensíveis:** reconhecimento facial trata dados
   biométricos, que são classificados como dados pessoais sensíveis pela
   LGPD (Art. 5º, II). O tratamento requer:
   - Base legal adequada (Art. 11)
   - Consentimento específico ou justificativa de segurança pública

3. **Registro de operações:** mantenha registro das operações de tratamento
   de dados pessoais, incluindo:
   - Finalidade da captação
   - Período de retenção das gravações
   - Quem tem acesso às imagens
   - Medidas de segurança adotadas

4. **Minimização de dados:** capture e armazene apenas o que for estritamente
   necessário para a finalidade declarada.

5. **Retenção limitada:** defina um período máximo de retenção para as
   gravações e implemente exclusão automática após esse período.

6. **Acesso controlado:** restrinja o acesso às gravações e logs apenas a
   pessoas autorizadas e com justificativa clara.

---

## Hardening Adicional (Recomendado)

Para ambientes de produção, considere também:

- [ ] Manter o Raspberry Pi OS sempre atualizado (`sudo apt full-upgrade`)
- [ ] Desabilitar login SSH por senha (usar apenas chaves SSH)
- [ ] Configurar `fail2ban` para proteção contra brute force
- [ ] Monitorar logs do sistema com `journalctl` regularmente
- [ ] Configurar alertas (email/Telegram) para quando serviços cairem
- [ ] Fazer backup periódico da configuração

---

*Última atualização: setembro 2026*
