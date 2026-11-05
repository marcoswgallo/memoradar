# MemoRadar: documento de design

App de barra de menu para macOS que mostra o que está consumindo memória, com foco em quem usa o Claude Code, e permite fechar o que ficou esquecido.

"MemoRadar" é um nome provisório (decisão do autor do documento, pode mudar).

## 1. Por que existe

O Claude Code roda dentro do VS Code e no terminal, e cada sessão sobe os próprios MCPs. Isso se acumula sem que a pessoa perceba.

O caso que originou o projeto: um Mac com 18 GB de RAM chegou a ter quase toda a memória ocupada, cerca de 5,7 GB de swap e 7 GB de memória comprimida. A análise manual encontrou:

- quatro janelas do VS Code abertas, uma delas havia 3,5 dias, sem que o dono soubesse;
- oito sessões do Claude Code dentro dessas janelas;
- nove cópias de cada um de dois MCPs globais, somando cerca de 3,5 GB.

Fechar o que não estava em uso reduziu o swap para 1,8 GB e a memória comprimida para 2,7 GB.

O Monitor de Atividade não mostra isso: lista dezenas de processos "Code Helper" sem dizer a qual projeto pertencem. O MemoRadar responde em segundos: **o que está gastando memória, o que ficou esquecido e o que posso fechar**.

## 2. Para quem

Usuários do Claude Code em Mac, técnicos ou não. Os textos do app devem ser diretos e evitar jargão.

## 3. Objetivos

1. Mostrar o estado geral da memória e a pressão atual.
2. Mostrar o ranking dos apps que mais consomem, com detalhe ao expandir.
3. Mostrar, por projeto no VS Code: memória, número de sessões do Claude, tempo aberto e tempo parado.
4. Mostrar os MCPs abertos: quantas cópias, de qual servidor e quanto consomem.
5. Identificar o que ficou esquecido e avisar sozinho.
6. Permitir fechar pelo próprio app, sempre com confirmação.

## 4. Fora do escopo na primeira versão

- Windows e Linux.
- Detalhe por projeto em outros editores, como Cursor ou Zed. Eles aparecem no ranking como qualquer outro app.
- Detalhe por aba do Chrome.
- Histórico, gráficos ao longo do tempo e detecção de vazamento de memória.
- Alterar a configuração de MCPs. O app mostra e fecha processos, mas nunca edita arquivos de configuração.
- Atualização automática do app.

## 5. O que o app nunca deve fazer

- Fechar qualquer coisa sem confirmação da pessoa.
- Descartar arquivo sem salvar ou contornar o aviso de salvar do próprio app.
- Oferecer fechar processos do sistema, como WindowServer.
- Enviar dados para fora do Mac. Sem conta, telemetria nem conexão de rede de qualquer tipo.
- Ler conversas do Claude Code (`~/.claude/projects/*.jsonl`), arquivos `.key` de `~/.claude/sessions/` ou arquivos de configuração como `~/.claude.json`, que podem conter dados sensíveis.
- Mostrar um estado que não conseguiu confirmar. Na dúvida, mostra "estado desconhecido".
- Prometer "limpar a memória". Nada de purge nem truques; o app só ajuda a fechar o que a pessoa escolher.
- Pesar na própria máquina que tenta aliviar. Meta: menos de 50 MB de footprint e CPU desprezível em repouso (meta do autor do documento).

## 6. Como funciona

### 6.1 Ícone na barra de menu

Sempre visível, perto do relógio. Muda de cor conforme o estado, nesta ordem de prioridade:

| Estado | Condição | Ícone |
|---|---|---|
| Crítico | Pressão crítica | Vermelho |
| Atenção | Pressão em aviso, ou há algo esquecido | Amarelo |
| Normal | Nenhum dos anteriores | Cor padrão da barra |

A cor não pode ser o único sinal: nos estados Atenção e Crítico o desenho do ícone também muda, por exemplo com um ponto ou badge, para quem não distingue cores.

### 6.2 Painel

Abre ao clicar no ícone. Layout aprovado (opção "Ranking na barra de menu"):

```
Memória 75%                 [Pressão normal]
[=================       ]
▾ VS Code                            3,5 GB
    projeto-a    6 min · 2 sessões  [Fechar]
    projeto-b    Parado há 5 h      [Fechar]   <- destaque de esquecido
▸ Google Chrome                      2,3 GB
▸ Claude Desktop                     1,1 GB
▸ WhatsApp                           0,6 GB
▸ MCPs abertos                 6 · 0,2 GB
```

