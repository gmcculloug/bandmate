// Bandmate Gig Mode Service Worker
// Provides offline caching for gig mode functionality

const CACHE_NAME = 'bandmate-gig-mode-v1';
const GIG_DATA_CACHE = 'bandmate-gig-data-v1';

// Static assets to always cache
const STATIC_ASSETS = [
  '/gig-mode.css',
  '/gig-mode.js',
  '/favicon.ico'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[Service Worker] Static assets cached');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[Service Worker] Failed to cache static assets:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME && cacheName !== GIG_DATA_CACHE) {
              console.log('[Service Worker] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('[Service Worker] Activated');
        return self.clients.claim();
      })
  );
});

// Fetch event - handle requests with caching strategy
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Handle gig mode API requests
  if (url.pathname.includes('/api/gigs/') && url.pathname.includes('/gig_mode')) {
    event.respondWith(handleGigDataRequest(event.request));
    return;
  }

  // Handle gig mode page requests
  if (url.pathname.includes('/gigs/') && url.pathname.includes('/gig_mode')) {
    event.respondWith(handleGigModePageRequest(event.request));
    return;
  }

  // Handle static assets (CSS, JS, etc.)
  if (isStaticAsset(url.pathname)) {
    event.respondWith(handleStaticAssetRequest(event.request));
    return;
  }

  // For all other requests, just fetch normally
  event.respondWith(fetch(event.request));
});

// Handle gig data API requests with cache-first strategy
async function handleGigDataRequest(request) {
  const cache = await caches.open(GIG_DATA_CACHE);

  try {
    // Try cache first
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      console.log('[Service Worker] Serving gig data from cache');

      // Fetch fresh data in background and update cache
      fetchAndCacheGigData(request, cache);

      return cachedResponse;
    }

    // No cache, fetch from network
    console.log('[Service Worker] Fetching fresh gig data');
    const networkResponse = await fetch(request);

    if (networkResponse.ok) {
      // Cache the response
      await cache.put(request, networkResponse.clone());
      console.log('[Service Worker] Cached fresh gig data');
    }

    return networkResponse;

  } catch (error) {
    console.error('[Service Worker] Failed to fetch gig data:', error);

    // Try to serve from cache as fallback
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      console.log('[Service Worker] Serving stale gig data from cache (offline)');
      return cachedResponse;
    }

    // Return error response if no cache available
    return new Response(
      JSON.stringify({ error: 'Offline and no cached data available' }),
      {
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

// Handle gig mode page requests
async function handleGigModePageRequest(request) {
  try {
    // Try network first for fresh content
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      // Cache the page
      const cache = await caches.open(CACHE_NAME);
      await cache.put(request, networkResponse.clone());
      return networkResponse;
    }
  } catch (error) {
    console.log('[Service Worker] Network failed, trying cache');
  }

  // Fall back to cache
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);

  if (cachedResponse) {
    console.log('[Service Worker] Serving gig mode page from cache');
    return cachedResponse;
  }

  // No cache available
  return new Response('Offline and no cached page available', {
    status: 503,
    headers: { 'Content-Type': 'text/html' }
  });
}

// Handle static assets with cache-first strategy
async function handleStaticAssetRequest(request) {
  const cache = await caches.open(CACHE_NAME);

  // Try cache first
  const cachedResponse = await cache.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  // Fetch from network and cache
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      await cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[Service Worker] Failed to fetch static asset:', error);
    return new Response('Asset not available offline', { status: 503 });
  }
}

// Background fetch and cache update for gig data
async function fetchAndCacheGigData(request, cache) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      await cache.put(request, networkResponse.clone());
      console.log('[Service Worker] Updated gig data cache in background');

      // Notify clients about the update
      self.clients.matchAll().then(clients => {
        clients.forEach(client => {
          client.postMessage({
            type: 'GIG_DATA_UPDATED',
            url: request.url
          });
        });
      });
    }
  } catch (error) {
    console.log('[Service Worker] Background update failed:', error);
  }
}

