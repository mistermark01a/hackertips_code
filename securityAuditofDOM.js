// Generate a security audit of current DOM - paste into console
// make sure to unblock popupblocker
// https://hackertips.today

(() => {
  const scripts = [
    ...document.querySelectorAll('script[src]')
  ].filter(s => /ruxitagentjs/i.test(s.src));

  console.table(scripts.map(s => {
    const file = s.src.split('/').pop();
    const match = file.match(/_(\d+)\.js/i);
    const build = match?.[1] || 'unknown';

    return {
      filename: file,
      build,
      possibleVersion: build.length >= 5
        ? `1.${parseInt(build.slice(2, 5), 10)}`
        : 'unknown',
      url: s.src
    };
  }));

  console.log('Dynatrace API:', typeof window.dtrum);
})();
