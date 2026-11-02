# Rulesets

Repo rulesets for trunk-based repos, kept here so they are versioned and identical across repos.

| File | Target | What it does |
|------|--------|--------------|
| `trunk.json` | `refs/heads/main` | Squash-only pull requests with 1 approval, no merge commits, merge queue, required checks. Repository admins can bypass with a pull request only (break-glass). |
| `release-branch-create.json` | `refs/heads/release/*` | Only bypass actors can create or delete a release branch: the GitHub Actions app (id 15368) and repository admins. |
| `release-branch.json` | `refs/heads/release/*` | Squash-only pull requests with 1 approval, no merge commits, no force push, required checks include `check-release-branch-fix`. Repository admins can bypass with a pull request only. |
| `version-tag-create.json` | `refs/tags/v*` | Only the GitHub Actions app and repository admins can create a version tag. |
| `version-tag-protect.json` | `refs/tags/v*` | Nobody can move or delete a version tag. `bypass_actors` is empty on purpose. |

Nothing is signed: no ruleset has `required_signatures`.

Why five files: a bypass covers every rule in its ruleset. Keeping "create" apart from "protect" means an actor that may create a branch or tag cannot also skip pull requests or move a tag.

Who can do what:

- Merge to `main`: anyone through a reviewed pull request and the merge queue. Repository admins can bypass with a pull request.
- Create a release branch: the Cut release branch workflow (Actions app) or repository admins.
- Change a release branch: reviewed pull request with 1 approval, and the change must already be on `main`. Repository admins can bypass with a pull request.
- Create a version tag: the Ship to production workflow (Actions app) or repository admins.
- Move or delete a version tag: nobody.

Before applying `trunk.json` or `release-branch.json`, edit the `context` names under `required_status_checks` to match the job names that repo really reports. They are set to `Required check 1` to `Required check 4` (plus `check-release-branch-fix` for release branches).

Who may run the Cut release branch and Ship to production workflows is controlled by the caller's `workflow_dispatch` workflows, using GitHub environments of the same names with required reviewers (repository admins).

Apply to a repo:

```bash
gh api -X POST repos/PG-Momik/<repo>/rulesets --input rulesets/version-tag-create.json
```

Update an existing one (find the id with `gh api repos/PG-Momik/<repo>/rulesets`):

```bash
gh api -X PUT repos/PG-Momik/<repo>/rulesets/<id> --input rulesets/version-tag-create.json
```

`bypass_mode: always` on a creation ruleset means "this actor is allowed to do the restricted thing". It is the only way to say "only this actor may create tags" in a ruleset: the rule blocks everyone, the bypass lets them through.
