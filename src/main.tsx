import { createRoot } from "react-dom/client";
import { HelmetProvider } from "react-helmet-async";
import App from "./App.tsx";
import "./index.css";
import { registerAppServiceWorker } from "./lib/registerAppServiceWorker";

// Recover once from stale cached Vite assets, a frequent cause of a blank PWA screen.
const CHUNK_RECOVERY_KEY = "agricapital-portal-chunk-recovery";
const isAssetLoadError = (message: string) =>
  /failed to fetch dynamically imported module|importing a module script failed|loading chunk .* failed|css chunk load failed|failed to load module script/i.test(message);

window.addEventListener("error", (event) => {
  const message = event.message || "";
  if (!isAssetLoadError(message)) return;
  try {
    const currentPage = window.location.pathname + window.location.search;
    if (sessionStorage.getItem(CHUNK_RECOVERY_KEY) !== currentPage) {
      sessionStorage.setItem(CHUNK_RECOVERY_KEY, currentPage);
      window.location.reload();
    }
  } catch {
    // If storage is unavailable, leave the error visible instead of risking a reload loop.
  }
});

window.addEventListener("load", () => {
  window.setTimeout(() => {
    try {
      sessionStorage.removeItem(CHUNK_RECOVERY_KEY);
    } catch {
      // Storage may be disabled by the browser.
    }
  }, 5000);
});

void registerAppServiceWorker().catch((error) => {
  console.error("[AgriCapital Portal] Enregistrement du service worker impossible :", error);
});

const rootElement = document.getElementById("root");
if (!rootElement) {
  document.body.innerHTML = "<main style='font-family:sans-serif;padding:2rem'><h1>AgriCapital Portail</h1><p>Impossible de charger l’application. Actualisez la page.</p></main>";
} else {
  createRoot(rootElement).render(
    <HelmetProvider>
      <App />
    </HelmetProvider>
  );
}
