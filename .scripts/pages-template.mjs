export function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function formatSize(bytes) {
  if (bytes == null) return '';
  if (bytes < 1000) return `${bytes} B`;
  const units = ['kB', 'MB', 'GB', 'TB'];
  let n = bytes / 1000;
  let i = 0;
  while (n >= 1000 && i < units.length - 1) { n /= 1000; i++; }
  return `${n.toFixed(n < 10 ? 1 : 0)} ${units[i]}`;
}

function formatDate(iso) {
  if (!iso) return '';
  return iso.slice(0, 10); // YYYY-MM-DD
}

function renderBreadcrumb(breadcrumb, depth) {
  const home = `<a href="${'../'.repeat(depth) || './'}">feed</a>`;
  if (breadcrumb.length === 0) return `<nav class="crumbs">${home}</nav>`;
  const parts = breadcrumb.map((seg, i) => {
    const back = depth - i - 1;
    const href = back === 0 ? './' : '../'.repeat(back);
    return `<a href="${href}">${escapeHtml(seg.name)}</a>`;
  });
  return `<nav class="crumbs">${home} <span class="sep">/</span> ${parts.join(' <span class="sep">/</span> ')}</nav>`;
}

function renderRow(child, depth, rawBase) {
  if (child.type === 'dir') {
    return `<tr data-type="dir" data-name="${escapeHtml(child.name)}" data-size="-1" data-mtime="">
      <td class="name"><a href="${escapeHtml(child.name)}/">📁 ${escapeHtml(child.name)}/</a></td>
      <td class="size">—</td>
      <td class="mtime"></td>
    </tr>`;
  }
  const rawUrl = `${rawBase}/${child.relPath.split('/').map(encodeURIComponent).join('/')}`;
  return `<tr data-type="file" data-name="${escapeHtml(child.name)}" data-size="${child.size}" data-mtime="${escapeHtml(child.mtime || '')}">
      <td class="name"><a href="${escapeHtml(rawUrl)}">📄 ${escapeHtml(child.name)}</a></td>
      <td class="size">${escapeHtml(formatSize(child.size))}</td>
      <td class="mtime">${escapeHtml(formatDate(child.mtime))}</td>
    </tr>`;
}

export function renderPage({ relPath, breadcrumb, children, extraHtml, rawBase, pagesUrl, repo }) {
  const depth = relPath ? relPath.split('/').length : 0;
  const cssPath = `${'../'.repeat(depth)}style.css` || 'style.css';
  const jsPath = `${'../'.repeat(depth)}app.js` || 'app.js';

  const title = relPath
    ? `${relPath} · ${repo}`
    : repo;

  const description = relPath
    ? `OpenWRT package feed listing for ${relPath}`
    : `OpenWRT package feed — browse pre-built .ipk and .apk packages for ${repo}.`;

  const canonical = pagesUrl
    ? (relPath ? `${pagesUrl}/${relPath}/` : `${pagesUrl}/`)
    : null;

  const rows = children.length
    ? children.map((c) => renderRow(c, depth, rawBase)).join('\n')
    : `<tr><td colspan="3" class="empty">(empty directory)</td></tr>`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
${canonical ? `<link rel="canonical" href="${escapeHtml(canonical)}">` : ''}
<link rel="stylesheet" href="${escapeHtml(cssPath)}">
</head>
<body>
<header>
<h1><a href="${'../'.repeat(depth) || './'}">${escapeHtml(repo)}</a></h1>
${renderBreadcrumb(breadcrumb, depth)}
</header>
<main>
<section class="listing-wrap">
<div class="toolbar">
<input id="filter" type="search" placeholder="Filter by name…" aria-label="Filter listing">
</div>
<table class="listing">
<thead>
<tr>
<th data-sort="name">Name</th>
<th data-sort="size">Size</th>
<th data-sort="mtime">Modified</th>
</tr>
</thead>
<tbody>
${rows}
</tbody>
</table>
</section>
${extraHtml || ''}
</main>
<footer>
<p><a href="https://github.com/${escapeHtml(repo)}">Setup feed</a></p>
<p>Generated from <a href="https://github.com/${escapeHtml(repo)}">${escapeHtml(repo)}</a> · files link to <code>raw.githubusercontent.com</code> on <code>main</code>.</p>
</footer>
<script src="${escapeHtml(jsPath)}" defer></script>
</body>
</html>
`;
}
