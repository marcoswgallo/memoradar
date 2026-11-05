# MemoRadar

*[Read in English](README.en.md)*

Um app de barra de menu para macOS que mostra o que está gastando memória, com foco em quem usa o **Claude Code**: quais projetos estão abertos, há quanto tempo o Claude está parado em cada um e quantas cópias de cada MCP estão rodando.

O Monitor de Atividade lista dezenas de processos `Code Helper` sem dizer de qual projeto eles são. O MemoRadar responde em segundos: **o que está gastando memória, o que ficou esquecido e o que dá para fechar**.

> Projeto independente, sem nenhum vínculo com a Anthropic ou com a Microsoft.

## O que ele mostra

- **Memória e pressão:** porcentagem usada e o nível de pressão informado pelo macOS.
- **Ranking de apps:** do que mais gasta para o que menos gasta, somando todos os processos de cada app.
- **Projetos no VS Code:** memória, número de sessões do Claude, tempo aberto e tempo parado.
- **Claude Code no terminal:** sessões por pasta.
- **MCPs abertos:** quantas cópias de cada servidor, quanto gastam e a qual sessão pertencem.

## O que conta como esquecido

Um projeto parece esquecido quando **todas** as sessões do Claude naquela pasta estão paradas há pelo menos 4 horas. Esse limite pode ser mudado nas configurações.

Quando isso acontece, o MemoRadar manda uma notificação, destaca o projeto no painel e deixa o ícone amarelo. O ícone fica vermelho se a pressão de memória ficar crítica.

## Fechar pelo app

Nada fecha sem confirmação. Se o Claude estiver trabalhando, ou se o estado da sessão for desconhecido, o alerta é mais forte.

| O que você fecha | O que o app faz |
|---|---|
| App comum | Pede para fechar normalmente, e o app pode perguntar se quer salvar |
| Janela do VS Code | Aciona o botão de fechar da janela, e o aviso de arquivo sem salvar continua sendo o do VS Code |
| Sessão no terminal | Envia `SIGTERM` |
| MCP | Envia `SIGTERM`. Ele volta em sessões novas, se continuar configurado |

Processos do sistema, servidores de desenvolvimento, Docker e afins aparecem na lista, mas não têm botão de fechar.

## Instalação

1. Baixe o `.dmg` mais recente na página de [Releases](https://github.com/marcoswgallo/memoradar/releases).
2. Abra o arquivo e arraste o **MemoRadar** para a pasta **Aplicativos**.
3. Na primeira vez, o macOS avisa que não consegue verificar o desenvolvedor, porque o app é gratuito e não passa pela notarização paga da Apple. Abra **Ajustes do Sistema > Privacidade e Segurança**, role até o aviso sobre o MemoRadar e clique em **Abrir Mesmo Assim**.

Requer macOS 14 ou mais recente.

## Permissões

- **Acessibilidade (opcional):** só para ler os títulos das janelas do VS Code e acionar o botão de fechar. Sem ela, todo o resto funciona. Pode ser preciso conceder de novo depois de atualizar o app.
- **Notificações (opcional):** a API oficial do macOS recusa apps sem certificado pago da Apple, então o aviso é enviado pelo AppleScript. Ele aparece com o nome e o ícone do **Editor de Script**, com o título começando em "MemoRadar:", e clicar nele pode abrir esse programa. Se não aparecer, permita as notificações do Editor de Script em Ajustes do Sistema > Notificações. O destaque no painel e a cor do ícone funcionam sem isso.

## Privacidade

O MemoRadar **não faz nenhuma conexão de rede**. Não tem conta, telemetria nem atualização automática.

**O que ele lê:** informações dos seus processos, via APIs do macOS, e os arquivos `~/.claude/sessions/<pid>.json`, que trazem o estado de cada sessão.

**O que ele nunca lê:** suas conversas (`~/.claude/projects`), os arquivos `.key` de sessão e arquivos de configuração como `~/.claude.json`.

## Limitações

- O estado das sessões vem de arquivos internos do Claude Code, que podem mudar em alguma atualização. Se isso acontecer, o app mostra "estado desconhecido" em vez de adivinhar, e usa o alerta forte.
- O macOS não informa o consumo de processos de outros usuários sem privilégio de administrador, como o WindowServer, e o app não pede esse privilégio. Por isso, ele mostra a memória reservada pelo sistema como um único número.
- A memória da janela em si nem sempre pode ser ligada a um projeto, e fica em "VS Code (geral)". A estimativa ao fechar uma janela pode ser menor que o real.
- Janelas sem sessão do Claude aparecem sem nome e não podem ser fechadas pelo app, porque não há como identificá-las com segurança.
- Janelas do VS Code em outro espaço de trabalho (Space) podem não ser encontradas. Nesse caso, nada é fechado.

## Compilar

Precisa só das Command Line Tools, sem o Xcode:

```bash
scripts/test.sh          # roda os testes
scripts/package-app.sh   # gera dist/MemoRadar.app
scripts/package-dmg.sh   # gera o .dmg em dist/
```

Sem o Xcode, o plugin da macro `@State` não está disponível, então o estado da interface fica em objetos `@Observable`. `scripts/test.sh` também contorna uma falha intermitente do plugin de testes nas Command Line Tools.

## Licença

[MIT](LICENSE)
