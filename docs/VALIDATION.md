# Evidências e roteiro de validação

## Resultado desta entrega

- Ambiente disponível: Linux, Python 3; sem Swift, Xcode ou SDK iOS.
- Testes Python das ferramentas: **3 testes passaram** em 2026-11-02, usando fixtures sintéticas (nenhum APK/IPA real).
- [Build iOS 41541928109](https://github.com/rauloutubro-debug/Nova-vision-ipa/actions/runs/41541928109): **sucesso** no commit `9025bc0bb7dfc5f269a5f89134d639c70209242f`, com Xcode 16.4, Swift 6.1.2 (modo Swift 5), macOS 15.7.9, runner `macos-15-intel`.
- Build de dispositivo `arm64`, `CODE_SIGNING_ALLOWED=NO`: **sucesso**; IPA real empacotado e disponibilizado como artefato. Ver [IPA-VERIFICATION](IPA-VERIFICATION.json) para hash e conferência estática do pacote.
- Testes de timeline, ranges, divisão/reordenação e persistência em macOS: **passaram**.
- Fixtures de vídeo sem áudio em paisagem e retrato, com corte e efeitos: **exportadas e decodificadas**, duração e resolução conferidas, pixel central do primeiro quadro monocromático conferido.
- Assinatura ESign e execução em iPhone/iPad: **não realizadas**; permanecem obrigatórias para confirmar o fluxo físico.
- APK: **inspeção estática realizada**, com contagens e avisos documentados em [APK-REPORT](APK-REPORT.md). Telas e funções Android não foram verificadas em execução; escopo de direitos por recurso permanece pendente.
- iOS 17.0 é o alvo mínimo configurado; não é comprovação de compatibilidade em dispositivos.

## Falha corrigida e limites desta evidência

A primeira tentativa Intel compilou as classes de mídia e falhou na execução com AVFoundation -11838. A composição criava uma faixa de áudio mesmo sem áudio na entrada. A criação passou a ocorrer somente quando há um trecho de áudio para inserir. A execução seguinte passou em ambas as fixtures sem áudio. Os atributos do compositor também foram ajustados para atender a Sendable do SDK; isso removeu os avisos de conformidade correspondentes.

Permanecem avisos de depreciação das APIs legadas de exportação no macOS 15, usadas para manter o caminho compatível com o alvo iOS 17. Não foram tratados como erros, e a exportação das fixtures passou. Isso não demonstra suporte a toda mídia de entrada.

[Diagnóstico Linux](https://github.com/rauloutubro-debug/Nova-vision-ipa/actions/runs/41541329653): **sucesso**, três testes Python e consistência do projeto gerado. Está disponível como workflow manual `Runner diagnostics`.

## Verificações automáticas

`python3 -m unittest discover -s Tests -p 'test_*.py'` usa fixtures sintéticas para verificar estrutura ZIP/IPA, permissões executáveis, exclusão de assinaturas/perfis na cópia, rejeição de builds de simulador, inventário APK e bloqueio de reutilização sem licença. Há também teste de catálogo declarativo com XML válido/inválido, templates, imagens de presets e detecção de OFL.txt. Os testes não provam que um binário seja instalável.

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

A build já passou; aprovação do MVP no dispositivo ainda depende desse roteiro nos dispositivos de destino. Falhas devem ser corrigidas antes de declarar a versão funcional/compatível.
