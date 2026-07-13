## Context

Pocket2FA publishes release APKs via GitHub Actions (`release-build-android.yml`) to GitHub Releases. The F-Droid ecosystem requires a metadata file (`metadata/net.gmartin.pocket2fa.yml`) in the `fdroiddata` repository that describes each release: version name, version code, commit SHA, build instructions, and binary URLs for each ABI.

Currently, updating this metadata is manual. The developer must:
1. Wait for the GitHub Release to complete
2. Copy the version info from `pubspec.yaml`
3. Compute version codes (base versionCode × 10 + ABI offset)
4. Get the release commit SHA
5. Add 3 new build entries (one per ABI) to the YAML file
6. Commit and push to the fdroiddata fork

The fdroiddata fork lives at `https://gitlab.com/gmag11/fdroiddata/` on branch `net.gmartin.pocket2fa`. The metadata file currently contains build entries for v0.9.16 (3 ABIs × 1 version = 3 entries).

## Goals / Non-Goals

**Goals:**
- Automatically update `metadata/net.gmartin.pocket2fa.yml` with new build entries when a GitHub Release is published
- Extract version info from the repository (pubspec.yaml) and the release payload
- Generate correct version codes following the `VercodeOperation` scheme (base × 10 + ABI offset: 1=armeabi-v7a, 2=arm64-v8a, 3=x86_64)
- Construct build entries matching the existing YAML structure (path mirroring, Flutter version extraction, PUB_CACHE configuration, NDK pinning)
- Push the updated metadata to the GitLab fdroiddata fork
- Create a GitLab Merge Request against upstream `fdroid/fdroiddata` using the "App Update" template
- Work both on release publish and manual trigger (workflow_dispatch)

**Non-Goals:**
- Modifying the existing `release-build-android.yml` workflow
- Handling F-Droid build server submission or review
- Updating other metadata fields (description, screenshots, categories)

## Decisions

### 1. Trigger mechanism: `workflow_run` on release-build-android completion

**Chosen:** `workflow_run` trigger on `release-build-android.yml` completion, filtered to `completed` status.

**Rationale:** The metadata update depends on the APK build being done and the release being created. Using `workflow_run` ensures the Android workflow has uploaded APKs to the release before we try to reference binary URLs. The workflow file is completely decoupled from the build workflow.

**Alternative considered:** `release: [published]` event — simpler but timing risk: the build workflow uploads APKs to the release asynchronously. If the metadata workflow fires on release publish before APKs are attached, the binary URLs won't exist yet. The `workflow_run` approach guarantees APKs are uploaded first.

### 2. Git operations: SSH deploy key for push + GitLab PAT for MR API

**Chosen:** SSH deploy key for pushing commits to the GitLab fdroiddata fork, plus a GitLab Personal Access Token for creating the Merge Request via the GitLab API.

**Rationale:** SSH deploy keys are repo-scoped and don't expire — ideal for `git push`. The GitLab Merge Request API requires a PAT (or OAuth token) with `api` scope. This combination gives us secure push access plus the ability to create MRs programmatically.

**Alternative considered:** GitLab PAT for both push and API — simpler single credential but PATs expire and have broader scope. SSH key for push is more secure and maintenance-free.

### 3. YAML generation: template-based with `yq` (or Python script)

**Chosen:** Python script using `ruamel.yaml` or a template-substitution approach with `sed`.

**Rationale:** The build entries must be inserted at the end of the `Builds:` list in the YAML file. The structure is repetitive but requires precise indentation and formatting. A Python script gives control over YAML parsing, version code computation, and safe insertion without corrupting the file.

**Alternative considered:** `yq` (command-line YAML processor) — simpler if installed, but adds a dependency and has version-compatibility issues between Go-based and Python-based `yq`. Python is pre-installed on GitHub runners.

### 4. Flutter version extraction: read from existing CI workflow

**Chosen:** Extract Flutter version from `release-build-android.yml` using `sed`, same approach the F-Droid recipe uses.

**Rationale:** Single source of truth. When the developer updates Flutter in the CI workflow, the F-Droid recipe and this automation both pick it up automatically.

### 5. Merge Request creation: GitLab API with "App Update" template

**Chosen:** Create the MR via GitLab API (`POST /projects/:id/merge_requests`) using the "App Update" template as the MR description body.

**Rationale:** The F-Droid project expects MRs against `fdroid/fdroiddata` to follow the "App Update" template. Using the GitLab API we can set:
- `source_branch`: `net.gmartin.pocket2fa` (our fork branch)
- `target_branch`: `master` (upstream fdroiddata)
- `target_project_id`: `fdroid/fdroiddata` (cross-project MR)
- `title`: `net.gmartin.pocket2fa: update to v<versionName>` (starts with app name as required)
- `description`: the filled "App Update" template with checklist items

The template includes the required checklist (inclusion criteria, fdroiddata issues, `fdroid build` verification) and the MR description boilerplate. The workflow fills in the version-specific fields.

**Alternative considered:** Manual MR creation — defeats the purpose of automation. The whole point is zero-touch after release.

## Risks / Trade-offs

- **[Version code collision]** → If a release is re-published with the same version, duplicate build entries could be added. Mitigation: check if build entries for this version already exist before appending.
- **[GitLab SSH key rotation]** → If the SSH key is compromised or lost, the workflow silently fails. Mitigation: workflow step explicitly verifies SSH connectivity before commit.
- **[GitLab PAT expiration]** → GitLab PATs have a maximum lifespan (typically 1 year). If the token expires, MR creation fails. Mitigation: document renewal procedure; the push still succeeds via SSH, only the MR step fails.
- **[YAML formatting drift]** → If the fdroiddata YAML schema changes (e.g., new required fields), generated entries may be rejected. Mitigation: the script uses the existing last entry as a structural template, making it resilient to minor schema evolution.
- **[Concurrent releases]** → Two releases published in quick succession could race on the fdroiddata repo. Mitigation: use a concurrency group in the workflow to serialize metadata pushes.
