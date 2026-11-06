#!/usr/bin/env bash
# Generated-code gate: run every Almide-emitting generator in this package
# over each fixture library in ci/gencheck/, write each output into its own
# scratch project, and `almide check` it with the pinned compiler.
#
# bindgen's own `almide check` sees the templates only as string literals, so
# a removed spelling inside a template passes there and fails first in a
# consumer. This gate fails here instead.
set -euo pipefail

cd "$(dirname "$0")/../.."
work="target/gencheck"
rm -rf "$work"
mkdir -p "$work"
almide --version

fail=0
for lib in ci/gencheck/*.almd; do
  name="$(basename "$lib" .almd)"
  case "$name" in *_test) continue ;; esac
  out="$work/$name"
  mkdir -p "$out"
  almide check "$lib"
  almide compile "$lib" --json > "$out/iface.json"
  echo "$name" > "$work/current"
  timeout 300 almide test ci/gencheck/emit_test.almd </dev/null
  rm -f "$work/current"
  for kind in consumer bridge; do
    echo "── $name / $kind ──"
    if [ ! -f "$out/$kind/main.almd" ]; then
      echo "::error::the driver wrote no $kind output for $lib"
      fail=1
      continue
    fi
    printf '[package]\nname = "gencheck_%s_%s"\nversion = "0.0.0"\n' "$name" "$kind" > "$out/$kind/almide.toml"
    if ! (cd "$out/$kind" && almide check main.almd); then
      echo "::error::the generated $kind code for $lib does not pass almide check"
      cat -n "$out/$kind/main.almd"
      fail=1
    fi
  done
done
exit "$fail"
