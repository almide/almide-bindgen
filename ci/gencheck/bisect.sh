#!/usr/bin/env bash
# TEMPORARY: bisect the hang
set -u
cd "$(dirname "$0")/../.."
mkdir -p target/dbg target/gencheck/shapes
almide compile ci/gencheck/shapes.almd --json > target/gencheck/shapes/iface.json
E='"{\"module\":\"t\",\"types\":[],\"functions\":[]}"'
mk() { printf '%s\n' "$2" > "target/dbg/$1_test.almd"; }
mk a "import self.scaffolding as scaffolding
test \"a\" { assert(string.contains(scaffolding.generate($E), \"bridge_free\")) }"
mk b "import fs
import self.scaffolding as scaffolding
test \"b\" { assert(string.contains(scaffolding.generate($E), \"bridge_free\")) }"
mk c "import self.scaffolding as scaffolding
import self.bindings.almide as almide_bind
test \"c\" { assert(string.contains(scaffolding.generate($E), \"bridge_free\")) }"
mk d "import self.bindings.almide as almide_bind
test \"d\" { assert(string.contains(almide_bind.generate($E), \"import ffi\")) }"
mk e "import fs
test \"e\" { let s = fs.read_text(\"target/gencheck/shapes/iface.json\") ?? \"\"
  assert(string.len(s) > 10) }"
mk f "import fs
import self.scaffolding as scaffolding
test \"f\" { let s = fs.read_text(\"target/gencheck/shapes/iface.json\") ?? \"\"
  assert(string.contains(scaffolding.generate(s), \"bridge_add\")) }"
mk g "import fs
import self.bindings.almide as almide_bind
test \"g\" { let s = fs.read_text(\"target/gencheck/shapes/iface.json\") ?? \"\"
  assert(string.contains(almide_bind.generate(s), \"raw_bridge_add\")) }"
cp spec/bindgen_test.almd target/dbg/h_test.almd
for t in a b c d e f g h; do
  echo "=== $t"
  head -3 "target/dbg/${t}_test.almd"
  timeout 90 almide test "target/dbg/${t}_test.almd" </dev/null 2>&1 | tail -5; echo "rc=${PIPESTATUS[0]}"
done
