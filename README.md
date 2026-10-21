# Dictation

App Android (Flutter) para corrigir as dictations do Método Callan.

Tudo funciona no próprio celular, sem chave de API e sem conta.

- **Corrigir:** tire ou escolha a foto da página do livro e a do caderno do aluno e toque em **Corrigir**. O texto das fotos é lido no aparelho (ML Kit do Google, offline), comparado palavra por palavra e cada erro vem com uma explicação curta. A dictation aparece dividida em trechos, com narração e pausas como num ditado. Se a leitura da letra de mão errar, toque em **Marcar como certo** no erro e a nota é recalculada.
- **Progresso:** cada correção fica salva com a data, o número da dictation (lido da página) e a nota, com um gráfico das notas ao longo do curso. Arraste um item para a esquerda para apagar.
- **Ouvir:** foto de qualquer texto em inglês, lido de uma vez em voz nativa.
- **Pronúncia:** escolha uma dictation do histórico (ou a foto de um texto), grave a sua leitura e veja as palavras que o celular entendeu diferente. Toque numa palavra para ouvir a pronúncia certa. Usa o reconhecimento de voz do próprio Android, então é uma aproximação, não uma avaliação fonética.

O tema claro/escuro troca no ícone do topo; voz e velocidade ficam em Configurações.

## APK

Cada push na `main` roda o workflow **Build APK** no GitHub Actions. O APK fica em *Actions → última execução → Artifacts → dictation-apk* (vem dentro de um .zip).

Para instalar, abra o arquivo no Android e permita instalar de fontes desconhecidas.

## Desenvolvimento

```
flutter pub get
flutter run
```
