#!/bin/sh
set -eu

test -f export_presets.cfg
grep -Fq 'platform="Web"' export_presets.cfg
grep -Fq 'export_path="build/web/index.html"' export_presets.cfg
grep -Fq 'html/canvas_resize_policy=2' export_presets.cfg
grep -Fq 'progressive_web_app/enabled=true' export_presets.cfg
grep -Fq 'variant/extensions_support=false' export_presets.cfg
grep -Fq 'variant/thread_support=false' export_presets.cfg
test -x scripts/export-web
grep -Fq 'mkdir -p build/web' scripts/export-web

echo "Web export preset is deployment-ready."