// Check if a URL is a static asset we want to cache
function isStaticAsset(pathname) {
  const staticExtensions = ['.css', '.js', '.ico', '.png', '.jpg', '.svg'];
  const gigModeAssets = ['/gig-mode.css', '/gig-mode.js'];

  return staticExtensions.some(ext => pathname.endsWith(ext)) ||
         gigModeAssets.some(asset => pathname.includes(asset));
}

// Message handler for communication with the main thread
self.addEventListener('message', (event) => {
  const { type, gigId } = event.data;

  if (type === 'CACHE_GIG_DATA') {
    cacheGigData(gigId);
  } else if (type === 'CLEAR_GIG_CACHE') {
    clearGigCache(gigId);
  } else if (type === 'GET_CACHE_STATUS') {
    getCacheStatus(gigId).then(status => {
      event.ports[0].postMessage(status);
    });
  }
});

// Cache specific gig data
async function cacheGigData(gigId) {
  try {
    const gigDataUrl = `/api/gigs/${gigId}/gig_mode`;
    const gigPageUrl = `/gigs/${gigId}/gig_mode`;

    const [dataCache, pageCache] = await Promise.all([
      caches.open(GIG_DATA_CACHE),
      caches.open(CACHE_NAME)
    ]);

    // Fetch and cache gig data
    const dataResponse = await fetch(gigDataUrl);
    if (dataResponse.ok) {
      await dataCache.put(gigDataUrl, dataResponse.clone());
      console.log('[Service Worker] Cached gig data for gig:', gigId);
    }

    // Fetch and cache gig page
    const pageResponse = await fetch(gigPageUrl);
    if (pageResponse.ok) {
      await pageCache.put(gigPageUrl, pageResponse.clone());
      console.log('[Service Worker] Cached gig page for gig:', gigId);
    }

    // Notify clients
    self.clients.matchAll().then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type: 'GIG_CACHED',
          gigId: gigId
        });
      });
    });

  } catch (error) {
    console.error('[Service Worker] Failed to cache gig data:', error);

    // Notify clients of error
    self.clients.matchAll().then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type: 'GIG_CACHE_ERROR',
          gigId: gigId,
          error: error.message
        });
      });
    });
  }
}

// Clear cache for specific gig
async function clearGigCache(gigId) {
  try {
    const [dataCache, pageCache] = await Promise.all([
      caches.open(GIG_DATA_CACHE),
      caches.open(CACHE_NAME)
    ]);

    const gigDataUrl = `/api/gigs/${gigId}/gig_mode`;
    const gigPageUrl = `/gigs/${gigId}/gig_mode`;

    await Promise.all([
      dataCache.delete(gigDataUrl),
      pageCache.delete(gigPageUrl)
    ]);

    console.log('[Service Worker] Cleared cache for gig:', gigId);

  } catch (error) {
    console.error('[Service Worker] Failed to clear gig cache:', error);
  }
}

// Get cache status for specific gig
async function getCacheStatus(gigId) {
  try {
    const [dataCache, pageCache] = await Promise.all([
      caches.open(GIG_DATA_CACHE),
      caches.open(CACHE_NAME)
    ]);

    const gigDataUrl = `/api/gigs/${gigId}/gig_mode`;
    const gigPageUrl = `/gigs/${gigId}/gig_mode`;

    const [dataExists, pageExists] = await Promise.all([
      dataCache.match(gigDataUrl).then(response => !!response),
      pageCache.match(gigPageUrl).then(response => !!response)
    ]);

    return {
      gigId: gigId,
      dataCached: dataExists,
      pageCached: pageExists,
      fullyCached: dataExists && pageExists
    };

  } catch (error) {
    console.error('[Service Worker] Failed to get cache status:', error);
    return {
      gigId: gigId,
      dataCached: false,
      pageCached: false,
      fullyCached: false,
      error: error.message
    };
  }
}