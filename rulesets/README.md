# Release ruleset templates

These files are examples for repositories using the release actions. Committing them does not change repository settings. Set each repository's required check names before applying them. The templates use the repository admin role for the release lead and the built-in Actions integration for workflow-created refs. A developer with write access cannot bypass them.

Apply `trunk` to `main`, and the three release rulesets only where release branches and tags are used. Configure the `release-cut` and `release-tag` environments with the admin as required reviewer. Limit staging to `release/*` branches and production to `v*` tags. The deploy environments do not need a second approval.
