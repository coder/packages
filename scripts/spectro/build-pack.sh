#!/usr/bin/env bash

# Builds a Spectro Cloud Palette community pack for a given Coder version.
#
# The pack is a re-vendored copy of the upstream Coder Helm chart plus the
# Palette-specific metadata that spectrocloud/pack-central requires. Output is
# a directory tree that can be committed verbatim to pack-central under
# packs/coder-<version>/.
#
# Every artifact is derived from the published chart. Nothing is hand-edited,
# because the two defects in the previously contributed pack both came from
# hand edits: Chart.yaml was version-bumped without re-vendoring the chart
# body, and the pack values.yaml was nested one level too shallow, which made
# every user override silently inert.

set -euo pipefail

readonly CHART_REPO="https://helm.coder.com/v2"
readonly IMAGE_REPO="ghcr.io/coder/coder"

# Palette treats a pack with a different name or displayName as an entirely new
# pack rather than a new version of an existing one. These two values must stay
# byte-stable across every release, forever.
readonly PACK_NAME="coder-chart"
readonly PACK_DISPLAY_NAME="Coder"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

log()  { printf '  %s\n' "$*" >&2; }
step() { printf '\n==> %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

usage() {
	cat >&2 <<'EOF'
Usage: build-pack.sh <version> [--outdir <dir>] [--pack-central <dir>]

Arguments:
  <version>          Bare semver of the Coder release, with no leading "v".
                     Example: 2.35.6

Options:
  --outdir <dir>     Where to write the pack. Default: ./build/spectro
  --pack-central <dir>
                     Checkout of spectrocloud/pack-central. Supplies logo.png
                     and the previous pack.json, and provides the upstream
                     validator used for the pre-flight structural check.
                     Defaults to $PACK_CENTRAL_DIR.

Requires: helm, yq, jq, crane, python3 with PyYAML.
EOF
	exit 2
}

version=""
outdir="./build/spectro"
pack_central="${PACK_CENTRAL_DIR:-}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--outdir)
		[[ $# -ge 2 ]] || usage
		outdir="$2"
		shift 2
		;;
	--pack-central)
		[[ $# -ge 2 ]] || usage
		pack_central="$2"
		shift 2
		;;
	-h | --help) usage ;;
	-*) die "unknown option: $1" ;;
	*)
		[[ -z "$version" ]] || die "unexpected argument: $1"
		version="$1"
		shift
		;;
	esac
done

[[ -n "$version" ]] || usage

step "Checking inputs and tooling"

# pack-central's validate_pack_version rejects a leading "v" outright. The
# container image tag, confusingly, does carry one. Catch the mixup here rather
# than in someone else's CI.
if [[ "$version" == v* ]]; then
	die "version must not have a leading 'v' (got '$version'). The pack version is bare semver; only the image tag is prefixed."
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	die "version must be bare semver x.y.z (got '$version')"
fi

for tool in helm yq jq crane python3 tar curl sha256sum; do
	command -v "$tool" >/dev/null 2>&1 || die "required tool not found on PATH: $tool"
done
python3 -c 'import yaml' 2>/dev/null || die "python3 is missing the PyYAML module"

[[ -n "$pack_central" ]] || die "pass --pack-central <dir> or set PACK_CENTRAL_DIR to a checkout of spectrocloud/pack-central"
[[ -d "$pack_central/packs" ]] || die "not a pack-central checkout: $pack_central"

# The newest Coder pack already in pack-central is the source of truth for the
# things that must not drift: the logo bytes and the pack.json identity fields.
# The target version is excluded so that re-running against a branch which
# already contains it cannot seed the new pack from itself.
prev_pack="$(find "$pack_central/packs" -maxdepth 1 -type d -name 'coder-*' -print |
	grep -v "/coder-$version\$" |
	sort -V | tail -n 1)"
[[ -n "$prev_pack" ]] || die "no existing packs/coder-* directory found in $pack_central"
log "tooling ok, previous pack: ${prev_pack#"$pack_central"/}"

pack_dir="$outdir/packs/coder-$version"
if [[ -e "$pack_dir" ]]; then
	die "$pack_dir already exists; remove it or choose another --outdir"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

step "Fetching the published chart index"

curl -fsSL "$CHART_REPO/index.yaml" -o "$work/index.yaml" ||
	die "could not fetch $CHART_REPO/index.yaml"

expected_digest="$(yq -r \
	".entries.coder[] | select(.version == \"$version\") | .digest" \
	"$work/index.yaml" | head -n 1)"

