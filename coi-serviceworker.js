/*! coi-serviceworker v0.1.7 - Cross-Origin Isolation Service Worker for GitHub Pages & WebAssembly Pthreads */
if (typeof window === "undefined") {
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

  self.addEventListener("fetch", (event) => {
    const r = event.request;
    if (r.cache === "only-if-cached" && r.mode !== "same-origin") {
      return;
    }
    event.respondWith(
      fetch(r)
        .then((response) => {
          if (response.status === 0) {
            return response;
          }
          const newHeaders = new Headers(response.headers);
          newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
          newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
          newHeaders.set("Cross-Origin-Resource-Policy", "cross-origin");
          return new Response(response.body, {
            status: response.status,
            statusText: response.statusText,
            headers: newHeaders,
          });
        })
        .catch((e) => console.error(e))
    );
  });
} else {
  (() => {
    if (window.crossOriginIsolated !== false || !window.isSecureContext || !("serviceWorker" in navigator)) {
      return;
    }
    const swUrl = window.document.currentScript ? window.document.currentScript.src : "coi-serviceworker.js";
    navigator.serviceWorker.register(swUrl).then(
      (registration) => {
        if (registration.active && !navigator.serviceWorker.controller) {
          window.location.reload();
        } else if (registration.installing) {
          registration.installing.addEventListener("statechange", (e) => {
            if (e.target && e.target.state === "activated") {
              window.location.reload();
            }
          });
        }
      },
      (err) => {
        console.warn("COI ServiceWorker registration failed:", err);
      }
    );
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (!window.crossOriginIsolated) {
        window.location.reload();
      }
    });
  })();
}
