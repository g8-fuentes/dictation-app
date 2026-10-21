# Dictation

App Android (Flutter) para corrigir as dictations do Método Callan.

1. Tire ou escolha a foto do texto original do livro.
2. Tire ou escolha a foto do que o aluno escreveu.
3. Toque em **Corrigir**. Enquanto o Claude analisa, as palavras da dictation aparecem na tela e cada uma fala a pronúncia ao ser tocada.
4. O resultado mostra a nota, os erros e a dictation dividida em trechos, com o original, o que o aluno escreveu marcado e a explicação de cada erro. O botão **Tocar** narra a dictation, com pausas como num ditado.

O tema claro/escuro troca no ícone do topo.

## Chave da API

O app usa a API da Anthropic com a sua própria chave. Crie uma em <https://console.anthropic.com/settings/keys> e cole em **Configurações** no app. A chave fica salva só no celular.

## APK

Cada push na `main` roda o workflow **Build APK** no GitHub Actions. O APK fica em *Actions → última execução → Artifacts → dictation-apk* (vem dentro de um .zip).

Para instalar, abra o arquivo no Android e permita instalar de fontes desconhecidas.

## Desenvolvimento

```
flutter pub get
flutter run
```
