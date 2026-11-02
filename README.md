# NovaEditor iOS — MVP independente

Código SwiftUI/AVFoundation/Core Image/Metal para um editor local de uma faixa, com importação pelo app Arquivos, timeline, divisão/trim, reordenação, prévia, efeitos simples e exportação MP4 pelo menu de compartilhamento. O projeto único é salvo localmente. Alvo configurado: iPhone/iPad, iOS 17 ou posterior.

**Estado:** MVP compilado para iOS físico, sem assinatura, com Xcode 16.4 no GitHub Actions. Testes de timeline e renderização/exportação em macOS passaram. Assinatura ESign e execução em iPhone/iPad ainda não foram testadas. O APK da release foi inspecionado estaticamente: identidade 0.894.0, 350 arquivos na pasta de efeitos e 12 templates confirmados. Ver [relatório e licenças](docs/APK-REPORT.md). Nenhuma tela/paridade foi validada em execução Android e nenhum recurso dele foi incluído.

## IPA desta build

[Baixar o artefato NovaEditor-iOS-unsigned](https://github.com/rauloutubro-debug/Nova-vision-ipa/actions/runs/41541928109/artifacts/13187032999) (requer login GitHub; retenção até 2026-11-16). Descompactar o ZIP do artefato no app Arquivos para obter `NovaEditor-iOS-unsigned.ipa`.

Build do commit `9025bc0bb7dfc5f269a5f89134d639c70209242f`, aplicativo MVP `0.1.0`, alvo configurado iOS 17.0. [Evidências](docs/VALIDATION.md) e [verificação do IPA](docs/IPA-VERIFICATION.json). Não é uma conversão binária do APK nem uma versão de paridade comprovada.

## Usar exclusivamente pelo iPad

Enviar esta pasta completa a um repositório GitHub, abrir **Actions → iOS unsigned IPA → Run workflow**, e, após sucesso, baixar/descompactar o artefato para obter `NovaEditor-iOS-unsigned.ipa`. Assinar no ESign com certificado/chave privada e perfil válidos e compatíveis. O workflow não utiliza certificados. Passo a passo e limites em [BUILD-ESIGN](docs/BUILD-ESIGN.md).

Não existe conversão automática de APK para IPA. O workflow compila este código nativo novo. Repositório de destino: https://github.com/rauloutubro-debug/Nova-vision-ipa. Consulte Actions para o resultado real de cada execução.

## Desenvolvimento e conferência

Abrir `NovaEditor.xcodeproj` em Xcode com SDK iOS 17+. Não há dependências externas do app. Bundle ID provisório: `org.example.NovaEditor`.

```sh
python3 Scripts/generate_project.py  # regenerar após adicionar/remover fontes ou mudar configurações
python3 -m unittest discover -s Tests -p 'test_*.py'
# macOS com Xcode:
bash Scripts/test_media.sh
bash Scripts/build_unsigned.sh
```

O projeto Xcode gerado está incluído. O workflow confere sua sincronização, testa lógica/render em macOS, compila para dispositivo sem assinatura e empacota `Payload/NovaEditor.app`. Ler [VALIDATION](docs/VALIDATION.md) antes de afirmar suporte em um dispositivo.

## Referência Android e próximos passos

[Plano de migração e matriz de direitos](docs/MIGRATION.md). Para repetir a inspeção do APK:

```sh
python3 Scripts/inspect_apk.py /caminho/referencia.apk --output analysis/apk
```

A ferramenta gera inventário estático sem extração nem execução. Categorias são heurísticas; todos os recursos começam com licença desconhecida e reutilização bloqueada. O relatório não identifica por si só telas acessíveis ou direitos de uso.

O MVP usa canvas 720p retrato/paisagem, 30 fps e SDR; não preserva necessariamente características da origem. Fontes do sistema e filtros Core Image próprios. Sem VHS/glitches, templates, Python, QuickJS, ONNX ou RIFE nesta versão.

O código novo deste diretório é oferecido sob [MIT](LICENSE). Isso não licencia o APK, nome/marca, recursos ou modelos de terceiros. O uso dos SDKs Apple segue seus termos.
