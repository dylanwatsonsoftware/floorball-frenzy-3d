#!/bin/sh
set -eu

project_file="project.godot"

grep -Fq 'config/features=PackedStringArray("4.7", "GL Compatibility")' "$project_file"
grep -Fq 'run/main_scene="res://scenes/app/main_menu.tscn"' "$project_file"
grep -Fq 'textures/vram_compression/import_etc2_astc=true' "$project_file"
grep -Fq 'common/physics_interpolation=true' "$project_file"

if grep -Fq '"C#"' "$project_file"; then
  echo "Project must not require C# because Godot 4 C# cannot export to web." >&2
  exit 1
fi

if grep -Fq '[dotnet]' "$project_file"; then
  echo "Project must not contain .NET configuration." >&2
  exit 1
fi

if grep -Fq 'res://addons/godot_mcp/plugin.cfg' "$project_file"; then
  echo "C#-only Godot MCP plugin must be disabled in the GDScript project." >&2
  exit 1
fi

test -f scenes/app/main_menu.tscn
test -f scenes/match/match.tscn
test -f scripts/app/main.gd

echo "Project baseline is web-capable."
