// Per LI post - 11/09/2026 - https://tinyurl.com/hackertipsblockLItelem
// Blocks (per session) LI hits to /li/track
// paste into dev tools / console while on LI .. for a long term solution block the path with uOrigin

(() => {
  const blocked = u => {
    try { return new URL(String(u), location.href).pathname === '/li/track'; }
    catch { return false; }
  };

  const oldFetch = window.fetch;
  window.fetch = function(input, init) {
    const url = typeof input === 'string' ? input : input?.url;
    if (blocked(url)) {
      console.warn('[BLOCKED fetch]', url);
      return Promise.resolve(new Response('', {status: 204}));
    }
    return oldFetch.apply(this, arguments);
  };

  const oldOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__blockedURL = blocked(url);
    if (this.__blockedURL) console.warn('[BLOCKED XHR]', url);
    return oldOpen.apply(this, arguments);
  };

  const oldSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    if (this.__blockedURL) {
      this.abort();
      return;
    }
    return oldSend.apply(this, arguments);
  };

  const oldBeacon = navigator.sendBeacon?.bind(navigator);
  if (oldBeacon) {
    navigator.sendBeacon = function(url, data) {
      if (blocked(url)) {
        console.warn('[BLOCKED beacon]', url);
        return true;
      }
      return oldBeacon(url, data);
    };
  }

  console.log('Blocking /li/track');
})();
