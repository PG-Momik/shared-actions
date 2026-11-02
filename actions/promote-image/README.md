# Promote Image

Copies an image from the staging ECR registry to the production one, keeping the same digest, so production runs exactly what staging tested. It copies instead of retagging because dev, staging and production are separate AWS accounts with separate registries. Use it for tag deploys only, after the same commit has been deployed to staging. If the source tag is missing it fails with a clear error, and running it twice is safe: if the target already has the same digest under the source tag, the copy is skipped and only the extra tags are written.

```yaml
- name: Promote staging image
  if: startsWith(github.ref, 'refs/tags/')
  uses: PG-Momik/shared-actions/actions/promote-image@<commit-sha>
  with:
    source-registry: ${{ vars.STAGING_ECR_REGISTRY }}
    target-registry: ${{ vars.ECR_REGISTRY }}
    repository: my-ecr-repo
```

AWS credentials must already be set up in an earlier step. That identity must be allowed to push to the target repository, and the source repository policy must allow the same role to pull from it.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `source-registry` | yes | | Registry to copy from |
| `target-registry` | yes | | Registry to copy to |
| `repository` | yes | | ECR repository name |
| `source-tag` | no | `github.sha` | Existing image tag to copy |
| `target-tags` | no | `github.sha,github.ref_name` | Comma separated tags to write |
| `region` | no | your AWS config | AWS region, passed as `--region` only when set |

## Tests

```bash
node --test actions/promote-image/test/*.test.js
```
