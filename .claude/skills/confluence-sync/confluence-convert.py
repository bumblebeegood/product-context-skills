#!/usr/bin/env python3
"""Markdown <-> Confluence storage format for confluence-sync, keeping
Confluence-only elements (macros, page links, images, mentions, layouts) intact.

  confluence-convert.py to-md   <storage.html> <out.md>   <store.json>
  confluence-convert.py to-html <in.md>        <out.html> <store.json>

to-md replaces every element Markdown cannot hold with a placeholder and saves
the element's storage XML in the store (existing entries are kept). Placeholders
are inline code spans, which WYSIWYG Markdown editors display and keep on save:

  `confluence:toc 1a2b3c4d`                          whole element, not editable
  See `confluence:link 1a2b3c4d "label"` here.       inline element
  `confluence:info 1a2b3c4d "title"`
  ...Markdown body, editable...
  `/confluence:info 1a2b3c4d`                        macro with an editable body

Code macros keep their code in a fenced block between the markers. to-html also
accepts the older HTML-comment form (<!-- confluence:toc 1a2b3c4d -->).

to-html swaps the placeholders back for the stored XML, so a push keeps the
elements where the placeholders are. Deleting a placeholder deletes the element.
Warnings go to stderr. Exit codes: 0 ok, 1 conversion error, 2 usage/setup error.
"""
import hashlib
import html
import json
import os
import re
import subprocess
import sys

PANDOC_TO_MD = ["pandoc", "-f", "html", "-t", "gfm", "--wrap=none"]
PANDOC_TO_HTML = ["pandoc", "-f", "gfm", "-t", "html", "--wrap=none", "--no-highlight"]

# Tokens survive pandoc untouched (letters and hex digits only).
TOK = "CFMARK"
TOKEN_RE = re.compile(TOK + r"(ONE|BEG|END)([0-9a-f]{8})")

# Whole-element containers: kept as one opaque element, content included.
CONTAINER_RE = re.compile(
    r"<ac:(layout|task-list|adf-extension)\b[^>]*?(?:/>|>.*?</ac:\1>)", re.S)
# Innermost macro: contains no other macro.
MACRO_RE = re.compile(
    r"<ac:structured-macro\b[^>]*?(?:/>|>(?:(?!<ac:structured-macro\b).)*?</ac:structured-macro>)",
    re.S)
# Inline elements.
INLINE_RE = re.compile(
    r"<ac:(link|image|emoticon|placeholder)\b[^>]*?(?:/>|>.*?</ac:\1>)", re.S)
# Dates are plain <time> elements pandoc would drop.
TIME_RE = re.compile(r"<time\b[^>]*?(?:/>|>.*?</time>)", re.S)

_PH = r'(/?)confluence:([\w.-]+)\s+([0-9a-f]{8})(?:\s+"[^"]*")?'
PLACEHOLDER_RE = re.compile(r"`\s*" + _PH + r"\s*`|<!--\s*" + _PH + r"\s*-->")


