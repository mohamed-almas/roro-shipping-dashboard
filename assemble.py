"""
assemble.py — data is served live from Supabase (get_roro_dashboard_data RPC),
so this script simply copies dashboard_template.html -> index.html.

After changing dashboard_template.html, run:
  python assemble.py
  git add index.html && git commit && git push
"""
import shutil, os

src = 'dashboard_template.html'
dst = 'index.html'
shutil.copy(src, dst)
print(f'Copied {src} -> {dst}  ({os.path.getsize(dst)/1e3:.0f} KB)')
