/* Service worker — offline shell for the training app.
 *
 * Code and data are network-first: a redeploy must reach the phone on the next
 * online launch, and a cache-first shell would strand it on an old version
 * indefinitely. The network fetch uses cache:"no-store" so the browser's own
 * HTTP cache can't serve a stale copy underneath us either.
 *
 * Only the icons are cache-first — they're immutable and worth the speed.
 *
 * Offline still works: every network-first response is mirrored into the cache
 * and served from there the moment fetch fails.
 */
const CACHE = "training-v2";
const SHELL = ["./", "./index.html", "./manifest.json", "./icon-192.png", "./icon-512.png", "./icon-180.png"];
const IMMUTABLE = /\.(png|ico|svg|woff2?)$/i;

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => Promise.allSettled(SHELL.map(u => c.add(new Request(u, {cache:"reload"})))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

async function networkFirst(req, fallbackKey){
  try{
    // no-store: bypass the HTTP cache, otherwise a stale disk copy wins silently
    const res = await fetch(new Request(req, {cache:"no-store"}));
    if (res && res.ok){
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(fallbackKey || req, copy)).catch(() => {});
    }
    return res;
  }catch(err){
    const hit = await caches.match(fallbackKey || req);
    if (hit) return hit;
    throw err;
  }
}

async function cacheFirst(req){
  const hit = await caches.match(req);
  if (hit) return hit;
  try{
    const res = await fetch(req);
    if (res && res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {}); }
    return res;
  }catch(err){
    return new Response("", {status:504, statusText:"offline"});
  }
}

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;

  // Never intercept the GitHub API — sync must always see live data.
  if (new URL(req.url).origin !== self.location.origin) return;

  if (req.mode === "navigate"){
    e.respondWith(networkFirst(req, "./index.html"));
    return;
  }
  e.respondWith(IMMUTABLE.test(new URL(req.url).pathname) ? cacheFirst(req) : networkFirst(req));
});
