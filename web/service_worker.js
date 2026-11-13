'use strict';

// Flutter 3.50 ships a flutter_service_worker.js that only unregisters itself,
// so GhostThread keeps its own worker for the app shell.
const VERSION = 'v1';
const SHELL_CACHE = `ghostthread-shell-${VERSION}`;
const RUNTIME_CACHE = `ghostthread-runtime-${VERSION}`;
const OFFLINE_URL = 'offline.html';

const SHELL_ASSETS = [
  './',
  'index.html',
  'manifest.json',
  OFFLINE_URL,
  'favicon.png',
  'icons/Icon-180.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL_CACHE);
      await Promise.all(
        SHELL_ASSETS.map(async (asset) => {
          try {
            await cache.add(new Request(asset, { cache: 'reload' }));
          } catch (error) {
            // A missing optional entry must not break the whole install.
            console.warn('[ghostthread] could not precache', asset, error);
          }
        })
      );
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => key !== SHELL_CACHE && key !== RUNTIME_CACHE)
          .map((key) => caches.delete(key))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(handleNavigation(request));
    return;
  }

  event.respondWith(staleWhileRevalidate(request));
});

async function handleNavigation(request) {
  const cache = await caches.open(SHELL_CACHE);

  try {
    const response = await fetch(request);
    if (response && response.ok && response.type === 'basic') {
      // The SPA has a single entry document; keep the newest copy.
      await cache.put('index.html', response.clone());
    }
    return response;
  } catch (error) {
    const cached =
      (await cache.match('index.html')) ||
      (await caches.match('index.html')) ||
      (await caches.match('./'));
    if (cached) {
      return cached;
    }

    const offline = await caches.match(OFFLINE_URL);
    if (offline) {
      return offline;
    }

    return new Response('GhostThread is offline and its files are not cached.', {
      status: 503,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  }
}

async function staleWhileRevalidate(request) {
  const cached = await caches.match(request);
  const runtime = await caches.open(RUNTIME_CACHE);

  const network = fetch(request)
    .then(async (response) => {
      if (
        response &&
        response.status === 200 &&
        response.type === 'basic'
      ) {
        await runtime.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cached) {
    // Refresh in the background; the cached copy is good enough for now.
    return cached;
  }

  const fresh = await network;
  if (fresh) return fresh;

  return new Response('', { status: 504, statusText: 'Offline' });
}