- **Topo:** porcentagem de memória usada, barra e nível de pressão.
- **Ranking:** apps ordenados por memória. Cada processo conta em uma única linha do ranking (ver 7.2).
- **Expandir app:** mostra os processos ou, no VS Code, os projetos.
- **Grupo "MCPs abertos":** por servidor, número de cópias e memória. Expandindo, mostra a qual sessão cada cópia pertence.
- **Sessões do Claude no terminal:** aparecem como grupo "Claude Code no terminal", por pasta do projeto.
- **Sistema:** uma linha com a memória reservada pelo sistema (Wired), sem botão de fechar. O macOS não informa a memória de processos de outros usuários sem privilégio de administrador (negado para 235 processos, incluindo WindowServer), e o app não pede esse privilégio nem estima o valor.
- **Serviços do macOS:** processos do próprio usuário em `/System`, `/usr`, `/sbin` e `/bin`, em uma linha, sem botão de fechar.
- **Outros:** processos do usuário sem app e fora de sessões do Claude, como servidores de desenvolvimento, Docker ou Ollama. Aparecem com a memória, mas sem botão de fechar na primeira versão.
- **Rodapé:** Configurações e Sair.

### 6.3 O que significa "esquecido"

Um projeto é identificado pela pasta (`cwd`) da sessão. Ele é marcado como esquecido quando **todas** as sessões do Claude naquela pasta, no VS Code ou no terminal, estão paradas há pelo menos **4 horas**. O limite é ajustável nas configurações.

- O tempo parado vem do campo `statusUpdatedAt` do arquivo de sessão.
- Projeto sem sessão do Claude: mostra só o tempo aberto e nunca é chamado de esquecido, porque falta dado para afirmar.
- Sessão com estado desconhecido: nunca é marcada como esquecida.
- Apenas tempo aberto nunca marca algo como esquecido: um projeto pode estar aberto há dias e em uso.

### 6.4 Avisos

Quando um projeto vira esquecido, acontecem três coisas: notificação do macOS, destaque no painel e mudança de cor do ícone.

- Uma notificação por pasta de projeto a cada vez que ela vira esquecida. Só avisa de novo se o projeto voltar a ter atividade e depois ficar parado outra vez.
- Notificações podem ser desligadas nas configurações. O destaque e a cor continuam.
- A API oficial (`UserNotifications`) recusa apps com assinatura ad-hoc (`UNErrorDomain Code=1`), então o aviso usa `osascript` e aparece como Editor de Script. O nome da pasta só entra como argumento, nunca no texto do script.
- Se o aviso não aparecer, o app continua funcionando normalmente.

### 6.5 Fechar

Todo fechamento passa por uma confirmação que diz o que será fechado e a estimativa de memória liberada ("cerca de X GB").

| Situação da sessão | Confirmação |
|---|---|
| Claude trabalhando (`busy`) | Alerta forte: "O Claude Code está rodando em projeto-a. Fechar mesmo assim?" |
| Estado desconhecido | Mesmo alerta forte |
| Claude parado (`idle`) ou sem sessão | Confirmação simples |

O que "fechar" faz em cada caso:

| Item | Ação |
|---|---|
| App comum | Pedido normal de encerramento (`NSRunningApplication.terminate()`), sem `forceTerminate`. O app pode pedir para salvar |
| Janela de projeto do VS Code | Aciona o botão de fechar daquela janela via API de Acessibilidade. O aviso de arquivo sem salvar continua sendo o do VS Code |
| Sessão do Claude no terminal | `SIGTERM` no processo da sessão |
| MCP | `SIGTERM` nos processos daquele servidor. A confirmação avisa que a sessão fica sem essas ferramentas e que ele volta em sessões novas, se continuar configurado |

Regras adicionais:

- **MCP:** a linha do servidor tem "Fechar todos", e cada cópia expandida tem o próprio "Fechar". Se as sessões afetadas estiverem em estados diferentes, vale o alerta mais forte, listando as que estão trabalhando.
- **Sessão do Claude no terminal integrado do VS Code:** tratada como sessão de terminal, porque não descende do extension host. Se uma janela do VS Code tiver a mesma pasta de uma sessão assim que esteja trabalhando ou em estado desconhecido, fechar a janela usa o alerta forte. Essa confirmação nunca fica mais fraca por falta de associação. Esse comportamento é confirmado no protótipo.
- **Mesma pasta em dois lugares:** o projeto aparece como esquecido uma vez, mas fechar age separadamente na janela e nas sessões de terminal, cada um com a própria confirmação.
- Antes de agir, o app confere se o processo ainda é o mesmo (PID e horário de início), para não atingir outro processo que reaproveitou o PID.
- Só oferece fechar processos do usuário atual. Processos do sistema e o próprio Finder não têm botão.
- Sem a permissão de Acessibilidade, o app continua mostrando tudo. Ao tentar fechar uma janela do VS Code, explica a permissão e abre o ajuste certo. Nunca recorre a matar processos como alternativa.
- Se a janela não puder ser identificada com segurança, mostra o motivo e não fecha nada.
- Se a ação falhar, ou o item continuar aberto depois de alguns segundos, o painel informa em vez de fingir que deu certo. Isso cobre o caso do VS Code aguardando resposta sobre arquivo sem salvar.

