// Scrape and open in new tab list of youtube links on current page
// paste into dev tools

(() => {
  const links = new Set();

  document.querySelectorAll('a[href]').forEach(a => {
    try {
      const u = new URL(a.href);
      let id = null;
      const host = u.hostname.toLowerCase();

      if (host === 'youtube.com' || host.endsWith('.youtube.com')) {
        if (u.pathname === '/watch')
          id = u.searchParams.get('v');
        else if (/^\/(shorts|live|embed)\//.test(u.pathname))
          id = u.pathname.split('/')[2];
      } else if (host === 'youtu.be') {
        id = u.pathname.split('/')[1];
      }

      if (/^[\w-]{11}$/.test(id || ''))
        links.add(`https://www.youtube.com/watch?v=${id}`);
    } catch {}
  });

  const tab = window.open('', '_blank');

  if (!tab) {
    console.warn('Popup blocked. Allow popups and retry.');
    return;
  }

  const doc = tab.document;
  doc.title = 'YouTube Video Links';

  const style = doc.createElement('style');
  style.textContent = `
    body { background:#10141c; color:#eee; font:15px Arial;
           padding:35px; max-width:1100px; margin:auto; }
    h2 { color:#fff; }
    a { display:block; color:#79b8ff; padding:9px 0;
        text-decoration:none; border-bottom:1px solid #293241;
        overflow-wrap:anywhere; }
    a:hover { color:white; }
  `;
  doc.head.appendChild(style);

  const heading = doc.createElement('h2');
  heading.textContent = `YouTube Video Links (${links.size})`;
  doc.body.appendChild(heading);

  links.forEach(url => {
    const a = doc.createElement('a');
    a.href = url;
    a.textContent = url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    doc.body.appendChild(a);
  });

  console.log(`Opened ${links.size} unique links in a new tab.`);
})();
