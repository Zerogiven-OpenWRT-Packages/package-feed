import prettyBytes from 'pretty-bytes';

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDate(iso) {
  if (!iso) return '-';
  const date = new Date(iso);
  return `${date.toDateString()} ${date.toLocaleTimeString()}`;
}

function renderBreadcrumb(breadcrumb, depth) {
  const home = `Index of <a href="${'../'.repeat(depth) || './'}"><i>(root)</i></a>`;
  if (breadcrumb.length === 0) return `<nav class="crumbs">${home}</nav>`;
  const parts = breadcrumb.map((seg, i) => {
    const back = depth - i - 1;
    const href = back === 0 ? './' : '../'.repeat(back);
    return `<a href="${href}">${escapeHtml(seg.name)}</a>`;
  });
  return `<nav class="crumbs">${home} <span class="sep">/</span> ${parts.join(' <span class="sep">/</span> ')}</nav>`;
}

function renderRow(child, depth, rawBase) {
  console.log('child', child, depth, rawBase);

  if (child.type === 'dir') {
    return `<tr data-type="dir" data-name="${escapeHtml(child.name)}" data-size="-1" data-mtime="${escapeHtml(child.mtime || '')}">
      <td class="name"><a href="${escapeHtml(child.name)}/">📁 ${escapeHtml(child.name)}/</a></td>
      <td class="size">-</td>
      <td class="mtime">${escapeHtml(formatDate(child.mtime))}</td>
    </tr>`;
  }
  const rawUrl = `${rawBase}/${child.relPath.split('/').map(encodeURIComponent).join('/')}`;
  return `<tr data-type="file" data-name="${escapeHtml(child.name)}" data-size="${child.size}" data-mtime="${escapeHtml(child.mtime || '')}">
      <td class="name"><a href="${escapeHtml(rawUrl)}">📄 ${escapeHtml(child.name)}</a></td>
      <td class="size">${escapeHtml(prettyBytes(child.size))}</td>
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
    : `OpenWRT package feed - browse pre-built .ipk and .apk packages for ${repo}.`;

  const canonical = pagesUrl
    ? (relPath ? `${pagesUrl}/${relPath}/` : `${pagesUrl}/`)
    : null;

  const rows = children.length
    ? children.map((c) => renderRow(c, depth, rawBase)).join('\n')
    : `<tr><td colspan="3" class="empty">(empty directory)</td></tr>`;

    // <h1><a href="${'../'.repeat(depth) || './'}">${escapeHtml(repo)}</a></h1>
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
<th data-sort="name" style="width: 60%;"><div>Name</div></th>
<th data-sort="size" style="width: 12%;"><div>Size</div></th>
<th data-sort="mtime"><div>Modified</div></th>
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
<p>Generated from <a href="https://github.com/${escapeHtml(repo)}">${escapeHtml(repo)}</a> · files link to <code>raw.githubusercontent.com</code> on <code>main</code>.</p>
</footer>
<script src="${escapeHtml(jsPath)}" defer></script>
</body>
</html>
`;
}
