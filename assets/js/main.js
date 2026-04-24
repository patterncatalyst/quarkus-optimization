document.querySelectorAll('pre').forEach(pre => {
  const btn = document.createElement('button');
  btn.textContent = 'Copy';
  btn.style.cssText =
    'position:absolute;top:.5rem;right:.5rem;background:#1E3A5F;color:#90A4AE;' +
    'border:none;padding:.2rem .5rem;border-radius:4px;font-size:.7rem;' +
    'cursor:pointer;font-family:inherit;transition:color .15s';
  pre.appendChild(btn);
  btn.addEventListener('click', () => {
    const text = (pre.querySelector('code') || pre).innerText;
    navigator.clipboard.writeText(text).then(() => {
      btn.textContent = '✓ Copied'; btn.style.color = '#00BCD4';
      setTimeout(() => { btn.textContent = 'Copy'; btn.style.color = '#90A4AE'; }, 2000);
    });
  });
});
