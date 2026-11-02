# shared-actions

Dummy shared actions and workflows for a CI/CD flow demo.

## Trunk-based release actions

- `actions/cut-release-branch`: cuts a `release/<version>` branch from `main`.
- `actions/ship-to-production`: tags a release branch and runs the production deploy.
- `actions/check-release-branch-fix`: checks that a pull request into a release branch is already on `main`.
- `actions/promote-image`: promotes an already built image to the next environment.
- `actions/action-1`: works out the environment (and release branch) for the current ref.
- `actions/action-3`: records a production deploy, or creates or publishes the GitHub Release.

The matching branch rulesets are in `rulesets/`.
