#!/usr/bin/env python3
"""Render docs/GDD.md into a single self-contained HTML page (docs/GDD.html).

Usage: scripts/build_gdd_page.py [--title "Name"] [--out path]
Reads docs/roster.json (optional) for the biome colour strip in the header.
"""
import html
import json
import re
import sys
from datetime import date
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "GDD.md"
ROSTER = ROOT / "docs" / "roster.json"
OUT = ROOT / "docs" / "GDD.html"

HEX_RE = re.compile(r"(?<![\w#])#([0-9A-Fa-f]{6})\b")


def arg(flag, default):
    if flag in sys.argv:
        return sys.argv[sys.argv.index(flag) + 1]
    return default


def render_markdown(text):
    md = markdown.Markdown(
        extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list", "md_in_html", "pymdownx.tilde"],
        extension_configs={"toc": {"toc_depth": "2-3", "permalink": False}},
    )
    body = md.convert(text)
    return body, md.toc_tokens


def mermaid_blocks(body):
    def repl(m):
        code = html.unescape(m.group(1))
        return '<pre class="mermaid">' + html.escape(code) + "</pre>"
    return re.sub(r'<pre><code class="language-mermaid">(.*?)</code></pre>', repl, body, flags=re.S)


def swatches(body):
    # Turn #RRGGBB mentions outside <code>/<pre> into colour chips.
    parts = re.split(r"(<pre.*?</pre>|<code.*?</code>)", body, flags=re.S)
    for i, p in enumerate(parts):
        if p.startswith("<pre") or p.startswith("<code"):
            continue
        parts[i] = HEX_RE.sub(lambda m: f'<span class="swatch" style="--c:#{m.group(1)}"></span><span class="hex">#{m.group(1).upper()}</span>', p)
    return "".join(parts)


def wrap_tables(body):
    return body.replace("<table>", '<div class="table-wrap"><table>').replace("</table>", "</table></div>")


def toc_html(tokens):
    out = ["<ol>"]
    for t in tokens:
        out.append(f'<li><a href="#{t["id"]}">{html.escape(t["name"])}</a>')
        kids = [c for c in t.get("children", []) if c["level"] == 3]
        if kids:
            out.append("<ol>")
            for c in kids:
                out.append(f'<li><a href="#{c["id"]}">{html.escape(c["name"])}</a></li>')
            out.append("</ol>")
        out.append("</li>")
    out.append("</ol>")
    return "".join(out)


def biome_strip():
    if not ROSTER.exists():
        return ""
    roster = json.loads(ROSTER.read_text())
    tiles = []
    for b in roster["biomes"]:
        found = HEX_RE.findall(b.get("palette", ""))
        c = "#" + (found[0] if found else "9AA79C")
        label = html.escape(f'{b["index"]}. {b["biomeName"]} ({b["difficultyLabel"]}) - {b["animal"]}')
        tiles.append(f'<span class="tile" style="--c:{c}" title="{label}"><b>{b["index"]}</b></span>')
    return '<div class="strip" aria-label="The twenty biomes in order">' + "".join(tiles) + "</div>"


