# Ship To Production

Turns a release branch into a production deploy. It checks that the last successful `staging` deployment (from GitHub deployments) was the release branch tip, creates the version tag (`release/2026.11.1` becomes `v2026.11.1`), pushes it, starts the deploy workflow on that tag, then waits for the run to finish. A version tag is the approval, and `resolve-environment` only accepts a deploy on it when a push or this action's bot started it.

- Staging has not deployed the tip: fails with `staging has not deployed <sha>`.
- The tag already exists on another commit: fails.
- The tag already exists on the tip: it is not recreated, only the deploy is restarted (re-run case).

```yaml
on:
  workflow_dispatch:
    inputs:
      release-branch:
        required: true
jobs:
  ship:
    runs-on: ubuntu-latest
    environment: ship-to-production
    timeout-minutes: 60
    permissions:
      contents: write
      actions: write
      deployments: read
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: PG-Momik/shared-actions/actions/ship-to-production@<commit-sha>
        with:
          release-branch: ${{ inputs.release-branch }}
          deploy-workflow: deploy.yml
```

The job needs `contents: write`, `actions: write`, `deployments: read`, `fetch-depth: 0`, a 60 minute job timeout (it waits for the whole deploy), and must run inside the `ship-to-production` GitHub Environment so only engineering leads can approve it.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `release-branch` | yes | | Release branch to ship |
| `deploy-workflow` | yes | | Workflow file name to start on the tag |

## Outputs

| Output | Description |
|--------|-------------|
| `tag` | The version tag that was shipped |
| `sha` | The commit the tag points to |
| `deploy-run-url` | URL of the production deploy run |

## Tests

```bash
node --test actions/ship-to-production/test/*.test.js
```
