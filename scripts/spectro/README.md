# Spectro Cloud Palette pack pipeline

Keeps the Coder community pack in
[spectrocloud/pack-central](https://github.com/spectrocloud/pack-central) in
step with the stable Coder release.

## Why this exists

Palette community packs are maintained by the contributing vendor, not by
Spectro Cloud. Nothing about merging a pack creates an obligation on their side
to update it, and Palette deprecates a pack minor once two newer minors exist,
then disables it after three months and deletes it three months after that. A
pack that nobody republishes ages out of Palette on its own.

The first Coder pack was assembled by hand and drifted accordingly. It was
published as `coder-2.23.3` but shipped upstream chart content from 2.21.3,
because `Chart.yaml` was version-bumped without re-vendoring the chart body. Its
`values.yaml` also nested the chart values one level too shallow, so every
override a Palette user set was silently discarded and the deployment always ran
chart defaults.

Both defects came from hand edits, and both are the kind of thing a generator
plus an assertion catches for free. Hence this directory.

## Contents

| Path | Purpose |
| --- | --- |
| `build-pack.sh` | Builds `packs/coder-<version>/` from the published Helm chart and validates it. |
| `pack-README.md` | Template for the pack's own README, required per pack version by pack-central. `__VERSION__` is substituted at build time. |

The workflow that drives this on a release is
`.github/workflows/publish-spectro-pack.yaml`.

## Running it locally

```sh
git clone https://github.com/spectrocloud/pack-central.git /tmp/pack-central

PACK_CENTRAL_DIR=/tmp/pack-central \
  ./scripts/spectro/build-pack.sh 2.35.6
```

Output lands in `./build/spectro/packs/coder-2.35.6/` with a provenance summary
at `./build/spectro/pack-summary.md`.

Requires `helm`, `yq`, `jq`, `crane`, and `python3` with PyYAML.

## What it guarantees

The script refuses to produce a pack unless all of the following hold.

- The chart tarball's sha256 matches the digest published in
  `https://helm.coder.com/v2/index.yaml`.
- The chart body's own `version` and `appVersion` equal the requested version,
  and the repackaged archive agrees with its own filename. This is the check
  that the 2.23.3 pack would have failed.
- `pack.json` still carries `name: coder-chart` and `displayName: Coder`.
  Changing either makes Palette treat the result as a brand new pack rather than
  a new version of the existing one.
- `charts.coder` in the pack values mirrors the chart's root keys exactly, and
  pack-central's own `validator/check-values-structure.py` exits 0.
- Rendering the chart with only the pack's `charts.coder` subtree produces
  `ghcr.io/coder/coder:v<version>`, and an override probe injected into that
  subtree reaches the rendered manifests. A pack with inert values renders
  identically either way, which is exactly how the previous breakage went
  unnoticed.
- Every image in `pack.content.images` resolves with `crane manifest`.
- Every chart value path documented in the pack README still exists in the
  chart, so the parameter table cannot quietly start lying after an upstream
  rename.

## Release channel

Only stable releases produce a pack. `coder/coder` sends `release_channel` in
the `coder-release` dispatch payload, and the workflow gates on it. Stable is
roughly one release a month, which stays comfortably ahead of Palette's
deprecation clock without adding noise to a third-party repository whose review
queue is measured in weeks.

## Not yet covered

pack-central asks contributors to push the pack to their own registry and test
it in a Palette environment before opening a pull request. That step needs a
Palette tenant. Coder is working with Spectro Cloud on a partner tenant; once it
exists, the pipeline should push the pack to an OCI registry under
`spectro-packs/archive/`, register and sync it through
`POST /v1/registries/oci/basic`, and run `POST /v1/clusterprofiles/validate/packs`,
which validates a profile without deploying a cluster. Note that Palette
requires ORAS v1.0.0 specifically for pack pushes.

Until then the pull request states which offline checks ran.

## Maintenance

The pack README parameter table is hand-maintained. `build-pack.sh` verifies
that every path it documents still exists, but it cannot tell whether a
newly added chart value deserves a row. Review `pack-README.md` when upstream
adds a significant option.

The workflow also runs a weekly drift check that compares
`GET /repos/coder/coder/releases/latest`, which returns the stable release
rather than the newest tag, against the highest `packs/coder-*` directory on
pack-central. If the pack falls behind it opens a tracking issue here. That
guard exists because silent rot is the failure mode that produced the original
problem.