### 6.6 Configurações

Limite de "esquecido" (padrão de 4 horas), notificações ligadas ou desligadas e abrir ao iniciar sessão no Mac (desligado por padrão).

## 7. De onde vêm os dados

Verificado em um Mac com macOS 27.2, Apple M3 Pro, Claude Code 2.1.318 e VS Code.

### 7.1 Sistema

- Memória usada: Apps + Wired + Comprimida, a partir de `host_statistics64`. Medido assim, deu 75% enquanto o usuário via 72% em outra ferramenta, e essa diferença é aceitável.
- Pressão: `sysctl kern.memorystatus_vm_pressure_level` (1 = normal, 2 = aviso, 4 = crítico).
- Swap: `sysctl vm.swapusage`.

### 7.2 Processos

- Memória por processo: `ri_phys_footprint` de `proc_pid_rusage`. É o mesmo número da coluna MEM do `top`. Não usar RSS, que subestimou muito no caso real (VS Code: 2,5 GB em RSS contra 10,4 GB em footprint).
- Árvore de processos, argumentos e pasta atual: `libproc` e `sysctl KERN_PROCARGS2`.
- Agrupamento em app: pelo caminho `.app` do executável. Processos dentro de `Visual Studio Code.app` e de `~/.vscode/extensions/` contam como VS Code.
- Só processos do usuário atual são medidos e listados, porque os demais exigem privilégio de administrador.

**Regra de contagem:** no ranking, cada processo conta em uma linha só. A ordem de prioridade é: (1) MCP confirmado, na linha "MCPs abertos"; (2) sessão do Claude dentro do VS Code e demais processos do VS Code, na linha do VS Code; (3) sessão do Claude no terminal e seus descendentes, em "Claude Code no terminal"; (4) demais apps pelo `.app`; (5) o restante em "Outros". A linha de um projeto mostra a memória dele sem MCPs, com a indicação "+ X de MCPs" quando houver. A estimativa de memória liberada ao fechar soma tudo o que será encerrado, incluindo os MCPs.

A soma de footprints passa do total de RAM quando há compressão e swap (chegou a 27 GB em 18 GB). A interface não deve apresentar essa soma como memória física usada.

### 7.3 Sessões do Claude Code

Arquivo `~/.claude/sessions/<pid>.json`, com os campos observados: `pid`, `sessionId`, `cwd`, `startedAt`, `procStart`, `version`, `kind`, `entrypoint` (`cli`, `claude-vscode`), `status` (`idle`, `busy`), `updatedAt` e `statusUpdatedAt`. Datas em milissegundos.

**Risco:** é um formato interno do Claude Code, sem garantia de estabilidade.

- Ler só `<pid>.json`, nunca `.key`.
- Ignorar arquivos cujo PID não esteja vivo ou cujo processo não corresponda.
- Campo ausente ou valor desconhecido resulta em "estado desconhecido", nunca em erro. Outros valores de `status` podem existir, e todo valor que não for `idle` conta como desconhecido, exceto `busy`.
- Testar com arquivos de exemplo que cubram formato antigo, campo faltando e JSON inválido.

### 7.4 Projetos no VS Code

Uma janela corresponde a um processo `Code Helper (Plugin)` com `--type=utility`, o extension host. As sessões do Claude são filhas dele, então a pasta (`cwd`) da sessão identifica o projeto da janela.

- Memória do projeto: árvore do extension host + janela correspondente (`Code Helper (Renderer)`) quando a associação for confiável.
- Processos que não puderem ser associados a uma janela ficam em "VS Code (geral)". Nunca são atribuídos a um projeto por palpite.
- Janela sem sessão do Claude: o nome do projeto vem do título da janela via Acessibilidade. Sem a permissão, aparece como "Janela do VS Code".

**Ponto a validar primeiro:** a associação entre extension host, renderer e janela da Acessibilidade não foi testada. Validar com um protótipo descartável é o primeiro passo da construção. Se não houver associação segura, o projeto mostra a memória que puder confirmar, e fechar exige identificar a janela pelo título.

