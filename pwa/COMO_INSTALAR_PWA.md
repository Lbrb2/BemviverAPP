# Transformando o Bem Viver em app instalável (PWA)

> A pasta `bemviver/` do repositório já vem com estes três passos feitos. O guia abaixo
> serve para quem montar outro projeto Vite do zero.

Três passos no seu projeto Vite (a pasta "bemviver" criada com npm create vite):

## 1. Copie os arquivos
Copie `manifest.webmanifest`, `sw.js` e `icone.svg` desta pasta para a pasta **`public/`** do projeto Vite.

## 2. Edite o `index.html` (na raiz do projeto Vite)
Dentro do `<head>`, adicione:

    <link rel="manifest" href="/manifest.webmanifest" />
    <meta name="theme-color" content="#27418F" />
    <link rel="icon" href="/icone.svg" />
    <title>Bem Viver ILPI</title>

## 3. Edite o `src/main.jsx`
No final do arquivo, adicione:

    if ("serviceWorker" in navigator) {
      window.addEventListener("load", () =>
        navigator.serviceWorker.register("/sw.js").catch(() => {})
      );
    }

## Testando
- `npm run dev` funciona normal, mas o service worker só entra de verdade
  no build: `npm run build` e depois `npm run preview`.
- No Chrome do celular ou do PC, abra o endereço: aparecerá a opção
  **"Instalar app"** (menu ⋮ → Instalar). O ícone vai para a tela inicial
  e o app abre em tela cheia, sem barra do navegador.
- Offline: a casca do app abre mesmo sem internet, e os check-ins e
  partidas feitos sem conexão ficam na fila e sobem sozinhos quando
  a rede volta (o app tenta a cada 30 segundos).

## Importante
- PWA exige HTTPS quando sair do localhost. Hospedagens como Render,
  Vercel e Netlify já entregam HTTPS de graça.
- Lembre de apontar o `API_URL` (topo do app_ilpi.jsx) para o endereço
  público da sua API quando ela sair do localhost.
