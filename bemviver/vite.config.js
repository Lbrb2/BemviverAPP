// Projeto Vite que exibe o app. As telas ficam num arquivo só, na raiz do
// repositório (../app_ilpi.jsx), e são importadas por src/main.jsx.
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // o app_ilpi.jsx mora uma pasta acima: o React dele tem de ser o mesmo daqui
  resolve: { dedupe: ["react", "react-dom"] },
  server: { port: 5173, open: true, fs: { allow: [".."] } },
});
