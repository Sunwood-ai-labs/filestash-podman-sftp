"""results/ の実測値から、記事・README用のグラフ（SVG）を作る。

使い方（リポジトリ直下で）: python assets/make_charts.py
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def rows(path):
    with open(ROOT / path, encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


INK, SUB, GRID, TRACK, ACCENT, CARD = '#111827', '#6B7280', '#D1D5DB', '#EEF0F2', '#0F766E', '#FFFFFF'
FONT = "font-family=\"'Segoe UI','Hiragino Sans','Yu Gothic UI','Meiryo','Noto Sans JP',sans-serif\""
W = 880


def frame(h, title, subtitle, body):
    return '\n'.join([
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {h}" width="{W}" height="{h}" role="img" aria-label="{title}" {FONT}>',
        f'<rect x="0.5" y="0.5" width="{W - 1}" height="{h - 1}" rx="12" fill="{CARD}" stroke="{GRID}"/>',
        f'<text x="32" y="44" font-size="20" font-weight="700" fill="{INK}">{title}</text>',
        f'<text x="32" y="70" font-size="13.5" fill="{SUB}">{subtitle}</text>',
        *body, '</svg>'])


def write(name, svg):
    (ROOT / 'assets' / name).write_text(svg, encoding='utf-8', newline='\n')
    print('wrote', name)


def mark(cx, cy, status):
    """確認できた＝塗り、注記あり＝二重丸、確認できなかった＝白抜きに×。色に頼らず形でも区別する。"""
    if status == 'confirmed':
        return [f'<circle cx="{cx}" cy="{cy}" r="8" fill="{ACCENT}"/>']
    if status == 'confirmed_with_note':
        return [f'<circle cx="{cx}" cy="{cy}" r="7" fill="{CARD}" stroke="{ACCENT}" stroke-width="2"/>',
                f'<circle cx="{cx}" cy="{cy}" r="3" fill="{ACCENT}"/>']
    return [f'<circle cx="{cx}" cy="{cy}" r="7" fill="{CARD}" stroke="{INK}" stroke-width="2"/>',
            f'<path d="M{cx - 3} {cy - 3}l6 6M{cx + 3} {cy - 3}l-6 6" stroke="{INK}" stroke-width="2"/>']


# ---- 1. 操作ごとの結果 ----
ops = load('results/operations.json')['operations']
n = len(ops)
ok = sum(o['status'] != 'unconfirmed' for o in ops)
noted = sum(o['status'] == 'confirmed_with_note' for o in ops)
groups = []
for o in ops:
    if o['group'] not in groups:
        groups.append(o['group'])
cols = [groups[:2], groups[2:]]
colx = [32, 456]
rh, gh, y0 = 38, 34, 150
lx, ly = 32, 104
body = [
    *mark(lx + 8, ly, 'confirmed'), f'<text x="{lx + 24}" y="{ly + 5}" font-size="12.5" fill="{INK}">確認できた</text>',
    *mark(lx + 130, ly, 'confirmed_with_note'), f'<text x="{lx + 146}" y="{ly + 5}" font-size="12.5" fill="{INK}">確認できたが注記あり</text>',
    *mark(lx + 316, ly, 'unconfirmed'), f'<text x="{lx + 332}" y="{ly + 5}" font-size="12.5" fill="{INK}">確認できなかった</text>',
]
bottoms = []
for x, gs in zip(colx, cols):
    y = y0
    for g in gs:
        items = [o for o in ops if o['group'] == g]
        body += [
            f'<text x="{x}" y="{y}" font-size="13" font-weight="700" fill="{SUB}">{g}</text>',
            f'<line x1="{x}" x2="{x + 392}" y1="{y + 9}" y2="{y + 9}" stroke="{GRID}"/>',
        ]
        y += gh
        for o in items:
            body += mark(x + 9, y, o['status'])
            body.append(f'<text x="{x + 28}" y="{y - 1}" font-size="14" fill="{INK}">{o["name"]}</text>')
            if o['note']:
                body.append(f'<text x="{x + 28}" y="{y + 15}" font-size="11.5" fill="{SUB}">{o["note"]}</text>')
            y += rh
        y += 14
    bottoms.append(y)
write('chart-operations.svg', frame(
    max(bottoms) - 8, f'{n}の操作のうち{ok}を確認。確認できなかったのは{n - ok}つ',
    f'Filestash {load("results/operations.json")["filestash_ui_version"]} をSFTPサーバーにつなぎ、ブラウザで操作した結果。{ok}のうち{noted}は注記つき', body))

# ---- 2. ファイルの中身は変わらなかったか ----
checks = load('results/integrity.json')['checks']
for c in checks:
    if c.get('raw', '').endswith('.csv'):
        r = rows('results/' + c['raw'])
        c['matched'], c['total'] = sum(x['Matches'] == 'True' for x in r), len(r)
    elif c.get('raw', '').endswith('.json'):
        e = load('results/' + c['raw'])['entries']
        c['matched'], c['total'] = sum(bool(x['matches_initial_fixture']) for x in e), len(e)
tm, tt = sum(c['matched'] for c in checks), sum(c['total'] for c in checks)
x0, unit, y0, rh = 420, 44, 108, 58
body = []
for i, c in enumerate(checks):
    y = y0 + i * rh
    body += [
        f'<text x="32" y="{y + 15}" font-size="15" font-weight="700" fill="{INK}">{c["name"]}</text>',
        f'<text x="32" y="{y + 34}" font-size="12" fill="{SUB}">{c["detail"]}</text>',
    ]
    for k in range(c['total']):
        bx = x0 + k * unit
        if k < c['matched']:
            body.append(f'<rect x="{bx}" y="{y}" width="{unit - 6}" height="26" rx="4" fill="{ACCENT}"/>')
        else:
            body += [
                f'<rect x="{bx + 1}" y="{y + 1}" width="{unit - 8}" height="24" rx="4" fill="{CARD}" stroke="{INK}" stroke-width="2"/>',
                f'<path d="M{bx + 14} {y + 8}l10 10M{bx + 24} {y + 8}l-10 10" stroke="{INK}" stroke-width="2"/>',
            ]
    tx = x0 + c['total'] * unit + 8
    body.append(f'<text x="{tx}" y="{y + 19}" font-size="15" font-weight="700" fill="{INK}">{c["matched"]}<tspan font-weight="400" fill="{SUB}"> / {c["total"]} 一致</tspan></text>')
    if c.get('note'):
        body.append(f'<text x="{tx + 86}" y="{y + 19}" font-size="12" fill="{INK}">{c["initial_bytes"]}→{c["restored_bytes"]}バイト。{c["note"]}</text>')
yb = y0 + len(checks) * rh
write('chart-integrity.svg', frame(
    yb + 4, f'照合した{tt}ファイルのうち{tm}がSHA-256で一致。不一致の1つは改行コードの差',
    '四角1つが1ファイル。転送や操作の前後でファイルの中身が1バイトも変わっていないかを、ハッシュ値で比べた', body))

# ---- 3. 依頼から使えるようになるまでの時間 ----
tl = load('results/timeline.json')


def sec(t):
    h, m, s = map(int, t.split(':'))
    return h * 3600 + m * 60 + s


def dur(a, b):
    d = sec(b) - sec(a)
    return f'{d // 60}分{d % 60:02d}秒'


t0, t1 = sec(tl['phases'][0]['start']), sec(tl['phases'][-1]['end'])
ms = {m['label']: m['time'] for m in tl['milestones']}
http = next(m['time'] for m in tl['milestones'] if 'HTTP 200' in m['label'])
x0, pw, y0, rh = 300, 548, 112, 50


def sx(t):
    return x0 + (sec(t) - t0) / (t1 - t0) * pw


yb = y0 + len(tl['phases']) * rh
body = []
for m in range(0, (t1 - t0) // 60 + 1, 10):
    gx = x0 + m * 60 / (t1 - t0) * pw
    body += [
        f'<line x1="{gx:.1f}" x2="{gx:.1f}" y1="{y0 - 10}" y2="{yb - 6}" stroke="{TRACK}"/>',
        f'<text x="{gx:.1f}" y="{yb + 12}" font-size="12" text-anchor="middle" fill="{SUB}">{m}分</text>',
    ]
for i, p in enumerate(tl['phases']):
    y = y0 + i * rh
    a, b = sx(p['start']), sx(p['end'])
    env = '復旧' in p['name']
    body += [
        f'<text x="32" y="{y + 14}" font-size="14" fill="{INK}">{p["name"]}</text>',
        f'<text x="32" y="{y + 31}" font-size="11.5" fill="{SUB}">{p["start"]} → {p["end"]}</text>',
        f'<rect x="{a:.1f}" y="{y}" width="{max(b - a, 3):.1f}" height="24" rx="4" fill="{INK if env else ACCENT}"><title>{p["name"]}: {dur(p["start"], p["end"])}</title></rect>',
    ]
    label = dur(p['start'], p['end'])
    if b - a > 100:
        body.append(f'<text x="{a + 10:.1f}" y="{y + 17}" font-size="13.5" font-weight="700" fill="{CARD}">{label}</text>')
    else:
        body.append(f'<text x="{b + 10:.1f}" y="{y + 17}" font-size="13.5" font-weight="700" fill="{INK}">{label}</text>')
hx = sx(http)
body += [
    f'<line x1="{hx:.1f}" x2="{hx:.1f}" y1="{y0 - 16}" y2="{yb - 6}" stroke="{INK}" stroke-dasharray="5 4" stroke-width="1.5"/>',
    f'<text x="{hx + 8:.1f}" y="{y0 - 10}" font-size="12" fill="{INK}">{http} ブラウザで開ける状態（HTTP 200）</text>',
    f'<text x="{x0 + pw / 2}" y="{yb + 34}" font-size="12.5" text-anchor="middle" fill="{SUB}">実験を依頼してからの経過時間（{tl["phases"][0]["start"]} 開始、日本時間）</text>',
]
write('chart-timeline.svg', frame(
    yb + 52, f'依頼から{dur(tl["phases"][0]["start"], http).split("分")[0]}分で画面が開き、{(t1 - t0) // 60}分で基本の7項目を終えた',
    '1回目の実験の時間配分。濃い色の帯は環境の復旧（止まっていたPodman machineの起動）にかかった時間', body))
