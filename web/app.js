(() => {
  const filter = document.getElementById('filter');
  const thead = document.querySelector('table.listing thead tr');
  const tbody = document.querySelector('table.listing tbody');
  if (!tbody) return;

  if (filter) {
    filter.addEventListener('input', () => {
      const q = filter.value.trim().toLowerCase();
      for (const row of tbody.children) {
        const name = (row.dataset.name || '').toLowerCase();
        row.hidden = q !== '' && !name.includes(q);
      }
    });
  }

  const sortState = { key: 'name', dir: 'asc' };

  function updateHeaders() {
      const headers = Array.from(thead.children);
      for (const header of headers) {
        header.dataset.dir = '';

        if (sortState.key === header.dataset.sort) {
          header.dataset.dir = sortState.dir;
        }
      }
  }

  function sortBy(key) {
    sortState.dir = sortState.key === key && sortState.dir === 'asc' ? 'desc' : 'asc';
    sortState.key = key;

    updateHeaders();

    const rows = Array.from(tbody.children).filter((r) => r.dataset.type);
    rows.sort((a, b) => {
      // Directories always sort before files regardless of column.
      const dirA = a.dataset.type === 'dir';
      const dirB = b.dataset.type === 'dir';
      if (dirA !== dirB) return dirA ? -1 : 1;

      const va = a.dataset[key] || '';
      const vb = b.dataset[key] || '';
      let cmp;
      if (key === 'size') cmp = Number(va) - Number(vb);
      else cmp = va.localeCompare(vb);
      return sortState.dir === 'asc' ? cmp : -cmp;
    });

    for (const row of rows) tbody.appendChild(row);
  }

  for (const th of document.querySelectorAll('table.listing th[data-sort]')) {
    th.addEventListener('click', () => sortBy(th.dataset.sort));
  }

  tbody.addEventListener('click', async (e) => {
    const t = e.target.closest('.sha-copy');
    if (!t) return;
    try {
      await navigator.clipboard.writeText(t.dataset.sha);
      const original = t.title;
      t.title = 'Copied!';
      setTimeout(() => { t.title = original; }, 1200);
    } catch {}
  });

  updateHeaders();
})();
