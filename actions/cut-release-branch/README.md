# Cut Release Branch

Creates the next release branch: `release/YYYY.MM.N` (CalVer) or the next `release/X.Y.Z` (SemVer) from `main`, or a hotfix branch like `release/2026.11.3.1` from a tag (a hotfix of a hotfix stays at four parts, such as `release/2026.11.3.2`). With `patch-of` (a rollback), the branch is named after that tag's family but cut from `hotfix-from-tag`. The number is the highest existing one plus one, so a deleted branch or skipped number never collides. It fails if the branch already exists.

After pushing the branch it starts the deploy with `gh workflow run <deploy-workflow> --ref <branch>`, because a push made with the workflow token does not trigger other workflows. The caller must run `actions/checkout` with `fetch-depth: 0` first (this fetches tags too), and must grant `contents: write` and `actions: write` on the job.

```yaml
on:
  workflow_dispatch:
jobs:
  cut:
    runs-on: ubuntu-latest
    environment: cut-release-branch
    permissions:
      contents: write
      actions: write
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: PG-Momik/shared-actions/actions/cut-release-branch@<commit-sha>
        with:
          version-scheme: calver
          deploy-workflow: deploy.yml
```

## Who can run it

The `release/*` creation ruleset (`rulesets/release-branch-create.json`) limits who can create release branches by hand. Who may run this workflow is controlled by the caller's `workflow_dispatch` workflow: put the job in a GitHub environment (we suggest `cut-release-branch`) with required reviewers.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `version-scheme` | no | `calver` | `calver` or `semver` |
| `from-ref` | no | `main` | Branch to cut from |
| `hotfix-from-tag` | no | | Cut a hotfix branch from this tag |
| `patch-of` | no | | Rollback: name the branch after this tag's version family |
| `deploy-workflow` | yes | | Workflow file name to start on the new branch |
| `semver-bump` | no | `minor` | `major`, `minor`, or `patch` (semver only) |

## Outputs

| Output | Description |
|--------|-------------|
| `release-branch` | The branch that was created |
| `from-sha` | The commit the branch was cut from |

The script reads `RELEASE_YM` (such as `2026.10`) for the month if set, otherwise the current UTC month.

## Tests

```bash
node --test actions/cut-release-branch/test/*.test.js
```
