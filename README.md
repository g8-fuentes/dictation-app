# dictation-app

App web (PWA) que corrige a **dictation** dos livros Callan: você tira a foto da página do livro e a foto do que o aluno escreveu, e o app aponta os erros. Funciona no navegador do celular e pode ser instalado na tela inicial. As fotos são lidas pelo Gemini com a sua chave gratuita do [Google AI Studio](https://aistudio.google.com/apikey), colada no próprio app.

**Abrir:** https://g8-fuentes.github.io/dictation-app/

## Instalar no celular

- **Android (Chrome):** abra o link, toque em ⋮ e depois em **Instalar app** (ou **Adicionar à tela inicial**).
- **iPhone (Safari):** abra o link, toque em Compartilhar e depois em **Adicionar à Tela de Início**.

## O que tem

- **Corrigir:** duas fotos (câmera ou galeria) e um toque em Corrigir. O texto é dividido em partes curtas, com a cópia do aluno marcada (riscado = errado, verde = certo, ^ = faltou, ondulado = sobrou), a explicação de cada erro e a opção **Marcar como certo** quando o app leu a letra errado. Dá para ouvir a dictation com pausas, normal ou devagar.
- **Progresso:** todas as dictations ficam salvas no aparelho, com nota, média, melhor nota e gráfico da evolução.
- **Ouvir:** foto de qualquer texto em inglês, lido de uma vez na voz nativa do celular.
- **Pronúncia:** escolha uma dictation (ou foto de um texto), grave lendo em voz alta e veja as palavras que soaram diferente, com o áudio certo de cada uma.
- Tema claro/escuro, sotaque britânico ou americano e velocidade da voz nas Configurações.

## Como funciona

O Gemini transcreve a página do livro e a letra do aluno exatamente como foi escrita (numa única chamada), e o app compara os dois textos palavra por palavra, divide em partes e explica cada erro. A chave fica salva só no navegador do aparelho (Configurações) e é enviada apenas ao Google; nunca vai para o repositório. Se o Gemini estiver ocupado, o app tenta outro modelo Flash. Sem chave, as abas Ouvir e Pronúncia leem fotos de texto impresso offline com o [Tesseract.js](https://github.com/naptha/tesseract.js). A voz e o reconhecimento de fala são os do celular (o reconhecimento precisa de internet no Chrome). Se a leitura errar uma palavra, use **Marcar como certo**.

A versão anterior em Flutter (APK) está no branch `flutter-app`.

## Desenvolvimento

```bash
npm install
npm run dev     # http://localhost:5173/dictation-app/
npm test
npm run build
```

O push no `main` publica no GitHub Pages pelo workflow `.github/workflows/pages.yml`.