if [[ -z "$expected_digest" || "$expected_digest" == "null" ]]; then
	die "chart version $version is not published at $CHART_REPO. Available recent versions: $(yq -r '[.entries.coder[].version] | .[0:5] | join(", ")' "$work/index.yaml")"
fi
log "index digest: $expected_digest"

step "Downloading and verifying the chart"

tarball="$work/coder_helm_$version.tgz"
curl -fsSL "$CHART_REPO/coder_helm_$version.tgz" -o "$tarball" ||
	die "could not download coder_helm_$version.tgz"

actual_digest="$(sha256sum "$tarball" | cut -d' ' -f1)"
if [[ "$actual_digest" != "$expected_digest" ]]; then
	die "chart digest mismatch. index.yaml says $expected_digest, downloaded artifact is $actual_digest"
fi
log "sha256 verified against the published index"

step "Unpacking and applying the Palette chart patch"

mkdir -p "$pack_dir/charts"
tar -xzf "$tarball" -C "$pack_dir/charts"
[[ -d "$pack_dir/charts/coder" ]] || die "chart tarball did not contain a top-level coder/ directory"

chart_yaml="$pack_dir/charts/coder/Chart.yaml"

# The library chart is vendored inside the packaged tarball at charts/libcoder,
# so the dependency path has to lose the parent traversal that upstream uses in
# its source tree. The icon is rewritten to the Palette convention, and
# kubeVersion is normalised to the form the Palette parser accepts. These three
# edits, plus dropping the upstream chart README, are the complete set of
# Spectro-specific deltas.
#
# These are line-oriented rather than yq edits on purpose. yq reflows sequence
# indentation, which would make every future pack diff noisy against the
# previous version directory for no semantic gain.
sed -i \
	-e 's|^\(\s*repository:\s*\)file://\.\./libcoder\s*$|\1file://libcoder|' \
	-e 's|^icon:.*$|icon: file://assets/icons/coder.png|' \
	-e "s|^kubeVersion:.*\$|kubeVersion: '>=1.19-0'|" \
	"$chart_yaml"

# Chart.lock is deliberately left as upstream published it. Its digest is
# computed over the dependency list, so rewriting the repository field without
# recomputing the digest would leave the lock internally inconsistent. Nothing
# in the pack path resolves dependencies, because libcoder ships pre-vendored.

rm -f "$pack_dir/charts/coder/README.md"

# Assert the patch landed, since sed fails silently when a pattern stops matching.
[[ "$(yq -r '.dependencies[] | select(.name == "libcoder") | .repository' "$chart_yaml")" == "file://libcoder" ]] ||
	die "libcoder dependency repository was not rewritten in Chart.yaml"
[[ "$(yq -r '.icon' "$chart_yaml")" == "file://assets/icons/coder.png" ]] ||
	die "icon was not rewritten in Chart.yaml"
[[ "$(yq -r '.kubeVersion' "$chart_yaml")" == ">=1.19-0" ]] ||
	die "kubeVersion was not rewritten in Chart.yaml"
[[ -d "$pack_dir/charts/coder/charts/libcoder" ]] ||
	die "libcoder is not vendored inside the chart; the dependency path rewrite would break packaging"
log "applied the three Palette Chart.yaml edits"

chart_version="$(yq -r '.version' "$chart_yaml")"
chart_app_version="$(yq -r '.appVersion' "$chart_yaml")"
[[ "$chart_version" == "$version" ]] ||
	die "chart body reports version $chart_version but $version was requested. The published artifact is mislabelled; stop and investigate."
[[ "$chart_app_version" == "$version" ]] ||
	die "chart body reports appVersion $chart_app_version but $version was requested"
log "chart body reports version $chart_version, appVersion $chart_app_version"

step "Repackaging the pack chart archive"

helm package "$pack_dir/charts/coder" --destination "$pack_dir/charts" >/dev/null ||
	die "helm package failed"

chart_archive="charts/coder-$version.tgz"
[[ -f "$pack_dir/$chart_archive" ]] ||
	die "helm package did not produce $chart_archive"

# Guards against the exact defect shipped last time: an archive whose filename
# advertises one version while its contents are another.
repacked_version="$(tar -xzOf "$pack_dir/$chart_archive" coder/Chart.yaml | yq -r '.version')"
[[ "$repacked_version" == "$version" ]] ||
	die "repackaged archive reports version $repacked_version, expected $version"
