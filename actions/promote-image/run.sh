#!/usr/bin/env bash
set -euo pipefail

source="${SOURCE_REGISTRY:?}/${REPOSITORY:?}"
target="${TARGET_REGISTRY:?}/${REPOSITORY:?}"
tag=${SOURCE_TAG:?}
[[ $tag =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid source tag' >&2; exit 1; }
for registry in "$SOURCE_REGISTRY" "$TARGET_REGISTRY"; do
  aws ecr get-login-password --region "${REGION:?}" | crane auth login -u AWS --password-stdin "$registry"
done
digest=$(crane digest "$source:$tag")
if current=$(crane digest "$target:$tag" 2>/dev/null); then
  [[ $current == "$digest" ]] || { echo 'Production image digest differs from staging' >&2; exit 1; }
else
  crane copy "$source@$digest" "$target:$tag"
  [[ $(crane digest "$target:$tag") == "$digest" ]] || { echo 'Copied image digest differs from staging' >&2; exit 1; }
fi
IFS=',' read -ra tags <<< "${TARGET_TAGS:?}"
for version in "${tags[@]}"; do
  [[ $version =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid target tag' >&2; exit 1; }
  crane tag "$target:$tag" "$version"
done
echo "Promoted $tag with digest $digest"
