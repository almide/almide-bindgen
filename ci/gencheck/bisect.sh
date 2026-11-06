#!/usr/bin/env bash
# TEMPORARY: bisect the hang
set -u
cd "$(dirname "$0")/../.."
mkdir -p target/dbg target/gencheck/shapes
almide compile ci/gencheck/shapes.almd --json > target/gencheck/shapes/iface.json
E='"{\"module\":\"t\",\"types\":[],\"functions\":[]}"'
mk() { printf '%s\n' "$2" > "target/dbg/$1_test.almd"; }
mk i "import self as bindgen
import self.scaffolding as scaffolding
test \"i\" { assert(string.contains(scaffolding.generate($E), \"bridge_free\")) }"
mk j "import json
import self.scaffolding as scaffolding
test \"j\" { assert(string.contains(scaffolding.generate($E), \"bridge_free\")) }"
mk k "import self.scaffolding as scaffolding
test \"k\" { assert(string.len(scaffolding.generate_cargo($E)) > 0) }"
for t in i j k; do
  echo "=== $t"
  head -3 "target/dbg/${t}_test.almd"
  timeout 90 almide test "target/dbg/${t}_test.almd" </dev/null 2>&1 | tail -5; echo "rc=${PIPESTATUS[0]}"
done
