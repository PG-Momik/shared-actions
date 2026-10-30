#!/usr/bin/env bash
set -euo pipefail

ref=${GIT_REF:?}
branch=${ref#refs/heads/}
release_branch=

if [[ ${TRUNK_BASED:-false} == true ]]; then
  case ${VERSION_SCHEME:-calver} in
    calver) version='[0-9]{4}\.[0-9]{2}\.[0-9]+(\.[0-9]+)?' ;;
    semver) version='[0-9]{1,3}\.[0-9]+\.[0-9]+' ;;
    *) echo 'Invalid version scheme' >&2; exit 1 ;;
  esac
  if [[ $ref == refs/heads/main ]]; then
    environment=dev
  elif [[ $ref =~ ^refs/heads/release/($version)$ ]]; then
    environment=staging
  elif [[ $ref =~ ^refs/tags/v($version)$ ]]; then
    environment=production
    release_branch="release/${BASH_REMATCH[1]}"
  else
    echo "Unknown trunk ref: $ref" >&2
    exit 1
  fi
else
  prod_branch=main
  [[ ${USE_MASTER:-false} == true ]] && prod_branch=master
  case $branch in
    dev) environment=dev ;;
    staging) environment=staging ;;
    "$prod_branch") environment=production ;;
    *) environment=${DEFAULT_ENVIRONMENT:-dev} ;;
  esac
fi

echo "environment=$environment" >> "$GITHUB_OUTPUT"
echo "release-branch=$release_branch" >> "$GITHUB_OUTPUT"
echo "Resolved environment: $environment"
