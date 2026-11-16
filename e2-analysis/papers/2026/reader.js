(() => {
  'use strict';
  const pages = [...document.querySelectorAll('#spread > .paper')];
  const groups = [[0], ...Array.from({ length: Math.ceil((pages.length - 1) / 2) }, (_, i) =>
    [i * 2 + 1, i * 2 + 2].filter(p => p < pages.length))];
  const spread = document.getElementById('spread');
  const previous = document.getElementById('prevPage');
  const next = document.getElementById('nextPage');
  let index = 0;
  const readHash = () => {
    const match = location.hash.match(/^#spread=(\d+)$/);
    return match ? Math.min(groups.length - 1, Number(match[1])) : 0;
  };
  function fit() {
    const fullscreen = Boolean(document.fullscreenElement) ||
      (innerHeight >= screen.availHeight - 24 && outerHeight - innerHeight < 55);
    document.documentElement.classList.toggle('browser-fullscreen', fullscreen);
    const width = groups[index].length * 535.748 * 96 / 72 + (groups[index].length === 2 ? 24 : 0) + 32;
    document.documentElement.style.setProperty('--fullscreen-paper-zoom', String(Math.min(1, (innerWidth - 16) / width)));
  }
  function render() {
    pages.forEach((page, n) => { page.hidden = !groups[index].includes(n); });
    spread.classList.toggle('single', groups[index].length === 1);
    document.getElementById('spreadLabel').textContent = index === 0 ? '封面' : `第 ${groups[index].join('—')} 页`;
    previous.disabled = index === 0;
    next.disabled = index === groups.length - 1;
    fit();
  }
  function go(delta) {
    const target = Math.max(0, Math.min(groups.length - 1, index + delta));
    if (target === index) return;
    index = target;
    try {
      history.replaceState(null, '', '#spread=' + index);
    } catch (_) {
      // Some local-file viewers restrict the History API but allow fragment navigation.
      location.hash = 'spread=' + index;
    }
    render();
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
      spread.animate([{ opacity: .5, transform: `translateX(${delta > 0 ? 20 : -20}px)` },
        { opacity: 1, transform: 'translateX(0)' }], { duration: 240, easing: 'ease-out' });
    }
  }
  previous.addEventListener('click', () => go(-1));
  next.addEventListener('click', () => go(1));
  document.addEventListener('keydown', event => {
    if (event.isComposing || event.ctrlKey || event.metaKey || event.altKey ||
        event.target?.closest?.('input,textarea,select,[contenteditable]')) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault(); go(event.key === 'ArrowRight' ? 1 : -1);
    } else if (event.key.toLowerCase() === 'f' && !event.repeat) {
      event.preventDefault();
      const unavailable = () => {
        const status = document.getElementById('fullscreenStatus');
        status.textContent = '当前预览不允许网页全屏，请在浏览器标签页中打开后按 F。';
        status.classList.add('visible');
        setTimeout(() => status.classList.remove('visible'), 5000);
      };
      try {
        const action = document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen();
        Promise.resolve(action).catch(unavailable);
      } catch (_) { unavailable(); }
    }
  });
  window.addEventListener('hashchange', () => { index = readHash(); render(); });
  window.addEventListener('resize', fit);
  document.addEventListener('fullscreenchange', fit);
  index = readHash(); render();
})();
