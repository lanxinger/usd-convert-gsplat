#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bundle_dir="$tmp_dir/usd-convert-gsplat-cli"
relocated_dir="$tmp_dir/relocated-cli"
input_ply="$tmp_dir/tiny_gaussian_test.ply"
output_usdz="$tmp_dir/tiny_gaussian_test.usdz"

"$repo_root/scripts/build-cli-bundle.sh" "$bundle_dir"
cp -a "$bundle_dir" "$relocated_dir"

if grep -F "$repo_root" "$relocated_dir/bin/convert-gsplat-to-usdz" >/dev/null; then
  echo "bundle launcher contains source repo path" >&2
  exit 1
fi

cat > "$input_ply" <<'PLY'
ply
format ascii 1.0
element vertex 2
property float x
property float y
property float z
property float scale_0
property float scale_1
property float scale_2
property float rot_0
property float rot_1
property float rot_2
property float rot_3
property float opacity
property float f_dc_0
property float f_dc_1
property float f_dc_2
end_header
0.0 0.0 0.0 -2.0 -2.0 -2.0 1.0 0.0 0.0 0.0 4.0 1.0 0.2 0.1
0.2 0.0 0.0 -2.0 -2.0 -2.0 1.0 0.0 0.0 0.0 -3.4028234663852886e38 0.1 0.5 1.0
PLY

"$relocated_dir/bin/convert-gsplat-to-usdz" "$input_ply" "$output_usdz"

"$relocated_dir/.venv/bin/python" - "$output_usdz" <<'PY'
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path) as archive:
    names = archive.namelist()
    assert names == ["default.usda"], names
    data = archive.read("default.usda").decode("utf-8")
    assert "ParticleField3DGaussianSplat" in data
    assert "opacities" in data
PY
