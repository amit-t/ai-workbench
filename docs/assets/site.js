(function () {
  // ===== THEME TOGGLE =====
  var toggle = document.getElementById('theme-toggle');
  var root = document.body;
  var stored = null;
  try { stored = localStorage.getItem('wb-theme'); } catch (_) {}
  var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  var isDark = stored ? stored === 'dark' : prefersDark;
  applyTheme(isDark);

  if (toggle) {
    toggle.addEventListener('click', function () {
      isDark = !root.classList.contains('dark');
      applyTheme(isDark);
      try { localStorage.setItem('wb-theme', isDark ? 'dark' : 'light'); } catch (_) {}
    });
  }

  function applyTheme(dark) {
    if (dark) {
      root.classList.add('dark');
      if (toggle) toggle.textContent = '☀';
    } else {
      root.classList.remove('dark');
      if (toggle) toggle.textContent = '☾';
    }
  }

  // ===== COPY BUTTONS ON <pre> =====
  var pres = document.querySelectorAll('pre');
  pres.forEach(function (pre) {
    if (pre.querySelector('.copy-btn')) return;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-btn';
    btn.textContent = 'Copy';
    btn.addEventListener('click', function () {
      var text = pre.innerText.replace(/^Copy\s*/, '');
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () {
          flash(btn);
        }, function () {
          fallbackCopy(text, btn);
        });
      } else {
        fallbackCopy(text, btn);
      }
    });
    pre.appendChild(btn);
  });

  function fallbackCopy(text, btn) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); flash(btn); } catch (_) {}
    document.body.removeChild(ta);
  }

  function flash(btn) {
    var orig = btn.textContent;
    btn.classList.add('copied');
    btn.textContent = 'Copied';
    setTimeout(function () {
      btn.classList.remove('copied');
      btn.textContent = orig;
    }, 1400);
  }
})();
