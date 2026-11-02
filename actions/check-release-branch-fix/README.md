# Check Release Branch Fix

Enforces "fix main first" on release branches. On a pull request into `release/*`, it fails unless every commit's patch is already on `main` (compared with `git cherry`, so a `git cherry-pick -x` of the main commit passes). Merge commits in the PR fail too.

## Usage

```yaml
on:
  pull_request:
    branches:
      - 'release/**'

permissions:
  contents: read

jobs:
  check_release_branch_fix:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request' && startsWith(github.base_ref, 'release/')
    steps:
      - uses: actions/checkout@<commit-sha>
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - uses: PG-Momik/shared-actions/actions/check-release-branch-fix@<commit-sha>
```

`fetch-depth: 0` is required. The action fetches `main` and the release branch itself.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `base-branch` | no | `github.base_ref` | The release branch the PR targets |
| `trunk-branch` | no | `main` | The branch fixes must land on first |

## Tests

```bash
node --test actions/check-release-branch-fix/test/*.test.js
```
