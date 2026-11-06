#!/usr/bin/env bash
# Generated-code gate: run every Almide-emitting generator in this package
# over the fixture library, write each output into its own scratch project,
# and `almide check` it with the pinned compiler. bindgen's own `almide check`
# only sees the templates as string literals, so a removed spelling inside a
# template passes there and fails first in a consumer; this gate fails here.
set -euxo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
almide --version

fail=0
for lib in "$root"/ci/gencheck/*.almd; do
  name="$(basename "$lib" .almd)"
  [ "$name" = main ] && continue
  out="$work/$name"
  mkdir -p "$out"
  almide check "$lib"
  almide compile "$lib" --json > "$out/iface.json"
  (cd "$root" && timeout 600 almide run ci/gencheck/main.almd -- "$lib" "$out/iface.json" "$out" </dev/null)
  for kind in consumer bridge; do
    printf '[package]\nname = "gencheck_%s_%s"\nversion = "0.0.0"\n' "$name" "$kind" > "$out/$kind/almide.toml"
    echo "── $name / $kind ──"
    if ! (cd "$out/$kind" && almide check main.almd); then
      echo "::error::generated $kind code for ci/gencheck/$name.almd does not pass almide check"
      cat -n "$out/$kind/main.almd"
      fail=1
    fi
  done
done
exit "$fail"
