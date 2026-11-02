# Evidências e roteiro de validação

## Resultado desta entrega

- Ambiente disponível: Linux, Python 3; sem Swift, Xcode ou SDK iOS.
- Testes Python das ferramentas: **2 testes passaram** em 2026-11-02, usando fixtures sintéticas (nenhum APK/IPA real).
- Fontes Swift, compilação Xcode, renderização AVFoundation, testes macOS, instalação ESign e execução iOS: **não executados neste ambiente**.
- APK, telas, contagens e licenças de recursos: **não inspecionados; arquivo ausente**.
- iOS 17.0 é o alvo mínimo configurado; não é comprovação de compatibilidade em dispositivos.

## Verificações automáticas preparadas

`python3 -m unittest discover -s Tests -p 'test_*.py'` usa fixtures sintéticas para verificar estrutura ZIP/IPA, permissões executáveis, exclusão de assinaturas/perfis na cópia, rejeição de builds de simulador, inventário APK e bloqueio de reutilização sem licença. O teste não prova que um binário seja instalável.

`bash Scripts/test_media.sh`, em macOS com Xcode, compila as mesmas classes de timeline, composição e renderização usadas pelo app. Verifica divisão com início não zero, IDs, reordenação, durações inválidas e serialização. Gera vídeos sintéticos sem áudio, compõe trechos com filtros, exporta em paisagem/retrato e verifica duração, dimensões e pixels decodificados do primeiro quadro em preto e branco. A renderização de sépia passa pela exportação, mas o teste não compara sua cor. Não testa orientação visual de conteúdo assimétrico, áudio, preview SwiftUI ou execução iOS.

O workflow também compila o app completo para iOS físico. Testes macOS e compilação não comprovam que o ESign possa instalar a assinatura escolhida.

## Teste obrigatório em iPhone/iPad

Registrar modelo, versão iOS, Xcode do workflow, commit, tipo/prazo do perfil (sem segredos), versão ESign e resultado de cada passo:

1. Assinar, instalar, abrir e girar o dispositivo. Conferir layout em retrato/paisagem, tela dividida do iPad e texto ampliado.
2. Importar MOV e MP4 locais, um arquivo via iCloud e um inválido. Verificar erro compreensível, lote anterior preservado e ausência de alteração dos originais.
3. Usar vídeo com áudio, sem áudio e áudio mais curto que o vídeo. Verificar sincronismo após cortes e junções, inclusive na saída exportada.
4. Usar vídeos horizontal, vertical, rotacionado e espelhado com marcadores nos quatro cantos. Conferir ordem dos cantos, barras, escala e imagem da prévia versus exportação, inclusive misturando orientações no mesmo projeto.
5. Ajustar entrada/saída; dividir no meio e tentar dividir junto às bordas. Remover e reordenar trechos. Confirmar durações e conteúdo dos quadros nas junções.
6. Aplicar cada efeito, exportar e comparar quadro equivalente com a prévia. Repetir após mudar o primeiro clipe (o canvas pode mudar).
7. Exportar e salvar no app Arquivos, reabrir o MP4 e conferir duração, resolução, áudio e fim sem quadros pretos inesperados. Compartilhar no iPad deve abrir a apresentação do sistema sem falhas.
8. Encerrar/reabrir o app e confirmar mídia/efeitos/cortes. Testar mídia ausente, pouco armazenamento, arquivos extensos e alternância entre apps durante importação/exportação. Essas situações ainda não têm robustez comprovada.

Aprovação do MVP depende de uma build bem-sucedida e desse roteiro nos dispositivos de destino. Falhas devem ser corrigidas antes de declarar a versão funcional/compatível.
