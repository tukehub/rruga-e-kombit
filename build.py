#!/usr/bin/env python3
"""Builds the game into www/ (used by the Android app) from src/.

  python3 build.py            -> www/index.html + local three.js, bloom files, fonts, icons
  python3 build.py --artifact -> also dist/rruga.html (single file, scripts from CDN)
"""
import os, shutil, sys

R = os.path.dirname(os.path.abspath(__file__))
S, W = os.path.join(R, 'src'), os.path.join(R, 'www')
NM = os.path.join(R, 'node_modules')
ORDER = ['00_util.js', '01_data.js', '02_track.js', '03_sim.js', '04_tex.js', '045_gfx.js', '05_world.js',
         '06_cars.js', '07_fx.js', '08_audio.js', '09_ui.js', '10_main.js']
EXTRAS = ['shaders/CopyShader.js', 'shaders/LuminosityHighPassShader.js',
          'postprocessing/EffectComposer.js', 'postprocessing/UnrealBloomPass.js']
FONTS = [('Big Shoulders Display', 'big-shoulders-display', [('700', 'normal'), ('900', 'normal')]),
         ('Chakra Petch', 'chakra-petch', [('500', 'normal'), ('600', 'normal'), ('700', 'normal'), ('600', 'italic'), ('700', 'italic')])]
GFONTS = '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@700;900&family=Chakra+Petch:ital,wght@0,500;0,600;0,700;1,600;1,700&display=swap">'

def read(p):
    with open(p, encoding='utf8') as f: return f.read()

def main():
    js = '\n'.join(read(os.path.join(S, f)) for f in ORDER)
    shell = read(os.path.join(S, 'shell.html'))
    if os.path.isdir(W): shutil.rmtree(W)
    os.makedirs(os.path.join(W, 'fonts'))
    shutil.copy(os.path.join(NM, 'three/build/three.min.js'), W)
    with open(os.path.join(W, 'three-post.js'), 'w', encoding='utf8') as f:
        for e in EXTRAS: f.write(read(os.path.join(NM, 'three/examples/js', e)) + '\n')
    css = []
    for fam, pkg, variants in FONTS:
        for wt, st in variants:
            fn = f'{pkg}-latin-{wt}-{st}.woff2'
            shutil.copy(os.path.join(NM, '@fontsource', pkg, 'files', fn), os.path.join(W, 'fonts', fn))
            css.append(f"@font-face{{font-family:'{fam}';font-style:{st};font-weight:{wt};font-display:swap;src:url(fonts/{fn}) format('woff2')}}")
    with open(os.path.join(W, 'fonts.css'), 'w') as f: f.write('\n'.join(css) + '\n')
    for icon in ('icon-192.png', 'icon-512.png'):
        p = os.path.join(R, 'assets', icon)
        if os.path.exists(p): shutil.copy(p, W)
    # strip the Google Fonts tags from the shell; the app uses the bundled copies
    lines = [l for l in shell.split('\n') if 'fonts.googleapis.com' not in l and 'fonts.gstatic.com' not in l]
    shell_local = '\n'.join(lines)
    i = shell_local.index('</style>') + len('</style>')
    head = ('<!doctype html>\n<html lang="sq">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">\n'
            '<meta name="theme-color" content="#0d0a10">\n<link rel="icon" href="icon-192.png">\n<link rel="stylesheet" href="fonts.css">\n'
            '<style>[hidden]{display:none!important}body{margin:0}</style>\n')
    page = (head + shell_local[:i] + '\n</head>\n<body>\n' + shell_local[i:] +
            '\n<script src="three.min.js"></script>\n<script src="three-post.js"></script>\n<script>\n' + js + '\n</script>\n</body>\n</html>\n')
    with open(os.path.join(W, 'index.html'), 'w', encoding='utf8') as f: f.write(page)
    print(f'www/index.html {len(page) // 1024} KB')
    if '--artifact' in sys.argv:
        os.makedirs(os.path.join(R, 'dist'), exist_ok=True)
        cdn = '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>\n' + ''.join(
            f'<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/{e}"></script>\n' for e in EXTRAS)
        art = shell + '\n' + cdn + '<script>\n' + js + '\n</script>\n'
        with open(os.path.join(R, 'dist', 'rruga.html'), 'w', encoding='utf8') as f: f.write(art)
        print(f'dist/rruga.html {len(art) // 1024} KB')

if __name__ == '__main__':
    main()