def fail(msg, code=1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def pandoc(args, text):
    try:
        r = subprocess.run(args, input=text, capture_output=True, text=True)
    except FileNotFoundError:
        fail("pandoc not installed (brew install pandoc)", 2)
    if r.returncode != 0:
        fail(f"pandoc failed: {r.stderr.strip()}")
    return r.stdout


def load_store(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_store(path, store):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(store, f, indent=1, ensure_ascii=False, sort_keys=True)


def attr(xml, name):
    m = re.search(r'\b' + re.escape(name) + r'="([^"]*)"', xml)
    return html.unescape(m.group(1)) if m else ""


def label_for(kind, xml):
    """Short human hint shown in the placeholder; ignored on push."""
    if kind == "link":
        body = re.sub(r"<[^>]+>", "", re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", xml, flags=re.S)).strip()
        return body or attr(xml, "ri:content-title") or (attr(xml, "ri:account-id") and "@mention")
    if kind == "image":
        return attr(xml, "ri:filename") or attr(xml, "ri:value")
    if kind == "emoticon":
        return attr(xml, "ac:name")
    if kind == "time":
        return attr(xml, "datetime")
    title = re.search(r'<ac:parameter ac:name="title">(.*?)</ac:parameter>', xml, re.S)
    return html.unescape(title.group(1)).strip() if title else ""


def is_inline(doc, pos):
    """True when pos sits inside an open paragraph or heading."""
    last = None
    for m in re.finditer(r"<(/?)(p|h[1-6])\b[^>]*>", doc[:pos]):
        last = m
    return bool(last and not last.group(1))


class Extractor:
    def __init__(self, store):
        self.store = store
        self.seen = set()
        self.names = []

    def new_id(self, xml, preferred=""):
        base = re.sub(r"[^0-9a-f]", "", preferred.lower())[:8]
        if len(base) < 8:
            base = hashlib.sha1(xml.encode()).hexdigest()[:8]
        cid, n = base, 0
        while cid in self.seen:
            n += 1
            cid = hashlib.sha1(f"{xml}{n}".encode()).hexdigest()[:8]
        self.seen.add(cid)
        return cid

    def opaque(self, doc, m, kind):
        xml = m.group(0)
        cid = self.new_id(xml, attr(xml, "ac:macro-id"))
        inline = is_inline(doc, m.start())
        self.store[cid] = {"name": kind, "kind": "one", "xml": xml, "inline": inline,
                           "label": label_for(kind, xml)}
        self.names.append(kind)
        token = f"{TOK}ONE{cid}"
        return token if inline else f"<p>{token}</p>"

    def macro(self, doc, m):
        xml = m.group(0)
        name = attr(xml, "ac:name") or "macro"
        cid = self.new_id(xml, attr(xml, "ac:macro-id"))
        self.names.append(name)
        inline = is_inline(doc, m.start())
        for body_tag, kind in (("ac:rich-text-body", "rich"), ("ac:plain-text-body", "plain")):
            b = re.search(rf"(<{body_tag}>)(.*)(</{body_tag}>)", xml, re.S)
            if b and not inline:
                body = b.group(2)
                if kind == "plain":
                    code = re.sub(r"^\s*<!\[CDATA\[|\]\]>\s*$", "", body, flags=re.S)
                    lang = re.search(r'<ac:parameter ac:name="language">([\w+#.-]+)</ac:parameter>', xml)
                    cls = lang.group(1) if lang else "text"
                    body = f'<pre><code class="language-{cls}">{html.escape(code)}</code></pre>'

                self.store[cid] = {"name": name, "kind": kind,
                                   "open": xml[:b.end(1)], "close": xml[b.start(3):],
                                   "label": label_for(name, xml)}
                return f"<p>{TOK}BEG{cid}</p>{body}<p>{TOK}END{cid}</p>"
        self.store[cid] = {"name": name, "kind": "one", "xml": xml, "inline": inline,
                           "label": label_for(name, xml)}
        token = f"{TOK}ONE{cid}"
        return token if inline else f"<p>{token}</p>"


def sub_all(regex, fn, doc):
    """Replace matches one at a time (fn needs the current document)."""
    while True:
        m = regex.search(doc)
        if not m:
            return doc
        doc = doc[:m.start()] + fn(doc, m) + doc[m.end():]


def to_md(src, dst, store_path):
    s = open(src, encoding="utf-8").read()
    store = load_store(store_path)
    ex = Extractor(store)

    # Comment highlights: keep the text. (They are re-created by Confluence only
    # while the highlighted text is unchanged; see SKILL.md.)
    highlights = len(re.findall(r"<ac:inline-comment-marker\b", s))
    s = re.sub(r"</?ac:inline-comment-marker\b[^>]*>", "", s)

    s = sub_all(CONTAINER_RE, lambda d, m: ex.opaque(d, m, m.group(1)), s)
    s = sub_all(MACRO_RE, ex.macro, s)
    s = sub_all(INLINE_RE, lambda d, m: ex.opaque(d, m, m.group(1)), s)
    s = sub_all(TIME_RE, lambda d, m: ex.opaque(d, m, "time"), s)

    # Table cells holding one paragraph: unwrap so pandoc emits a pipe table.
    s = re.sub(r"<(t[hd])([^>]*)>\s*<p[^>]*>(.*?)</p>\s*</\1>", r"<\1\2>\3</\1>", s, flags=re.S)
    s = re.sub(r"<colgroup>.*?</colgroup>", "", s, flags=re.S)

    # Header row kept inside <tbody> by Confluence: move it to <thead>.
    def lift_header(m):
        return m.group(0) if "<td" in m.group(2) else \
            f"<table{m.group(1)}><thead>{m.group(2)}</thead><tbody>"
    s = re.sub(r"<table([^>]*)>\s*<tbody>\s*(<tr[^>]*>.*?</tr>)", lift_header, s, flags=re.S)

    leftover = sorted(set(re.findall(r"<(?:ac|ri):([\w-]+)", s)))
    s = re.sub(r"</?(?:ac|ri):[^>]*>", "", s)

    md = pandoc(PANDOC_TO_MD, s)

    def placeholder(m):
        kind, cid = m.group(1), m.group(2)
        e = store[cid]
        label = e.get("label", "").replace('"', "'").replace("`", "'").replace("--", "–")
        label = f' "{label}"' if label and kind != "END" else ""
        slash = "/" if kind == "END" else ""
        return f"`{slash}confluence:{e['name']} {cid}{label}`"
    md = TOKEN_RE.sub(placeholder, md)

    with open(dst, "w", encoding="utf-8") as f:
        f.write(md)
    save_store(store_path, store)

    if ex.names:
        counts = {n: ex.names.count(n) for n in dict.fromkeys(ex.names)}
        listed = ", ".join(f"{n}×{c}" if c > 1 else n for n, c in counts.items())
        print(f"info: Confluence elements kept as placeholders: {listed}", file=sys.stderr)
    hidden = sorted({n for n in ex.names if n in ("layout", "task-list", "adf-extension")})
    if hidden:
        print(f"info: text inside {', '.join(hidden)} is kept on push but not editable locally", file=sys.stderr)
    if leftover:
        print(f"warning: unsupported Confluence markup dropped: {', '.join(leftover)}", file=sys.stderr)
    if highlights:
        print(f"info: {highlights} comment highlight(s) on the page", file=sys.stderr)


def to_html(src, dst, store_path):
    md = open(src, encoding="utf-8").read()
    md = re.sub(r"\A---[ \t]*\n.*?\n---[ \t]*\n", "", md, flags=re.S)  # frontmatter
    store = load_store(store_path)

    missing = []

    def tokenize(m):
        g = m.groups()
        end, _name, cid = g[0:3] if g[2] else g[3:6]
        if cid not in store:
            missing.append(cid)
            return m.group(0)
        kind = "END" if end else ("ONE" if store[cid]["kind"] == "one" else "BEG")
        return f"{TOK}{kind}{cid}"
    md = PLACEHOLDER_RE.sub(tokenize, md)
    if missing:
        fail(f"unknown Confluence placeholder(s) {', '.join(missing)}: "
             f"not in {store_path}; fetch the page first", 2)

    out = pandoc(PANDOC_TO_HTML, md)

    # Bodied macros: <p>BEG</p> body <p>END</p> -> open + body + close.
    def bodied(m):
        cid, body = m.group(1), m.group(2)
        e = store[cid]
        if e["kind"] == "plain":
            code = re.search(r"<code[^>]*>(.*?)</code>", body, re.S)
            # Strip any markup (e.g. highlighting spans) before unescaping the code text.
            text = html.unescape(re.sub(r"<[^>]+>", "", code.group(1) if code else body))
            body = "<![CDATA[" + text.rstrip("\n").replace("]]>", "]]]]><![CDATA[>") + "]]>"
        return e["open"] + body + e["close"]
    beg_re = re.compile(rf"<p>{TOK}BEG([0-9a-f]{{8}})</p>(.*?)<p>{TOK}END\1</p>", re.S)
    while beg_re.search(out):
        out = beg_re.sub(bodied, out)

    # Opaque elements: a paragraph holding only the token is a block element;
    # anywhere else the token is inline.
    def block(m):
        e = store[m.group(1)]
        return f"<p>{e['xml']}</p>" if e.get("inline") else e["xml"]
    out = re.sub(rf"<p>{TOK}ONE([0-9a-f]{{8}})</p>", block, out)
    out = re.sub(rf"{TOK}ONE([0-9a-f]{{8}})", lambda m: store[m.group(1)]["xml"], out)
    # pandoc's generated heading anchors; Confluence makes its own.
    out = re.sub(r'<(h[1-6]) id="[^"]*"', r"<\1", out)

    if TOK in out:
        fail("unmatched Confluence placeholder (a start marker without its end marker?)")
    with open(dst, "w", encoding="utf-8") as f:
        f.write(out)


def main():
    if len(sys.argv) != 5 or sys.argv[1] not in ("to-md", "to-html"):
        fail("usage: confluence-convert.py to-md|to-html <in> <out> <store.json>", 2)
    cmd, src, dst, store = sys.argv[1:]
    (to_md if cmd == "to-md" else to_html)(src, dst, store)


if __name__ == "__main__":
    main()