log "$chart_archive contains chart version $repacked_version"

step "Writing pack.json"

# Derived from the previous pack.json so that annotations, layer, addonType and
# cloudTypes carry forward untouched. Only the version and the chart path move.
jq --arg v "$version" --arg c "$chart_archive" \
	'.version = $v | .charts = [$c]' \
	"$prev_pack/pack.json" >"$pack_dir/pack.json"

got_name="$(jq -r '.name' "$pack_dir/pack.json")"
got_display="$(jq -r '.displayName' "$pack_dir/pack.json")"
[[ "$got_name" == "$PACK_NAME" ]] ||
	die "pack.json name is '$got_name', expected '$PACK_NAME'. Changing it forks a new pack in Palette."
[[ "$got_display" == "$PACK_DISPLAY_NAME" ]] ||
	die "pack.json displayName is '$got_display', expected '$PACK_DISPLAY_NAME'. Changing it forks a new pack in Palette."
log "identity preserved: name=$got_name displayName=$got_display"

step "Generating values.yaml"

# The pack values file is the chart's own values.yaml re-rooted under
# charts.<chartName>, with a Palette metadata header on top.
#
# The nesting level matters and is the thing that was wrong before. The chart's
# root keys are coder, provisionerDaemon and extraTemplates, so the correct
# pack path is charts.coder.coder.*. Indenting the whole upstream file by one
# level under "charts:\n  coder:" produces that shape by construction, and it
# stays correct as upstream adds or removes keys.
#
# pack.content.images drives airgap image mirroring and Spectro's security
# scanning, and pack-central's CI resolves every entry with crane.
{
	printf 'pack:\n'
	printf '  content:\n'
	printf '    images:\n'
	printf '      - image: %s:v%s\n' "$IMAGE_REPO" "$version"
	printf '    charts:\n'
	printf '      - repo: helm.coder.com/v2\n'
	printf '        name: coder\n'
	printf '        version: %s\n' "$version"
	printf '  namespace: "coder"\n'
	printf 'charts:\n'
	printf '  coder:\n'
	# Indent non-blank lines only. Padding blank lines would introduce trailing
	# whitespace, which pack-central's values linter flags.
	sed -e 's/^\(.\)/    \1/' "$pack_dir/charts/coder/values.yaml"
} >"$pack_dir/values.yaml"

if grep -qP '\t' "$pack_dir/values.yaml"; then
	die "generated values.yaml contains tab characters"
fi
if grep -qE ' +$' "$pack_dir/values.yaml"; then
	die "generated values.yaml contains trailing whitespace"
fi

pack_roots="$(yq -r '.charts.coder | keys | join(",")' "$pack_dir/values.yaml")"
chart_roots="$(yq -r 'keys | join(",")' "$pack_dir/charts/coder/values.yaml")"
[[ "$pack_roots" == "$chart_roots" ]] ||
	die "charts.coder keys ($pack_roots) do not match the chart's root keys ($chart_roots)"
log "charts.coder mirrors the chart root keys: $pack_roots"

step "Adding logo.png and README.md"

cp "$prev_pack/logo.png" "$pack_dir/logo.png"
log "logo.png copied unchanged from ${prev_pack#"$pack_central"/}"

readme_template="$SCRIPT_DIR/pack-README.md"
[[ -f "$readme_template" ]] || die "README template not found at $readme_template"
sed -e "s/__VERSION__/$version/g" "$readme_template" >"$pack_dir/README.md"
if grep -q '__VERSION__' "$pack_dir/README.md"; then
	die "README still contains an unsubstituted placeholder"
fi

# The README parameter table is hand-maintained, so it can silently start
# lying when upstream renames or drops a value. Assert that every chart path it
# advertises still exists.
python3 - "$pack_dir/README.md" "$pack_dir/charts/coder/values.yaml" <<'PY' || die "README references chart values that no longer exist"
import re
import sys

import yaml

readme, chart_values = sys.argv[1], sys.argv[2]
values = yaml.safe_load(open(chart_values))

# First column of any markdown table row whose cell is a single code span.
paths = []
for line in open(readme):
    m = re.match(r"^\|\s*`([A-Za-z][\w.]*)`\s*\|", line)
    if m:
        paths.append(m.group(1))

missing = []
for path in paths:
    node = values
    for part in path.split("."):
        if isinstance(node, dict) and part in node:
            node = node[part]
        else:
            missing.append(path)
            break

