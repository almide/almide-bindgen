#!/usr/bin/env bash
# Generated-code gate: run every Almide-emitting generator in this package
# over the fixture library, write each output into its own scratch project,
# and `almide check` it with the pinned compiler. bindgen's own `almide check`
# only sees the templates as string literals, so a removed spelling inside a
# template passes there and fails first in a consumer; this gate fails here.
set -euxo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
# The driver runs on the embedded wasm host (no native build), which sees
# only the working directory, so the scratch projects live under target/.
cd "$root"
work="target/gencheck"
rm -rf "$work"
almide --version
# DEBUG bisect
mkdir -p target/dbg
printf 'effect fn main() -> Unit = println("hi")\n' > target/dbg/hello.almd
timeout 120 almide run --target wasm target/dbg/hello.almd </dev/null || echo "hello wasm rc=$?"
timeout 120 almide run target/dbg/hello.almd </dev/null || echo "hello native rc=$?"
timeout 120 almide build --target wasm ci/gencheck/main.almd -o target/dbg/drv.wasm </dev/null || echo "build drv rc=$?"
ls -la target/dbg

fail=0
for lib in "$root"/ci/gencheck/*.almd; do
  name="$(basename "$lib" .almd)"
  lib="ci/gencheck/$name.almd"
  [ "$name" = main ] && continue
  out="$work/$name"
  mkdir -p "$out"
  almide check "$lib"
  almide compile "$lib" --json > "$out/iface.json"
  timeout 300 almide run --target wasm -v ci/gencheck/main.almd -- "$lib" "$out/iface.json" "$out" </dev/null
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
