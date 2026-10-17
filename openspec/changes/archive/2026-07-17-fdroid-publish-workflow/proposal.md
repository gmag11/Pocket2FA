## Why

Currently, after each release of Pocket2FA, updating the F-Droid metadata in the fdroiddata repository is a manual process: extract version info, compute version codes, copy commit SHA, update each build entry (3 ABIs), commit, and push. This is error-prone, time-consuming, and slows down releases. Automating this ensures F-Droid users get updates as soon as a GitHub Release is published, with zero manual steps.

## What Changes

- **New GitHub Actions workflow** (`fdroid-update-metadata.yml`) triggered on release publish (or workflow_dispatch) that automatically updates the F-Droid metadata in the fdroiddata fork
- **Automated metadata generation**: the workflow extracts `versionName`, `versionCode`, commit SHA, and constructs the correct build entries for all 3 ABIs (armeabi-v7a, arm64-v8a, x86_64) following the F-Droid recipe format
- **Automated push to fdroiddata**: commits the updated `metadata/net.gmartin.pocket2fa.yml` and pushes to the `net.gmartin.pocket2fa` branch of the GitLab fdroiddata fork
- **Automated Merge Request creation**: creates a GitLab MR against `fdroid/fdroiddata` using the "App Update" template, so the F-Droid maintainers can review and merge the metadata update

## Capabilities

### New Capabilities
- `fdroid-metadata-automation`: Automates the generation and publication of F-Droid metadata (version entries, build recipes, signing keys) from a completed GitHub Release, pushing changes to the developer's fdroiddata fork and creating a GitLab Merge Request against upstream `fdroid/fdroiddata` for maintainer review

### Modified Capabilities
<!-- None — this is a new workflow, not modifying existing spec-level behavior -->

## Impact

- **Affected files**: New file `.github/workflows/fdroid-update-metadata.yml`
- **External dependencies**: Requires a GitLab personal access token (`FDROID_DATA_TOKEN`) stored as a GitHub secret for MR creation via the GitLab API, plus an SSH deploy key (`FDROID_DATA_SSH_KEY`) for pushing to the fdroiddata fork
- **Repositories involved**: 
  - Source: `gmag11/Pocket2FA` (GitHub) — triggers the workflow
  - Target: `gmag11/fdroiddata` (GitLab) — receives metadata commits
- **No breaking changes**: purely additive automation
- **Integration point**: runs AFTER `release-build-android.yml` completes successfully (via `workflow_run` trigger or release event)
