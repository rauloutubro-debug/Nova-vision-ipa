# Inspeção estática do APK 0.894.0

Analisado em 2026-11-02 a partir de [NovaEditor-0.894.0.apk, release Apk](https://github.com/rauloutubro-debug/Nova-vision-ipa/releases/tag/Apk). Download de 209.161.589 bytes. SHA-256:

```text
29a1573452bb6ec79693ba2bbce3fb71615533e6af750ddb24fbf1c44152d25f
```

Nenhum código do APK foi executado ou incorporado ao app iOS. O APK permaneceu fora da árvore do projeto. Relatórios contêm contagens/metadados, sem shaders, imagens, fontes, modelos ou conteúdo completo de presets/templates.

## Identidade e estrutura verificadas

Manifesto binário decodificado com `pyaxmlparser 0.3.31`: package `com.novavision.editor.apk`, versionName `0.894.0`, versionCode `913`, minSdkVersion `26`, targetSdkVersion `37`. São valores declarados, sem avaliação de compatibilidade Android.

O ZIP contém **1.305 arquivos**, incluindo **1.121 em assets**, **dois DEX**, **18 bibliotecas .so** e **43 arquivos de fonte TTF/OTF**. As bibliotecas aparecem em `arm64-v8a` e `armeabi-v7a`, nove por arquitetura. Foram identificados nomes de biblioteca Python (`libpython.so`, `libpython.zip.so`), QuickJS (`libqjs.so`) e ONNX Runtime (`libonnxruntime.so`, `libonnxruntime4j_jni.so`). A presença dos arquivos não comprova que cada função seja usada pelo aplicativo.

| Grupo | Evidência estática | Implicação para migração |
| --- | --- | --- |
| `assets/effects` | 350 arquivos: 345 XML válidos com raiz `effect`, IDs distintos e hashes de conteúdo distintos; cinco imagens | XML inclui parâmetros e shaders/passes; exige adaptação do motor, sem inferir equivalência visual por nome |
| Categorias dos efeitos | 90 stylize, 66 distort, 51 color, 28 blur, 22 looks, 21 procedural, 21 matte e outras | Priorizar correções de cor e efeitos simples próprios antes dos múltiplos passes |
| `assets/presets` | **203 JPG**, incluindo duas imagens de amostra na raiz | São imagens; não comprovam 203 definições de preset reutilizáveis |
| Presets dentro dos XML | 95 elementos XML chamados `preset` | Contagem de elementos, sem prova de acessibilidade, unicidade funcional ou catálogo completo |
| Templates | 12 `.novatemplate`, todos parseáveis como JSON | Declaram camadas, campos e tempos; precisam de um modelo iOS próprio e revisão de direitos |
| VHS | 34 MP4: 20 glitch, 12 overlay, rewind e static | Precisam de licença da mídia e composição temporal própria |
| Shaders auxiliares | Pastas element3d, mblooks, swarpbubble, unichromab, univhs; arquivos frag/vert/glsl/comp | Não são Metal; portar somente após definir escopo de licença e testes de render |
| Fontes | 42 TTF/OTF em assets/fonts e um TTF em res/font | Identificar licença por família/arquivo e preservar avisos e nomes reservados |
| IA | `assets/ia/rife-v4.6.onnx` | Arquivo presente; licença dos pesos, operadores e desempenho iOS ainda pendentes |

[Resumo completo](apk/catalog-summary.json), [catálogo de 345 XML](apk/effects.csv), [catálogo dos templates](apk/templates.csv), [inventário resumido](apk/summary.json).

## Componentes e telas

O manifesto declara `com.novaeditor.MainActivity` exportada com intent MAIN e entradas VIEW/SEND. Declara `com.novaeditor.export.ServicoDeExportacao` não exportado e componentes de bibliotecas Android/Google. [Resumo do manifesto](apk/manifest-summary.json).

Uma leitura das tabelas de definições dos dois DEX encontrou 11.960 classes definidas, 1.246 sob o prefixo `com.novaeditor`. Nomes como `Project`, `ProjectHolder`, `AnimationPresets`, `ReguaDaTimeline` e `TimelineZoom` são indícios estruturais; não provam telas ou ações disponíveis. Não foi feito decompilado/portado de métodos.

**Nenhuma tela foi confirmada por execução Android.** Sem dispositivo/emulador Android neste ambiente, navegação, aparência, acessibilidade, login e exportação do original permanecem pendentes. Permissões declaradas também não demonstram funcionalidades utilizáveis.

## Licenças encontradas e decisões

- `assets/licencas/EFFECTCRAFT-LICENSE-MIT.txt`: aviso MIT atribuído a ArtCraft Team e contribuidores EffectCraft. O texto concede direitos sobre o Software coberto, mas não identifica explicitamente cada recurso do APK. Reutilização de um arquivo depende de estabelecer sua correspondência com esse componente; não autoriza presumir que o APK inteiro seja MIT.
- `assets/fonts/galeria/LICENSES.txt` lista famílias e atribuições, indicando OFL 1.1 para Montserrat, Poppins, Inter, Oswald, Lato, Playfair Display, Cinzel/Cinzel Decorative; Apache 2.0 para Roboto. Há `OFL.txt` e `APACHE-LICENSE.txt` nas pastas de fontes. O texto também cita Share Tech Mono de res/font e condições de nomes reservados. Essas fontes são candidatas à reutilização sob as respectivas condições, após correlacionar arquivos/versões e preservar avisos. Nenhuma foi incluída no MVP.
- Há avisos de bibliotecas AndroidX e de publicsuffix/OkHttp, que não licenciam os demais recursos.
- Não foi identificado um aviso específico dos pesos RIFE, dos 34 MP4 ou de cada shader/template. Não foi concluída uma auditoria jurídica ou de proveniência de todos os componentes. Esses recursos permanecem sem aprovação para inclusão.

A classificação inicial por nome do inventário foi corrigida para reconhecer também `OFL.txt`; **12 arquivos** são candidatos de licença/aviso. Nem todo aviso se chama LICENSE, e sua presença não resolve automaticamente o escopo.

## Plano ajustado

1. Manter o MVP independente já implementado, com fonte do sistema e três filtros Core Image próprios.
2. Concluir build macOS e testar instalação/edição/exportação nos dispositivos iOS de destino.
3. Obter evidências de navegação Android antes de reproduzir telas ou afirmar paridade; confrontar cada funcionalidade com resultados exportados autorizados.
4. Resolver escopo dos avisos e proveniência por recurso; as fontes com avisos identificados e correções simples são candidatas iniciais. Nenhum efeito foi aprovado apenas por seu nome.
5. Mapear o esquema dos XML para parâmetros próprios e reimplementar shaders em Core Image/Metal, preservando avisos quando aplicáveis. Presets baseados só em JPG precisam de suas definições reais.
6. Deixar múltiplas camadas/passes, templates, glitches/VHS e RIFE para fases posteriores, com testes de imagem, tempo, memória e exportação.

## Reproduzir o catálogo

```sh
python3 Scripts/inspect_apk.py /caminho/NovaEditor-0.894.0.apk --output analysis/apk
python3 Scripts/catalog_apk.py /caminho/NovaEditor-0.894.0.apk --output analysis/apk
# Dependência apenas da análise; não usada pelo app nem pela build iOS:
python3 -m pip install pyaxmlparser==0.3.31
python3 Scripts/decode_manifest.py /caminho/NovaEditor-0.894.0.apk --output analysis/apk/manifest-summary.json
```

O inventário CSV completo pode ser regenerado pelo primeiro comando. O catálogo não copia conteúdo para o app e não concede direitos de reutilização.
