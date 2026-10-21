"""Render share previews using the supplied, unmodified master logo.
Developer tool only: requires Playwright and Chromium; PNGs are committed.
"""
from pathlib import Path
import base64, re, shutil
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
logo=(ROOT/'assets/logo/lutera-horizontal-light.svg').read_text()
font=base64.b64encode((ROOT/'assets/fonts/Sora-600.woff2').read_bytes()).decode()
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<style>@font-face{{font-family:Sora;src:url(data:font/woff2;base64,{font})}}text{{font-family:Sora,Arial,sans-serif;fill:#161A3D;font-weight:600}}</style>
<rect width="1200" height="630" fill="#F3F2EE"/>
<g transform="translate(72 62) scale(.65)">{re.sub(r'^<svg[^>]*>|</svg>$','',logo.strip())}</g>
<text x="72" y="283" font-size="62" letter-spacing="-2">Hardware, software</text>
<text x="72" y="363" font-size="62" letter-spacing="-2">and intelligent systems.</text>
<text x="75" y="541" font-size="22">Lutera Technology Ltd</text>
<g fill="#2E5BFF" transform="translate(920 454)"><rect width="24" height="120" rx="12"/><rect x="34" y="80" width="24" height="40" rx="12"/><rect x="68" y="80" width="24" height="40" rx="12"/></g>
</svg>'''
(ROOT/'assets/social.svg').write_text(svg)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=shutil.which('chromium') or None,args=['--no-sandbox'])
 q=b.new_page(viewport={'width':1200,'height':630},device_scale_factor=1)
 q.set_content('<style>body{margin:0}</style>'+svg)
 q.evaluate('document.fonts.ready');q.screenshot(path=str(ROOT/'assets/social.png'))
 q.set_viewport_size({'width':600,'height':172})
 q.set_content('<style>body{margin:0}svg{width:600px;height:172px}</style>'+logo)
 q.screenshot(path=str(ROOT/'assets/logo/lutera-social-logo.png'),omit_background=True)
 b.close()
print('Rendered social.png (1200×630) and organization logo (600×172).')
