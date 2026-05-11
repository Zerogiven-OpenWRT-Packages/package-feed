#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { marked } from 'marked';
import { renderPage } from './pages-template.mjs';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const OUT = path.join(ROOT, 'dist');

const REPO = process.env.GITHUB_REPOSITORY || detectRepoFromGit();
const BRANCH = 'main';
const RAW_BASE = `https://raw.githubusercontent.com/${REPO}/${BRANCH}`;
const PAGES_URL = (process.env.PAGES_URL || '').replace(/\/$/, '');

const HARD_EXCLUDE_DIRS = new Set([
  '.git', '.github', '.scripts', '.claude', 'dist', 'node_modules', 'web',
]);

function shouldInclude(relPath, name, isDir) {
  if (name === '.gitkeep' || name === '.gitignore') return false;
  if (name === 'CLAUDE.md' || name === 'README.md') return false;
  return true;
}

function detectRepoFromGit() {
  try {
    const url = execFileSync('git', ['remote', 'get-url', 'origin'], { cwd: ROOT }).toString().trim();
    const m = url.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?$/);
    return m ? m[1] : 'unknown/unknown';
  } catch {
    return 'unknown/unknown';
  }
}

function loadMtimes() {
  const raw = execFileSync(
    'git',
    ['log', '--name-only', '--diff-filter=AMRC', '--pretty=format:%x00%cI'],
    { cwd: ROOT, maxBuffer: 256 * 1024 * 1024 },
  ).toString('utf8');

  const mtimes = new Map();
  let currentDate = null;
  for (const line of raw.split('\n')) {
    if (line.startsWith('\x00')) {
      currentDate = line.slice(1);
    } else if (line && currentDate && !mtimes.has(line)) {
      mtimes.set(line, currentDate);
    }
  }
  return mtimes;
}

function walkTree(absDir, relDir, mtimes) {
  const entries = fs.readdirSync(absDir, { withFileTypes: true });
  const children = [];

  for (const entry of entries) {
    if (HARD_EXCLUDE_DIRS.has(entry.name)) continue;

    const relPath = relDir ? `${relDir}/${entry.name}` : entry.name;
    const absPath = path.join(absDir, entry.name);
    const isDir = entry.isDirectory();

    if (!shouldInclude(relPath, entry.name, isDir)) continue;

    const stat = fs.statSync(absPath);
    const pathObj = {
      name: entry.name,
      relPath,
      size: stat.size,
      mtime: mtimes.get(relPath) || null,
    };

    if (isDir) {
      const sub = walkTree(absPath, relPath, mtimes);
      children.push({ ...pathObj, ...{
        type: 'dir',
        children: sub,
      }});
    } else {
      children.push({ ...pathObj, ...{
        type: 'file',
      }});
    }
  }

  children.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'dir' ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  return children;
}

function emitPage(children, relPath, breadcrumb, extraHtml) {
  const outDir = relPath ? path.join(OUT, relPath) : OUT;
  fs.mkdirSync(outDir, { recursive: true });

  const html = renderPage({
    relPath,
    breadcrumb,
    children,
    extraHtml,
    rawBase: RAW_BASE,
    pagesUrl: PAGES_URL,
    repo: REPO,
  });

  fs.writeFileSync(path.join(outDir, 'index.html'), html);
}

function emitDirRecursive(children, relPath, breadcrumb, rootExtra) {
  emitPage(children, relPath, breadcrumb, relPath === '' ? rootExtra : '');
  for (const child of children) {
    if (child.type === 'dir') {
      const nextCrumb = [...breadcrumb, { name: child.name, relPath: child.relPath }];
      emitDirRecursive(child.children, child.relPath, nextCrumb, '');
    }
  }
}

function collectDirPaths(children, acc = ['']) {
  for (const c of children) {
    if (c.type === 'dir') {
      acc.push(c.relPath);
      collectDirPaths(c.children, acc);
    }
  }
  return acc;
}

function emitSitemap(children) {
  if (!PAGES_URL) return; // skip if URL not known (local dry-run)
  const dirs = collectDirPaths(children);
  const xml =
    '<?xml version="1.0" encoding="UTF-8"?>\n' +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
    dirs.map((d) => {
      const loc = d ? `${PAGES_URL}/${d}/` : `${PAGES_URL}/`;
      return `  <url><loc>${loc}</loc></url>`;
    }).join('\n') +
    '\n</urlset>\n';
  fs.writeFileSync(path.join(OUT, 'sitemap.xml'), xml);
}

function emitRobots() {
  const sitemapLine = PAGES_URL ? `\nSitemap: ${PAGES_URL}/sitemap.xml\n` : '\n';
  fs.writeFileSync(path.join(OUT, 'robots.txt'), `User-agent: *\nAllow: /\n${sitemapLine}`);
}

function copyStaticAssets() {
  const webDir = path.join(ROOT, 'web');
  for (const file of ['style.css', 'app.js']) {
    const src = path.join(webDir, file);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(OUT, file));
    }
  }
}

function renderReadme() {
  const readmePath = path.join(ROOT, 'README.md');
  if (!fs.existsSync(readmePath)) return '';
  const md = fs.readFileSync(readmePath, 'utf8');
  let text = marked.parse(md);
  
  const index = text.indexOf('<h2>Available Packages</h2>');
  if (index !== -1) {
      text = text.slice(0, index);
  }

  return `
    <section class="readme">
      <article class="markdown-body" itemprop="text">
        ${text}
      </article>
    </section>`;
}

function countFiles(children) {
  let n = 0;
  for (const c of children) {
    if (c.type === 'file') n++;
    else n += countFiles(c.children);
  }
  return n;
}

function main() {
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });

  console.log(`Building site for ${REPO} → ${OUT}`);
  console.log(`Pages URL: ${PAGES_URL || '(unset — sitemap will be skipped)'}`);

  const mtimes = loadMtimes();
  console.log(`Loaded mtimes for ${mtimes.size} paths from git log`);

  const tree = walkTree(ROOT, '', mtimes);
  const fileCount = countFiles(tree);
  const dirCount = collectDirPaths(tree).length;
  console.log(`Tree contains ${dirCount} directories and ${fileCount} files`);

  emitDirRecursive(tree, '', [], renderReadme());
  emitSitemap(tree);
  emitRobots();
  copyStaticAssets();

  console.log('Done.');
}

main();
