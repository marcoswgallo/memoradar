- Nova seção **Skills**: por plugin, quantas Skills estão sem uso registrado, a data do último uso e o comando para desativar. O app só mostra, e quem desativa é você.
- **Mudança na privacidade:** para isso, o app passa a abrir `~/.claude.json` e `~/.claude/settings.json` ao abrir o painel, usando só os campos `skillUsage` e `enabledPlugins` e descartando o resto. Conversas e o conteúdo das Skills continuam fora. O README traz os detalhes.

**Para atualizar**, feche o MemoRadar em Sair, abra o `.dmg` e arraste o app para a pasta Aplicativos, substituindo o anterior. Na primeira abertura, o macOS pode mostrar o aviso de novo, e talvez seja preciso conceder a permissão de Acessibilidade outra vez.