for path in missing:
    print(f"ERROR: README documents '{path}', which is not a key in the chart values")

print(f"  checked {len(paths)} documented parameters, {len(missing)} missing")
sys.exit(1 if missing else 0)
PY

step "Validating"

# 1. The structural subset check that pack-central runs in CI. This is the gate
#    the current in-tree Coder pack fails with 27 errors.
checker="$pack_central/validator/check-values-structure.py"
[[ -f "$checker" ]] || die "validator not found at $checker"
python3 "$checker" \
	"$pack_dir/values.yaml" \
	"$pack_dir/charts/coder/values.yaml" \
	coder ||
	die "pack values.yaml is not a structural subset of the chart values"
log "structural subset check passed"

# 2. Prove overrides actually reach Helm. Rendering with only the pack's own
#    chart subtree must produce the expected image, and flipping a value in
#    that subtree must change the render. A pack that ignores its own values
#    renders identically either way, which is how the previous version was
#    broken without anyone noticing.
yq -r '.charts.coder' "$pack_dir/values.yaml" >"$work/render-values.yaml"
rendered="$(helm template coder "$pack_dir/charts/coder" -f "$work/render-values.yaml" |
	grep -oE "$IMAGE_REPO:v[0-9]+\.[0-9]+\.[0-9]+" | sort -u)"
[[ "$rendered" == "$IMAGE_REPO:v$version" ]] ||
	die "render produced image '$rendered', expected '$IMAGE_REPO:v$version'"
log "render produces $rendered"

yq '.coder.image.repo = "example.invalid/override-probe"' "$work/render-values.yaml" \
	>"$work/probe-values.yaml"
if ! helm template coder "$pack_dir/charts/coder" -f "$work/probe-values.yaml" |
	grep -q 'example.invalid/override-probe'; then
	die "override probe did not reach the rendered manifests. charts.coder is nested at the wrong depth and every user value would be silently ignored."
fi
log "override probe reached the rendered manifests"

# 3. Every declared image must be resolvable, which is what pack-central's
#    validate_content does.
while read -r img; do
	[[ -n "$img" ]] || continue
	crane manifest "$img" >/dev/null 2>&1 || die "cannot resolve image $img"
	log "resolved $img"
done < <(yq -r '.pack.content.images[].image' "$pack_dir/values.yaml")

# 4. Required files, per validate_logo, validate_readme and validate_charts_exist.
for required in pack.json values.yaml README.md logo.png "$chart_archive"; do
	[[ -f "$pack_dir/$required" ]] || die "missing required file: $required"
done
jq empty "$pack_dir/pack.json" || die "pack.json is not valid JSON"
log "required files present"

step "Writing pack-summary.md"

summary="$outdir/pack-summary.md"
cat >"$summary" <<EOF
Generated by \`scripts/spectro/build-pack.sh $version\` in coder/packages.

| Field | Value |
| --- | --- |
| Pack version | \`$version\` |
| Chart source | \`$CHART_REPO/coder_helm_$version.tgz\` |
| Chart sha256 | \`$expected_digest\` (verified against \`$CHART_REPO/index.yaml\`) |
| Chart version / appVersion | \`$chart_version\` / \`$chart_app_version\` |
| Image | \`$IMAGE_REPO:v$version\` |
| pack.json name / displayName | \`$got_name\` / \`$got_display\` (unchanged) |

Offline validation that passed:

- Chart tarball sha256 matches the digest published in the chart index.
- Repackaged \`$chart_archive\` reports chart version \`$version\`, so the archive name and its contents agree.
- \`validator/check-values-structure.py\` exits 0: \`charts.coder\` is a structural subset of the chart values.
- \`helm template\` with the pack's own \`charts.coder\` subtree renders \`$IMAGE_REPO:v$version\`.
- An override probe injected into \`charts.coder\` reaches the rendered manifests, confirming pack values are not inert.
- \`crane manifest\` resolves every entry in \`pack.content.images\`.
- \`pack.json\`, \`values.yaml\`, \`README.md\`, \`logo.png\` and the chart archive are all present; \`logo.png\` is byte-identical to the previous version.

Not yet covered: validation against a live Palette tenant. Coder is working with
Spectro Cloud on a partner tenant, after which registry sync and cluster profile
validation will be added to this pipeline.
EOF
log "wrote ${summary}"

step "Done"
printf '\nPack written to %s\n' "$pack_dir" >&2
printf 'Summary written to %s\n\n' "$summary" >&2
