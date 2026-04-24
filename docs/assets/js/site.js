(function () {
  'use strict';

  // ===== THEME TOGGLE =====
  const THEME_KEY = 'wb-theme';
  const root = document.body;
  const toggle = document.getElementById('theme-toggle');

  function apply(theme) {
    if (theme === 'dark') {
      root.classList.add('dark');
      if (toggle) toggle.textContent = '☀️';
    } else {
      root.classList.remove('dark');
      if (toggle) toggle.textContent = '🌙';
    }
  }

  const stored = localStorage.getItem(THEME_KEY);
  const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  apply(stored || (prefersDark ? 'dark' : 'light'));

  if (toggle) {
    toggle.addEventListener('click', function () {
      const next = root.classList.contains('dark') ? 'light' : 'dark';
      localStorage.setItem(THEME_KEY, next);
      apply(next);
    });
  }

  // ===== COPY BUTTONS ON <pre> =====
  function attachCopyButtons() {
    const pres = document.querySelectorAll('.markdown-body pre');
    pres.forEach(function (pre) {
      if (pre.querySelector('.copy-btn')) return;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'copy-btn';
      btn.setAttribute('aria-label', 'Copy code');
      btn.textContent = 'COPY';
      btn.addEventListener('click', function () {
        const code = pre.querySelector('code') || pre;
        const text = code.innerText;
        navigator.clipboard.writeText(text).then(function () {
          btn.textContent = 'COPIED';
          btn.classList.add('copied');
          setTimeout(function () {
            btn.textContent = 'COPY';
            btn.classList.remove('copied');
          }, 1600);
        });
      });
      pre.appendChild(btn);
    });
  }
  attachCopyButtons();
})();
