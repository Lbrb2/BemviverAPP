import React from "react";
import { createRoot } from "react-dom/client";
// As telas do app (idoso, responsável, equipe e gestor) estão todas aqui:
import App from "../../app_ilpi.jsx";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// PWA: permite "instalar" o app no celular e usar a fila offline
if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));
}
