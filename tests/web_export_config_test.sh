#!/bin/sh
set -eu

test -f export_presets.cfg
grep -Fq 'platform="Web"' export_presets.cfg
grep -Fq 'export_path="build/web/index.html"' export_presets.cfg
grep -Fq 'html/canvas_resize_policy=2' export_presets.cfg
grep -Fq '__floorballRtcPath' export_presets.cfg
grep -Fq 'progressive_web_app/orientation=1' export_presets.cfg
grep -Fq 'progressive_web_app/enabled=true' export_presets.cfg
grep -Fq 'variant/extensions_support=false' export_presets.cfg
grep -Fq 'variant/thread_support=false' export_presets.cfg
grep -Fq 'exclude_filter="build/*, addons/*, tests/*, docs/*, .github/*, vercel.json"' export_presets.cfg
test -x scripts/export-web
grep -Fq 'mkdir -p build/web' scripts/export-web
grep -Fq './scripts/harden-service-worker' scripts/export-web
test -x scripts/harden-service-worker
grep -Fq 'self.skipWaiting()' scripts/harden-service-worker
grep -Fq 'self.clients.claim()' scripts/harden-service-worker
grep -Fq 'client.navigate(client.url)' scripts/harden-service-worker
grep -Fq 'Floorball Frenzy network-first update policy.' scripts/harden-service-worker
grep -Fq 'await fetchAndCache(event, cache, isCacheable)' scripts/harden-service-worker
grep -Fq 'window/stretch/aspect="expand"' project.godot

echo "Web export preset is deployment-ready."