### 7.5 MCPs

Identificados pelo comportamento, e não por lista de nomes nem por leitura de configuração, para funcionar com qualquer servidor. Um processo é MCP confirmado quando: é **filho direto** de uma sessão do Claude, não é um shell, e tem a entrada padrão ligada a um pipe ou socket, que é como servidores locais de MCP conversam. Comandos da ferramenta Bash passam por um shell (a confirmar no protótipo), então seus processos não entram nessa regra. O nome é extraído dos argumentos; sem nome claro, mostra o executável. Formatos reais observados, todos filhos diretos da sessão:

- `npm exec chrome-devtools-mcp@latest --no-usage-statistics`, com filho `chrome-devtools-mcp`
- `npm exec rea-agents@4.0.1 mcp`, com filho `node .../.bin/rea mcp`
- `uv tool uvx mcp-obsidian`, com filho `python .../mcp-obsidian`

Wrapper e filho contam como uma única cópia. Qualquer outro descendente de sessão aparece em "Outros processos da sessão", contado junto com a sessão e sem botão de fechar: matar um servidor de desenvolvimento por engano é pior do que deixar um MCP sem classificar. Plugins e conectores remotos não geram processo local e não aparecem.

## 8. Construção e distribuição

Decisões do autor do documento, que o dono pode rever:

- **Stack:** Swift + SwiftUI (`MenuBarExtra`), via Swift Package Manager, sem dependências externas. Nativo, para o app gastar pouca memória.
- **Sem Xcode:** o Mac tem só as Command Line Tools (Swift 6.4.2). Verificado: `SwiftUI`, `MenuBarExtra`, `@Observable`, `UserNotifications` e `ServiceManagement` passam na checagem de tipos sem o Xcode. Compilar e abrir o `.app` de verdade é parte do protótipo inicial.
- **Empacotamento:** um script gera o `.app` (`Info.plist` com `LSUIElement`) e assina ad-hoc.
- **macOS mínimo:** 14.
- **Distribuição:** `.zip` no GitHub Releases, gratuito. Sem conta paga da Apple, o app não é notarizado, e o macOS mostra um aviso na primeira abertura. O README explica como abrir.
- **Permissões:** Acessibilidade só para fechar janelas do VS Code e, se concedida, para ler os títulos delas. A assinatura ad-hoc pode exigir conceder a Acessibilidade de novo após atualizar o app, e o README deve avisar. Confirmar no protótipo.
- **Atualização dos dados:** a cada 10 segundos com o painel fechado e a cada 3 segundos com ele aberto (padrão do autor do documento, ajustar se a meta de consumo não for cumprida).
- **Idioma:** interface e README em português do Brasil, com README também em inglês, por ser um projeto público. Interface em inglês fica para depois.
- **Licença:** MIT.

## 9. Repositório

Decisões do dono:

- Repositório **público e gratuito** na conta `marcoswgallo` do GitHub.

Decisões do autor do documento:

- Nome do repositório: `memoradar` (livre na conta em 2026-11-04).
- Este documento fica em `docs/design.md`.
- Nenhum nome de projeto real ou dado pessoal e de trabalho do dono no código, nos testes, nas capturas de tela ou no README. Exemplos usam nomes fictícios.
- O README pode citar o Claude Code como o produto que o app monitora. Deve deixar claro que o projeto é independente, sem vínculo com a Anthropic.

## 10. Como saber que deu certo

- Abrindo o painel, dá para ver em segundos o que mais consome, sem interpretar uma lista de "Code Helper".
- Com um projeto parado há mais de 4 horas, chegam notificação, destaque e ícone amarelo.
- Com uma sessão trabalhando, fechar mostra o alerta forte.
- Fechar uma janela do VS Code com arquivo sem salvar exibe o aviso do próprio VS Code, e nada se perde.
- Com o Monitor de Atividade como referência, os números dos processos do próprio usuário coincidem com a coluna de memória dele, dentro de uma margem pequena.
- Nenhuma soma de linhas conta o mesmo processo duas vezes no ranking.
- Com arquivo de sessão inválido ou em formato novo, o app mostra "estado desconhecido" e não trava.
- O app cumpre a meta de consumo e não faz nenhuma conexão de rede.

## 11. Deixado para quem for construir

- Organização do código e estratégia de testes.
- Desenho exato do ícone e dos textos, respeitando as regras acima.
- Como isolar a lógica pura, como agrupamento, regra de esquecido e leitura de sessão, para testá-la sem processos reais.
