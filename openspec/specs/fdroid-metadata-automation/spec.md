## ADDED Requirements

### Requirement: Workflow triggers on release build completion
The system SHALL automatically trigger the F-Droid metadata update workflow when the `release-build-android.yml` workflow completes successfully on a release event. The system SHALL also support manual triggering via `workflow_dispatch`.

#### Scenario: Release build succeeds
- **WHEN** `release-build-android.yml` completes with status `success` for a `release` event
- **THEN** the F-Droid metadata update workflow starts automatically

#### Scenario: Release build fails
- **WHEN** `release-build-android.yml` completes with status `failure` for a `release` event
- **THEN** the F-Droid metadata update workflow does NOT start

#### Scenario: Manual trigger
- **WHEN** a user triggers the workflow via `workflow_dispatch`
- **THEN** the workflow runs independently of the release build status

### Requirement: Extracts version information from the repository
The system SHALL extract `versionName`, `versionCode`, and `commit` SHA from the repository state at the release tag.

#### Scenario: Version extraction from pubspec.yaml
- **WHEN** the workflow runs on a tagged release commit
- **THEN** it reads `pubspec.yaml` and extracts `version: X.Y.Z+CODE` into `versionName: X.Y.Z` and `versionCode: CODE`

#### Scenario: Commit SHA extraction
- **WHEN** the workflow runs
- **THEN** it captures the full Git commit SHA from `${{ github.sha }}` or the release tag reference

### Requirement: Computes per-ABI version codes
The system SHALL compute unique version codes for each ABI using the formula: `baseVersionCode * 10 + abi_offset`, where `abi_offset` is 1 for armeabi-v7a, 2 for arm64-v8a, and 3 for x86_64.

#### Scenario: Version code computation
- **WHEN** `versionCode` is 271
- **THEN** the armeabi-v7a versionCode is 2711, arm64-v8a is 2712, and x86_64 is 2713

### Requirement: Generates build entries for all ABI targets
The system SHALL generate three build entries (armeabi-v7a, arm64-v8a, x86_64) in the F-Droid YAML format, appended to the `Builds:` list in `metadata/net.gmartin.pocket2fa.yml`.

#### Scenario: Build entry structure
- **WHEN** generating a build entry for a given ABI
- **THEN** the entry includes all fields: `versionName`, `versionCode`, `commit`, `sudo` block, `output`, `binary`, `srclibs`, `prebuild` block, `scanignore`, `build` block, and `ndk`

#### Scenario: Binary URL construction
- **WHEN** generating a build entry for armeabi-v7a for version `0.9.17`
- **THEN** the `binary` field points to `https://github.com/gmag11/Pocket2FA/releases/download/0.9.17/app-armeabi-v7a-release.apk`

#### Scenario: Flutter version is extracted from CI workflow
- **WHEN** generating build entries
- **THEN** the `prebuild` block extracts the Flutter version from `.github/workflows/release-build-android.yml` using the same `sed` pattern the F-Droid build server uses

#### Scenario: Path mirroring mirrors CI structure
- **WHEN** generating build entries
- **THEN** the `sudo`, `prebuild`, and `build` blocks include the path-mirroring steps (`mkdir -p /home/runner/work/Pocket2FA/Pocket2FA`, `mv`, `pushd`/`popd`) matching the existing 0.9.16 entries

#### Scenario: Duplicate prevention
- **WHEN** build entries for the current version already exist in the metadata file
- **THEN** the workflow skips generation and logs a warning instead of duplicating entries

### Requirement: Publishes updated metadata to the fdroiddata fork
The system SHALL commit the updated metadata file and push it to the `net.gmartin.pocket2fa` branch of the GitLab fdroiddata fork.

#### Scenario: Successful push
- **WHEN** the metadata file has been updated with new build entries
- **THEN** the workflow commits the change with a conventional commit message (e.g., `feat: add build entries for vX.Y.Z`) and pushes to `net.gmartin.pocket2fa` at `gitlab.com:gmag11/fdroiddata.git`

#### Scenario: SSH authentication
- **WHEN** pushing to the GitLab fdroiddata fork
- **THEN** the workflow authenticates using an SSH deploy key stored as a GitHub secret (`FDROID_DATA_SSH_KEY`)

#### Scenario: Concurrency control
- **WHEN** a new workflow run starts while a previous push is in progress
- **THEN** the new run waits for the previous run to complete (via `concurrency` group)

### Requirement: Reports workflow outcome
The system SHALL report clear success or failure status, including what was changed or why it was skipped.

#### Scenario: Successful update
- **WHEN** the metadata file is pushed successfully
- **THEN** the workflow summary shows: version updated, commit SHA, and link to the fdroiddata commit

#### Scenario: No new version
- **WHEN** the current version already has build entries in the metadata file
- **THEN** the workflow completes with status `success` and a warning: "Build entries for vX.Y.Z already exist — nothing to do"

### Requirement: Creates GitLab Merge Request against upstream fdroiddata
After pushing the metadata update, the system SHALL create a GitLab Merge Request from the `net.gmartin.pocket2fa` branch of `gmag11/fdroiddata` against the `master` branch of `fdroid/fdroiddata`, using the "App Update" template.

#### Scenario: MR created successfully
- **WHEN** the metadata push to `net.gmartin.pocket2fa` succeeds
- **THEN** the workflow creates a GitLab MR via the GitLab API (`POST /projects/:id/merge_requests`) with:
  - `source_branch`: `net.gmartin.pocket2fa`
  - `target_branch`: `master`
  - `target_project_id`: the numeric ID of `fdroid/fdroiddata`
  - `title`: `net.gmartin.pocket2fa: update to v<versionName>`
  - `description`: the "App Update" template with filled checklist items, referencing the new version

#### Scenario: MR title starts with app name
- **WHEN** creating the MR
- **THEN** the title SHALL start with `net.gmartin.pocket2fa:` as required by the fdroiddata contribution guidelines

#### Scenario: MR description contains the full template
- **WHEN** creating the MR
- **THEN** the description SHALL contain the complete "App Update" template markdown including:
  - The "Required" checklist (inclusion criteria, related issues, `fdroid build`)
  - The "Strongly Recommended" checklist (Fastlane/Triple-T metadata, tagged releases)
  - The "Suggested" checklist (git submodules, multiple APKs)
  - The instruction boilerplate (repo public, branch not protected, FOSS CI runners)

#### Scenario: MR not created when push had no changes
- **WHEN** no metadata changes were pushed (version already exists)
- **THEN** the MR creation step is skipped

#### Scenario: MR creation authentication
- **WHEN** calling the GitLab Merge Requests API
- **THEN** the workflow authenticates using a GitLab Personal Access Token stored as a GitHub secret (`FDROID_DATA_PAT`) with `api` scope
