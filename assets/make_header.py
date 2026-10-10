"""README用のヘッダー画像（assets/header.svg）を、results/ の実測値から作る。

使い方（リポジトリ直下で）: python assets/make_header.py
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ops = json.loads((ROOT / 'results/operations.json').read_text(encoding='utf-8'))['operations']
tl = json.loads((ROOT / 'results/timeline.json').read_text(encoding='utf-8'))
checks = json.loads((ROOT / 'results/integrity.json').read_text(encoding='utf-8'))['checks']

matched = total = 0
for c in checks:
    raw = c.get('raw', '')
    if raw.endswith('.csv'):
        with open(ROOT / 'results' / raw, encoding='utf-8-sig', newline='') as f:
            r = list(csv.DictReader(f))
        m, t = sum(x['Matches'] == 'True' for x in r), len(r)
    elif raw.endswith('.json'):
        e = json.loads((ROOT / 'results' / raw).read_text(encoding='utf-8'))['entries']
        m, t = sum(bool(x['matches_initial_fixture']) for x in e), len(e)
    else:
        m, t = c['matched'], c['total']
    matched, total = matched + m, total + t


def sec(t):
    h, m, s = map(int, t.split(':'))
    return h * 3600 + m * 60 + s


http = next(m['time'] for m in tl['milestones'] if 'HTTP 200' in m['label'])
minutes = (sec(http) - sec(tl['phases'][0]['start'])) // 60
confirmed = sum(o['status'] != 'unconfirmed' for o in ops)

A, A2 = '#14B8A6', '#5EEAD4'
SANS = "font-family=\"'Segoe UI','Helvetica Neue',Helvetica,Arial,sans-serif\""
MONO = 'font-family="ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"'
o = [
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 420" width="1280" height="420" role="img" aria-label="Filestash on Podman with SFTP: browser file operations field test">',
    '<defs>',
    '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0B0F14"/><stop offset="0.6" stop-color="#0D141A"/><stop offset="1" stop-color="#0B1C1B"/></linearGradient>',
    f'<radialGradient id="glow" cx="0.82" cy="0.25" r="0.6"><stop offset="0" stop-color="{A}" stop-opacity="0.22"/><stop offset="1" stop-color="{A}" stop-opacity="0"/></radialGradient>',
    f'<linearGradient id="title" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="{A2}"/></linearGradient>',
    '<pattern id="grid" width="32" height="32" patternUnits="userSpaceOnUse"><path d="M32 0H0V32" fill="none" stroke="#FFFFFF" stroke-opacity="0.035"/></pattern>',
    '<clipPath id="r"><rect width="1280" height="420" rx="20"/></clipPath>',
    '</defs>',
    '<g clip-path="url(#r)">',
    '<rect width="1280" height="420" fill="url(#bg)"/><rect width="1280" height="420" fill="url(#grid)"/><rect width="1280" height="420" fill="url(#glow)"/>',
    f'<g {SANS}>',
    f'<rect x="64" y="70" width="270" height="30" rx="15" fill="{A}" fill-opacity="0.14" stroke="{A}" stroke-opacity="0.55"/>',
    f'<text x="199" y="90" text-anchor="middle" font-size="13" font-weight="700" letter-spacing="2" fill="{A2}">SELF-HOSTED FILE MANAGER</text>',
    '<text x="64" y="158" font-size="54" font-weight="800" fill="url(#title)" letter-spacing="-1">Filestash</text>',
    '<text x="64" y="216" font-size="54" font-weight="800" fill="url(#title)" letter-spacing="-1">on Podman</text>',
    f'<text x="64" y="262" font-size="26" font-weight="600" fill="#9CA3AF"><tspan fill="{A}">×</tspan> SFTP <tspan fill="#6B7280" font-weight="400">— browser field test</tspan></text>',
    '</g>',
]
for i, (v, label) in enumerate([(f'{confirmed} / {len(ops)}', 'operations confirmed'), (f'{matched} / {total}', 'SHA-256 matches'), (f'{minutes} min', 'to first screen')]):
    x = 64 + i * 196
    o.append(f'<g {SANS}><rect x="{x}" y="304" width="182" height="64" rx="12" fill="#FFFFFF" fill-opacity="0.04" stroke="#FFFFFF" stroke-opacity="0.10"/><text x="{x + 18}" y="332" font-size="22" font-weight="800" fill="#F9FAFB">{v}</text><text x="{x + 18}" y="354" font-size="12.5" fill="#9CA3AF" letter-spacing="0.4">{label}</text></g>')

# 右側：データの通り道（ブラウザ → Filestash → SFTP）と、操作ごとの結果
o += [
    '<rect x="676" y="52" width="576" height="316" rx="16" fill="#000000" fill-opacity="0.28" stroke="#FFFFFF" stroke-opacity="0.08"/>',
    f'<text x="698" y="80" {MONO} font-size="12" fill="#6B7280" letter-spacing="1">DATA PATH</text>',
    f'<text x="1230" y="80" text-anchor="end" {MONO} font-size="12" fill="#6B7280">loopback only</text>',
]
boxes = [('Browser', '127.0.0.1:18334', False), ('Filestash', 'container :8334', True), ('SFTP server', 'container :22', False)]
bx, bw, by, bh, gap = 698, 156, 98, 70, 33
for i, (name, sub, main) in enumerate(boxes):
    x = bx + i * (bw + gap)
    o += [
        f'<rect x="{x}" y="{by}" width="{bw}" height="{bh}" rx="10" fill="{A if main else "#FFFFFF"}" fill-opacity="{0.16 if main else 0.05}" stroke="{A if main else "#FFFFFF"}" stroke-opacity="{0.7 if main else 0.14}"/>',
        f'<text x="{x + bw / 2}" y="{by + 31}" text-anchor="middle" {SANS} font-size="17" font-weight="700" fill="#F9FAFB">{name}</text>',
        f'<text x="{x + bw / 2}" y="{by + 52}" text-anchor="middle" {MONO} font-size="11" fill="#9CA3AF">{sub}</text>',
    ]
    if i < len(boxes) - 1:
        ax = x + bw + 5
        o.append(f'<path d="M{ax} {by + bh / 2}h{gap - 12}m-6 -5l6 5l-6 5" fill="none" stroke="{A2}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
o += [
    f'<text x="{bx + bw + gap / 2}" y="{by + bh + 18}" text-anchor="middle" {MONO} font-size="10.5" fill="#6B7280">HTTP</text>',
    f'<text x="{bx + 2 * bw + gap * 1.5}" y="{by + bh + 18}" text-anchor="middle" {MONO} font-size="10.5" fill="#6B7280">SFTP</text>',
    f'<text x="698" y="222" {MONO} font-size="12" fill="#6B7280" letter-spacing="1">{len(ops)} OPERATIONS</text>',
]
groups = []
for op in ops:
    if op['group'] not in groups:
        groups.append(op['group'])
names = {'接続と表示': 'browse', 'プレビュー': 'preview', 'ファイル操作': 'file ops', 'フォルダーと権限': 'folders / access'}
for gi, g in enumerate(groups):
    y = 250 + gi * 28
    o.append(f'<text x="698" y="{y + 4}" {MONO} font-size="11" fill="#9CA3AF">{names.get(g, "")}</text>')
    for k, op in enumerate([p for p in ops if p['group'] == g]):
        cx = 846 + k * 30
        if op['status'] == 'confirmed':
            o.append(f'<circle cx="{cx}" cy="{y}" r="8" fill="{A}"/>')
        elif op['status'] == 'confirmed_with_note':
            o.append(f'<circle cx="{cx}" cy="{y}" r="7" fill="none" stroke="{A}" stroke-width="2"/><circle cx="{cx}" cy="{y}" r="3" fill="{A}"/>')
        else:
            o.append(f'<circle cx="{cx}" cy="{y}" r="7" fill="none" stroke="#F9FAFB" stroke-opacity="0.75" stroke-width="2"/><path d="M{cx - 3} {y - 3}l6 6M{cx + 3} {y - 3}l-6 6" stroke="#F9FAFB" stroke-opacity="0.75" stroke-width="2"/>')
o += [f'<rect x="0" y="0" width="6" height="420" fill="{A}"/>', '</g></svg>']
(ROOT / 'assets/header.svg').write_text('\n'.join(o), encoding='utf-8', newline='\n')
print('wrote header.svg', confirmed, len(ops), matched, total, minutes)
