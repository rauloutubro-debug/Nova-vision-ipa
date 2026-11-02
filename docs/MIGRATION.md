# Migração do NovaEditor Android para iOS

## Evidência disponível

O APK foi disponibilizado na release `Apk` em 2026-11-02 e inspecionado estaticamente. Ver [APK-REPORT](APK-REPORT.md) para hashes, manifesto, contagens corrigidas e avisos encontrados. Foram confirmados 350 arquivos em effects, dos quais 345 XML; os 203 arquivos de presets são JPG. Não há gravações ou execução Android para confirmar telas e funcionalidades acessíveis.

O MVP é uma implementação independente; não foi portado DEX, incorporado recurso, copiada interface nem estabelecida equivalência funcional com o aplicativo Android. O nome é provisório e não implica afiliação ou autorização de marca.

## Processo de inspeção e verificações pendentes

1. Guardar o APK fora do Git e registrar proveniência e autorização de análise. Executar `python3 Scripts/inspect_apk.py caminho/app.apk --output analysis/apk`. O script registra SHA-256 do APK, caminhos ZIP, tamanhos, CRC e categorias por nomes, sem extração nem execução. Não valida que o APK seja a versão informada.
2. Decodificar AndroidManifest.xml com ferramentas Android em ambiente autorizado. Registrar package, versionName/versionCode, activities exportadas, permissões, providers e serviços. Activities não demonstram por si só telas visíveis. Fazer análise estática de DEX e bibliotecas somente dentro do escopo autorizado, sem contornar controles de acesso.
3. Navegar no aplicativo Android autorizado e registrar cada tela alcançável, estados, ações, entradas/saídas e gravação de evidência. Um APK isolado e uma lista de activities não comprovam funcionalidades acessíveis. Sem Android disponível, esta etapa permanece pendente.
4. Agrupar efeitos/presets pelo formato real: parâmetros, scripts, shaders, mídia ou arquivos auxiliares. Conferir referências e deduplicar conteúdo por hash antes de contar efeitos e presets. As categorias do script são heurísticas, não um catálogo funcional.
5. Para cada recurso candidato, preencher autor, origem, arquivo de licença, versão, permissões de redistribuição/modificação/uso comercial, atribuição, dependências e decisão. Ausência de licença deixa a reutilização bloqueada. A licença de uma biblioteca não cobre automaticamente o aplicativo, seus modelos ou seus recursos.
6. Só integrar recursos aprovados, com avisos e testes de comparação usando entradas cuja utilização seja autorizada.

## Matriz inicial de migração

| Componente informado | Possibilidade técnica | Condição de uso / trabalho necessário |
| --- | --- | --- |
| DEX e APIs Android | Não executam como aplicativo iOS nativo | Reimplementar comportamentos observados; não há conversor DEX → Swift utilizado |
| Imagens, áudio, VHS e templates | Formatos podem ser convertidos | Licença individual, codecs, espaço e memória; nenhum incluído |
| Fontes | Algumas fontes podem ser registradas no iOS | Permissão de distribuição e incorporação; usar fonte do sistema no MVP |
| Presets de parâmetros | Possível mapear depois de compreender o formato | Validar licença, unidades e semântica; recriar resultados em Core Image/Metal |
| Shaders/glitches | Normalmente exigem adaptação | Reescrever para Metal/Core Image; comparar cores, bordas, tempo e desempenho |
| Python/QuickJS | Não são uma interface iOS pronta | Preferir lógica Swift local; avaliar licenças e política de scripts antes de incorporar runtimes |
| ONNX Runtime | Possível dependência futura específica para iOS | Auditar versão, licença, arquitetura, operadores e tamanho; não incluído |
| Modelo RIFE | Interpolação depende do modelo e de operadores | Auditar pesos separadamente; avaliar Core ML/ONNX, memória, energia e resultados. Não implementado |

## Entregas e ordem

**MVP implementado em código:** SwiftUI com adaptação de largura para iPhone/iPad, importação múltipla pelo seletor Arquivos, cópia local, projeto único salvo em JSON, timeline de uma faixa de vídeo, seleção, cursor, divisão, entrada/saída, remoção e reordenação. Prévia AVPlayer, áudio original quando disponível, três filtros simples próprios e MP4 compartilhável pelo menu do sistema.

**Render:** AVMutableComposition + instruções por trecho + AVVideoCompositing/Core Image. CIContext usa Metal quando disponível e contexto padrão como alternativa. Canvas 1280×720 ou 720×1280 conforme o primeiro clipe, enquadramento proporcional com barras, 30 fps e saída SDR. Não é uma promessa de preservar HDR, metadados, taxa de quadros ou resolução da origem. O preset de exportação é HighestQuality com contêiner MP4, sem garantia de codec fixo. Sem efeitos ou bibliotecas do APK.

**Após o MVP validado:** confirmar licença/inventário e telas; miniaturas e formas de onda; progresso/cancelamento de operações; múltiplos projetos e gestão de armazenamento; parâmetros de filtros e presets próprios; só depois transições, VHS/glitches com shaders e IA. Não há cronograma ou paridade garantidos antes da análise.

## Limites e integridade do projeto

Um projeto por instalação, persistido em Application Support. Importação inválida falha por lote e preserva o projeto anterior. Alterações são compostas antes da troca e da gravação atômica; mídia removida só é apagada após sucesso. Os originais no app Arquivos não são alterados. Desinstalar o app pode apagar projeto e mídia; não existe backup de projeto exportável nesta versão.

O app copia integralmente os vídeos, exigindo espaço para originais locais e saída. Exportações temporárias podem permanecer até limpeza pelo sistema; não há gerenciador de armazenamento. Não há trilhas adicionais, títulos, captura de câmera, músicas, transições, velocidade, IA ou download remoto. Importação depende de o provedor de Arquivos entregar o arquivo e de o AVFoundation decodificá-lo; a extensão sozinha não estabelece suporte. DRM não é contornado. Vídeos HDR, orientação espelhada, entradas multicanal, vídeos muito longos e provedores iCloud precisam de validação específica.
