# Compilação pelo GitHub e assinatura no iPad

## Estado

Projeto Xcode e workflow incluídos; nenhum IPA real foi gerado no ambiente Linux. Não houve execução do GitHub Actions, assinatura ESign ou instalação física nesta entrega. A ausência de certificado na compilação não torna o IPA instalável sem assinatura posterior válida.

## Fluxo sem Mac local

1. Pelo Safari ou cliente Git no iPad, criar/selecionar um repositório. Enviar todo o conteúdo deste diretório, incluindo `.github/workflows/ios.yml`, `NovaEditor.xcodeproj` e `Scripts`. A interface web pode ocultar pastas iniciadas por ponto; conferir que o workflow está no repositório. Não é necessário tornar o repositório público.
2. Preferencialmente alterar `PRODUCT_BUNDLE_IDENTIFIER` no gerador `Scripts/generate_project.py` para seu identificador autorizado e regenerar o projeto, mantendo os dois arquivos sincronizados. Alternativamente o identificador pode ser ajustado pelo ESign, se suportado e compatível com seu perfil; isso precisa de teste.
3. Abrir **Actions → iOS unsigned IPA → Run workflow**. O runner `macos-latest` usa o Xcode selecionado pela imagem e registra sua versão; não depende de pacotes de terceiros do app ou de certificados. As versões das actions estão fixadas por versão principal; para controles de cadeia de fornecimento mais estritos, fixar os SHAs revisados.
4. O workflow verifica o projeto gerado, executa testes de lógica e mídia no macOS e compila com destino `generic/platform=iOS`, SDK `iphoneos`, `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO` e identidade vazia.
5. Após sucesso, baixar o artefato **NovaEditor-iOS-unsigned** na página da execução. Descompactar o ZIP do artefato no app Arquivos para obter **NovaEditor-iOS-unsigned.ipa**. O ZIP de artefato envolve o IPA, não deve ser importado como se fosse o próprio IPA. Retenção configurada: 14 dias. Consumo e disponibilidade de runners dependem da conta/plano GitHub.
6. No ESign, importar o IPA, seu certificado/identidade de assinatura (normalmente `.p12` com chave privada) e perfil de provisionamento válido. Um perfil sozinho não assina um app: é necessária a chave privada correspondente ao certificado permitido pelo perfil. Conferir Bundle ID, equipe, prazo e elegibilidade do dispositivo/tipo de distribuição. Assinar e instalar conforme o fluxo do ESign. Os nomes dos menus variam com a versão e não foram verificados.
7. Executar o roteiro de testes físicos antes de confiar na instalação. Se falhar, guardar a mensagem de erro e o log do Actions sem divulgar chaves/certificados.

Para mudar o Bundle ID apenas na build do GitHub sem executar Python pelo iPad, adicionar ao comando `xcodebuild` em `Scripts/build_unsigned.sh` o argumento `PRODUCT_BUNDLE_IDENTIFIER=seu.identificador`. Isso substitui a configuração durante a compilação.

## Estrutura do pacote

```text
NovaEditor-iOS-unsigned.ipa (ZIP)
└── Payload/
    └── NovaEditor.app/
        ├── NovaEditor          # executável de dispositivo, não simulador
        ├── Info.plist
        └── ...                # conteúdo produzido pelo Xcode
```

`Scripts/package_ipa.py` verifica plataforma iPhoneOS, preserva o bit executável e remove perfis e diretórios `_CodeSignature` de uma cópia de empacotamento. Isso não substitui a assinatura posterior. Não são usadas bibliotecas dinâmicas de terceiros nem extensões no MVP; se forem adicionadas, a assinatura de componentes internos deve ser reavaliada.

## Entitlements e permissões

O código-fonte do MVP não requer entitlements especiais nem arquivo `.entitlements`. O ESign deve gerar/aplicar os valores de assinatura autorizados pelo perfil, incluindo `application-identifier` e `com.apple.developer.team-identifier` quando exigidos. Não copiar entitlements do APK. Não adicionar `get-task-allow` para distribuição nem grupos/chaves incompatíveis com o perfil.

Importação usa o seletor de documentos do sistema e acesso security-scoped durante a cópia. Exportação abre o menu de compartilhamento; não chama diretamente a API de gravação na fototeca. Portanto não foram solicitadas permissões de câmera, microfone, biblioteca de fotos, rede ou grupos compartilhados. Se futuramente usar Photos para salvar diretamente, será preciso declarar a finalidade adequada, por exemplo `NSPhotoLibraryAddUsageDescription`, e solicitar autorização pelo fluxo da API. Essa descrição é uma chave de privacidade, não um entitlement. Conferir permissões efetivamente exigidas pelas atividades escolhidas no dispositivo.

## Certificados compartilhados

Certificados compartilhados podem ser revogados ou expirar, fazendo a assinatura/instalação falhar ou impedindo a abertura de apps já instalados. Podem não autorizar seu dispositivo, Bundle ID ou recursos. Perfil ad hoc/desenvolvimento exige elegibilidade/registro do dispositivo; certificados enterprise têm finalidade e termos específicos e não autorizam distribuição pública geral. ESign não elimina esses limites. Não existe garantia de instalação permanente nem recomendação de contorno de verificação ou revogação.

Nunca enviar certificados, chaves privadas, senhas, perfis ou UDIDs ao repositório. A build não usa esses dados nem secrets GitHub. Os padrões `.gitignore` ajudam, mas não substituem revisar arquivos antes do envio.