def main():
    title = arg("--title", "Animal Chase Obby GDD")
    out_path = Path(arg("--out", str(OUT)))
    text = SRC.read_text(encoding="utf-8")
    body, toc = render_markdown(text)
    body = wrap_tables(swatches(mermaid_blocks(body)))
    nav = toc_html(toc)
    strip = biome_strip()
    today = date.today().isoformat()
    page = f"""<title>{html.escape(title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600;700&family=Source+Sans+3:ital,wght@0,400;0,600;0,700;1,400&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
:root {{
  --bg: #F5F7F1; --bg-2: #EBEFE4; --ink: #1B2620; --ink-2: #4B5A50; --line: #D5DCD1;
  --accent: #23895B; --accent-ink: #FFFFFF; --yolk: #E9A825; --yolk-soft: #FBEFD0;
  --code-bg: #E8ECE3; --nav-bg: #EEF2E9; --shadow: 0 1px 2px rgba(20,40,30,.08);
  --display: "Fredoka", "Trebuchet MS", "Segoe UI", sans-serif;
  --body: "Source Sans 3", "Segoe UI", Helvetica, Arial, sans-serif;
  --mono: "JetBrains Mono", "Cascadia Mono", Consolas, monospace;
  color-scheme: light;
}}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --bg: #111814; --bg-2: #18211C; --ink: #E6ECE5; --ink-2: #A9B7AC; --line: #2B3730;
    --accent: #52C58B; --accent-ink: #0B1A12; --yolk: #F3C04E; --yolk-soft: #3A2F10;
    --code-bg: #1C2620; --nav-bg: #151D18; --shadow: 0 1px 2px rgba(0,0,0,.4); color-scheme: dark;
  }}
}}
:root[data-theme="dark"] {{
  --bg: #111814; --bg-2: #18211C; --ink: #E6ECE5; --ink-2: #A9B7AC; --line: #2B3730;
  --accent: #52C58B; --accent-ink: #0B1A12; --yolk: #F3C04E; --yolk-soft: #3A2F10;
  --code-bg: #1C2620; --nav-bg: #151D18; --shadow: 0 1px 2px rgba(0,0,0,.4); color-scheme: dark;
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 17px; line-height: 1.55; }}
.wrap {{ max-width: 1240px; margin: 0 auto; padding-inline: 16px; padding-block: 0 64px; }}
header.hero {{ padding-block: 40px 20px; border-bottom: 2px solid var(--line); }}
.eyebrow {{ font-family: var(--mono); font-size: 12px; letter-spacing: .14em; text-transform: uppercase; color: var(--accent); margin: 0 0 8px; }}
h1 {{ font-family: var(--display); font-weight: 700; font-size: clamp(34px, 5vw, 56px); line-height: 1.02; margin: 0 0 12px; text-wrap: balance; letter-spacing: -.01em; }}
.meta {{ display: flex; flex-wrap: wrap; gap: 8px 20px; color: var(--ink-2); font-size: 15px; margin: 0 0 18px; }}
.meta b {{ color: var(--ink); font-weight: 600; }}
.strip {{ display: flex; gap: 4px; flex-wrap: wrap; }}
.tile {{ --c: #999; flex: 1 1 36px; min-width: 36px; height: 34px; border-radius: 6px; background: var(--c); display: grid; place-items: center; color: #fff; font-family: var(--mono); font-size: 12px; font-weight: 600; text-shadow: 0 1px 2px rgba(0,0,0,.45); box-shadow: inset 0 0 0 1px rgba(0,0,0,.12); }}
.layout {{ display: grid; grid-template-columns: 260px minmax(0, 1fr); gap: 40px; align-items: start; padding-top: 28px; }}
nav.toc {{ position: sticky; top: env(safe-area-inset-top, 0px); max-height: 100vh; overflow: auto; padding: 14px 14px 24px; background: var(--nav-bg); border: 1px solid var(--line); border-radius: 10px; font-size: 14px; }}
nav.toc summary {{ font-family: var(--display); font-weight: 600; font-size: 15px; cursor: pointer; list-style: none; }}
nav.toc summary::-webkit-details-marker {{ display: none; }}
nav.toc ol {{ list-style: none; margin: 8px 0 0; padding: 0; }}
nav.toc ol ol {{ margin: 2px 0 6px 12px; border-left: 1px solid var(--line); padding-left: 10px; }}
nav.toc li {{ margin: 0; }}
nav.toc a {{ display: block; padding: 4px 6px; color: var(--ink-2); text-decoration: none; border-radius: 5px; }}
nav.toc > ol > li > a {{ color: var(--ink); font-weight: 600; }}
nav.toc a:hover, nav.toc a:focus-visible {{ background: var(--bg-2); color: var(--accent); outline: none; }}
article {{ min-width: 0; }}
article > * {{ max-width: 78ch; }}
article h2 {{ font-family: var(--display); font-weight: 600; font-size: 30px; line-height: 1.15; margin: 56px 0 14px; padding-top: 18px; border-top: 2px solid var(--line); scroll-margin-top: 16px; text-wrap: balance; }}
article h2:first-child {{ margin-top: 0; border-top: 0; padding-top: 0; }}
article h3 {{ font-family: var(--display); font-weight: 600; font-size: 22px; margin: 34px 0 8px; scroll-margin-top: 16px; text-wrap: balance; }}
article h4 {{ font-family: var(--body); font-weight: 700; font-size: 16px; letter-spacing: .02em; text-transform: uppercase; color: var(--ink-2); margin: 24px 0 6px; }}
article p, article li {{ max-width: 72ch; }}
article a {{ color: var(--accent); }}
article strong {{ font-weight: 700; }}
article blockquote {{ margin: 16px 0; padding: 10px 16px; border-left: 4px solid var(--yolk); background: var(--yolk-soft); border-radius: 0 8px 8px 0; }}
article blockquote p {{ margin: 0; }}
article hr {{ border: 0; border-top: 1px solid var(--line); margin: 32px 0; }}
code, pre {{ font-family: var(--mono); font-size: 14px; }}
:not(pre) > code {{ background: var(--code-bg); padding: 1px 6px; border-radius: 4px; }}
pre {{ background: var(--code-bg); padding: 14px 16px; border-radius: 8px; overflow-x: auto; max-width: 100%; line-height: 1.45; }}
pre.mermaid {{ background: var(--bg-2); border: 1px solid var(--line); }}
.table-wrap {{ max-width: 100%; overflow-x: auto; margin: 14px 0 22px; border: 1px solid var(--line); border-radius: 8px; box-shadow: var(--shadow); }}
table {{ border-collapse: collapse; width: 100%; font-size: 15px; font-variant-numeric: tabular-nums; }}
th, td {{ padding: 8px 12px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }}
th {{ background: var(--bg-2); font-weight: 700; white-space: nowrap; }}
tbody tr:last-child td {{ border-bottom: 0; }}
.swatch {{ --c: #999; display: inline-block; width: 13px; height: 13px; border-radius: 3px; background: var(--c); vertical-align: -1px; margin-right: 4px; box-shadow: inset 0 0 0 1px rgba(0,0,0,.18); }}
.hex {{ font-family: var(--mono); font-size: 13px; }}
footer {{ margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--line); color: var(--ink-2); font-size: 14px; }}
@media (max-width: 860px) {{
  .layout {{ grid-template-columns: 1fr; gap: 20px; }}
  nav.toc {{ position: static; max-height: none; }}
  nav.toc:not([open]) ol {{ display: none; }}
  body {{ font-size: 16px; }}
}}
@media (min-width: 861px) {{ nav.toc summary {{ pointer-events: none; }} }}
@media (prefers-reduced-motion: no-preference) {{ html {{ scroll-behavior: smooth; }} }}
</style>
<div class="wrap">
  <header class="hero">
    <p class="eyebrow">Game Design Document</p>
    <h1>{html.escape(title)}</h1>
    <p class="meta"><span>Version <b>1.0</b></span><span>Date <b>{today}</b></span><span>Scope <b>20 biomes, 200 stages, 20 animals</b></span><span>Status <b>Pre-production</b></span></p>
    {strip}
  </header>
  <div class="layout">
    <nav class="toc"><details open><summary>Contents</summary>{nav}</details></nav>
    <article>
{body}
      <footer>Source of truth for numbers: <code>docs/roster.json</code> and the generated <code>Biomes.luau</code>. Regenerate this page with <code>scripts/build_gdd_page.py</code>.</footer>
    </article>
  </div>
</div>
"""
    out_path.write_text(page, encoding="utf-8")
    print(f"wrote {out_path} ({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
