// Service worker do Bem Viver ILPI — casca do app disponível offline.
// A API (outra origem) nunca é interceptada: escritas offline ficam
// na fila do próprio app e sobem quando a conexão volta.
const CACHE = "bemviver-v1";
const CASCA = ["/", "/index.html", "/manifest.webmanifest", "/icone.svg"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CASCA)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== self.location.origin) return;
  e.respondWith(
    caches.match(e.request).then((emCache) => {
      const daRede = fetch(e.request)
        .then((resp) => {
          if (resp.ok) {
            const copia = resp.clone();
            caches.open(CACHE).then((c) => c.put(e.request, copia));
          }
          return resp;
        })
        .catch(() => emCache);
      return emCache || daRede;
    })
  );
});
