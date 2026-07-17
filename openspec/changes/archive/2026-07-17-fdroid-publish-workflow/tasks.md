## 1. GitLab fdroiddata access setup

- [x] 1.1 ⚠️ **MANUAL**: Generate an SSH deploy key pair for the fdroiddata GitLab repo (if none exists) and add the public key to `https://gitlab.com/gmag11/fdroiddata/-/settings/repository` as a Deploy Key with write access
- [x] 1.2 ⚠️ **MANUAL**: Add the private SSH key as a GitHub secret (`FDROID_DATA_SSH_KEY`) in the Pocket2FA repo settings
- [x] 1.3 ⚠️ **MANUAL**: Create a GitLab Personal Access Token at `https://gitlab.com/-/user_settings/personal_access_tokens` with `api` scope, and add it as a GitHub secret (`FDROID_DATA_PAT`) in the Pocket2FA repo settings
- [x] 1.4 Look up the numeric project ID of `fdroid/fdroiddata` via `GET /projects/fdroid%2Ffdroiddata` on `gitlab.com/api/v4` → **36528**, hardcoded in the workflow as `FDROID_FDROIDDATA_PROJECT_ID`
- [x] 1.5 Verify SSH connectivity from a test workflow step: `ssh -T -o StrictHostKeyChecking=accept-new git@gitlab.com`

## 2. Workflow scaffold

- [x] 2.1 Create `.github/workflows/fdroid-update-metadata.yml` with `workflow_run` trigger on `release-build-android.yml` completion (types: `[completed]`), filtered to `github.event.workflow_run.conclusion == 'success'`
- [x] 2.2 Add `workflow_dispatch` trigger for manual runs
- [x] 2.3 Add `concurrency: fdroid-metadata-push` group to prevent parallel execution
- [x] 2.4 Configure `permissions: contents: read` (no write needed for the source repo)
- [x] 2.5 Add `actions: read` permission for downloading artifacts from the build workflow (if needed)

## 3. Version information extraction

- [x] 3.1 Add a step to checkout the source repo at the release tag (or the commit that triggered the build)
- [x] 3.2 Extract `versionName` and `versionCode` from `pubspec.yaml` using `sed` (e.g., `sed -n 's/^version: \(.*\)+\(.*\)/\1/p' pubspec.yaml` for versionName)
- [x] 3.3 Capture the full commit SHA via `${{ github.sha }}` (or the release tag ref)
- [x] 3.4 Compute per-ABI version codes: `baseVersionCode * 10 + 1` (armeabi-v7a), `+2` (arm64-v8a), `+3` (x86_64) using shell arithmetic

## 4. Metadata generation script

- [x] 4.1 Embed logic directly in the workflow as shell steps (heredoc-based YAML generation inside the `generate build entries` step)
- [x] 4.2 Read existing `metadata/net.gmartin.pocket2fa.yml` from the fdroiddata clone
- [x] 4.3 Check if build entries for the current `versionName` already exist; if yes, skip generation and exit with a warning
- [x] 4.4 Extract the Flutter version from `.github/workflows/release-build-android.yml` using: `sed -n -E "s/.*flutter-version: '(.*)'/\1/p"`
- [x] 4.5 Generate three build entries following the exact structure of the existing entries (path mirroring with `/home/runner/work/Pocket2FA/Pocket2FA`, PUB_CACHE config, `--target-platform` per ABI, NDK `28.2.13676358`)
- [x] 4.6 Construct correct `binary` URLs: `https://github.com/gmag11/Pocket2FA/releases/download/<versionName>/app-<abi>-release.apk`
- [x] 4.7 Append new entries at the end of the `Builds:` list, preserving existing entries and YAML formatting (consistent indentation, blank line between entries)

## 5. Git push to fdroiddata fork

- [x] 5.1 Add a step to clone `git@gitlab.com:gmag11/fdroiddata.git` with `ref: net.gmartin.pocket2fa` and shallow depth
- [x] 5.2 Configure SSH agent with the `FDROID_DATA_SSH_KEY` secret, using `webfactory/ssh-agent@v0.9.1`
- [x] 5.3 Run the metadata generation script, passing version info as environment variables
- [x] 5.4 If the metadata file changed, commit with message: `feat: add build entries for v<versionName>` and push to `net.gmartin.pocket2fa`
- [x] 5.5 If no changes (version already exists), log a notice and exit successfully

## 6. Reporting and verification

- [x] 6.1 Add a final step that outputs a workflow summary: version updated, commit SHA, link to fdroiddata commit (if pushed)
- [x] 6.2 Add a verification step: after push, re-clone the fdroiddata repo briefly and confirm the new entries appear in the YAML file
- [x] 6.3 ⚠️ **MANUAL**: Test the workflow end-to-end: trigger manually via `workflow_dispatch` and verify metadata appears at `https://gitlab.com/gmag11/fdroiddata/-/blob/net.gmartin.pocket2fa/metadata/net.gmartin.pocket2fa.yml`

## 7. GitLab Merge Request creation

- [x] 7.1 Add a step after successful push that calls the GitLab API to create a cross-project MR: `POST https://gitlab.com/api/v4/projects/<fdroid-fdroiddata-id>/merge_requests`
- [x] 7.2 Set MR parameters: `source_branch: net.gmartin.pocket2fa`, `target_branch: master`, `target_project_id: <fdroid/fdroiddata numeric ID>`, `title: net.gmartin.pocket2fa: update to v<versionName>`, `remove_source_branch: false`
- [x] 7.3 Construct the MR description using the "App Update" template with filled checklists for: inclusion criteria ✅, tagged releases ✅, multiple APKs ✅, Fastlane metadata ⬜, git submodules ⬜, `fdroid build` ⬜
- [x] 7.4 Authenticate the API call using the `FDROID_DATA_PAT` secret as a `PRIVATE-TOKEN` header
- [x] 7.5 If an MR for the same branch already exists (API returns 409), log that the MR already exists and exit successfully instead of failing
- [x] 7.6 Output the MR URL in the workflow summary so the developer can review and monitor the F-Droid review process
