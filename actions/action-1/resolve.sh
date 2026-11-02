#!/usr/bin/env bash
set -euo pipefail

if [[ ${TRUNK_BASED:-false} == true ]]; then
  version='20[0-9]{2}\.[0-9]{2}\.[0-9]+(\.[0-9]+)?'
  if [[ ${VERSION_SCHEME:-calver} == semver ]]; then
    # SemVer major is capped at 3 digits so a CalVer name (2026.10.3) is not read as SemVer.
    version='[0-9]{1,3}\.[0-9]+\.[0-9]+(\.[0-9]+)?'
  fi
  case ${GITHUB_REF:-} in
    refs/heads/main) environment=dev ;;
    refs/heads/release/*)
      if [[ $GITHUB_REF =~ ^refs/heads/release/$version$ ]]; then
        environment=staging
      fi
      ;;
    refs/tags/v*)
      if [[ $GITHUB_REF =~ ^refs/tags/v($version)$ ]]; then
        # A version tag is the approval, so only a push or the Ship to production run may deploy it.
        if [[ ${GITHUB_EVENT_NAME:-} == workflow_dispatch && ${GITHUB_ACTOR:-} != 'github-actions[bot]' ]]; then
          echo "Manual run on a version tag is not allowed. Use the Ship to production workflow." >&2
          exit 1
        fi
        environment=production
        release_branch=release/${BASH_REMATCH[1]}
      fi
      ;;
  esac
  if [[ -z ${environment:-} ]]; then
    echo "Unsupported deploy ref: ${GITHUB_REF:-none}" >&2
    exit 1
  fi
else
  production_branch=main
  if [[ ${USE_MASTER:-false} == true ]]; then
    production_branch=master
  fi
  case ${GITHUB_REF_NAME:-} in
    dev) environment=dev ;;
    staging) environment=staging ;;
    "$production_branch") environment=production ;;
    *) environment=${DEFAULT_ENVIRONMENT:-dev} ;;
  esac
fi

echo "environment=$environment" >> "$GITHUB_OUTPUT"
if [[ -n ${release_branch:-} ]]; then
  echo "release_branch=$release_branch" >> "$GITHUB_OUTPUT"
fi
echo "Resolved environment: $environment (${GITHUB_REF:-unknown})"
