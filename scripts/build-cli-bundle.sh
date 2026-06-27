#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$repo_root/dist/usd-convert-gsplat-cli}"
tmp_dir="$output_dir.tmp"
python_spec="${PYTHON:-3.12}"

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir/bin"

if command -v uv >/dev/null 2>&1; then
  uv venv --python "$python_spec" "$tmp_dir/.venv"
  uv pip install --python "$tmp_dir/.venv/bin/python" "$repo_root/source/python[usd]" scipy
else
  python_bin="${PYTHON_BIN:-python3}"
  "$python_bin" -m venv "$tmp_dir/.venv"
  "$tmp_dir/.venv/bin/python" -m pip install --upgrade pip
  "$tmp_dir/.venv/bin/python" -m pip install "$repo_root/source/python[usd]" scipy
fi

cat > "$tmp_dir/bin/convert-gsplat-to-usdz" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="$bundle_dir/.venv/bin/python"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 input.ply output.usdz [usd-convert-gsplat options...]" >&2
  echo "Example: $0 scene.ply scene.usdz --up-axis Z --rotate-x 180" >&2
  exit 64
fi

if [[ ! -x "$python_bin" ]]; then
  echo "Bundled Python environment is missing: $python_bin" >&2
  exit 69
fi

input_path="$1"
output_path="$2"
shift 2

mkdir -p "$(dirname "$output_path")"
"$python_bin" -m usd_convert_gsplat -i "$input_path" -o "$output_path" "$@"
SH
chmod +x "$tmp_dir/bin/convert-gsplat-to-usdz"

cat > "$tmp_dir/README.md" <<'MD'
# usd-convert-gsplat CLI bundle

This directory is a self-contained CLI bundle for converting Gaussian splat
`.ply` or `.spz` files into USD formats.

```bash
bin/convert-gsplat-to-usdz input.ply output.usdz
```

The command accepts the same options as `python -m usd_convert_gsplat`, including
`--up-axis`, `--rotate-x`, `--rotate-y`, `--rotate-z`, `--generateSh`, and
`--generateScales`.
MD

rm -rf "$output_dir"
mv "$tmp_dir" "$output_dir"

echo "CLI bundle written to $output_dir"
echo "Run: $output_dir/bin/convert-gsplat-to-usdz input.ply output.usdz"
