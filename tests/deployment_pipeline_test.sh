#!/bin/sh
set -eu

test -f vercel.json
grep -Fq '"outputDirectory": ".vercel/output/static"' vercel.json

test -x scripts/install-godot-web-ci
grep -Fq 'Godot_v${godot_version}-stable_linux.x86_64.zip' scripts/install-godot-web-ci
grep -Fq 'web_nothreads_release.zip' scripts/install-godot-web-ci

test -x scripts/package-vercel-output
grep -Fq '"version": 3' scripts/package-vercel-output
grep -Fq '"routes"' scripts/package-vercel-output
grep -Fq 'application/wasm' scripts/package-vercel-output
grep -Fq '.vercel/output/static' scripts/package-vercel-output
grep -Fq 'https://floorball-frenzy.vercel.app/api/ice-servers' scripts/package-vercel-output
grep -Fq '"src": "/api/(lobby|signal)"' scripts/package-vercel-output
grep -Fq '.vercel/output/functions/api/matchmaking.func' scripts/package-vercel-output
grep -Fq 'server/matchmaking.mjs' scripts/package-vercel-output

if grep -R -Fq 'const API_BASE := "https://floorball-frenzy.vercel.app/api"' scripts; then
	echo "Browser networking must use same-origin /api routes so CORS cannot block matchmaking." >&2
	exit 1
fi

test -f .github/workflows/deploy-vercel.yml
grep -Fq 'actions/cache@v4' .github/workflows/deploy-vercel.yml
grep -Fq './scripts/export-web' .github/workflows/deploy-vercel.yml
grep -Fq './scripts/package-vercel-output' .github/workflows/deploy-vercel.yml
grep -Fq 'actions/upload-artifact@v4' .github/workflows/deploy-vercel.yml
grep -Fq "env.VERCEL_TOKEN != ''" .github/workflows/deploy-vercel.yml
grep -Fq 'deploy --prebuilt --prod' .github/workflows/deploy-vercel.yml
grep -Fq 'VERCEL_TOKEN' .github/workflows/deploy-vercel.yml

echo "Deployment pipeline configuration is valid."
