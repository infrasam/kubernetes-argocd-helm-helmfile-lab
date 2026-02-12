#!/usr/bin/bash

set -euo pipefail

generated_dir="generated"
base_dir="$(pwd)"
declare -a envs=("cl-infrasam-prod" "cl-infrasam-test" "cl-infrasam-dev")
echo "Base directory: $base_dir"

cleanup() {
  cd "$base_dir"
}

trap cleanup EXIT

rm -rf "$generated_dir"

for release_path in releases/*; do
  for env_dir in "${envs[@]}"; do
    if [[ -d "$release_path" ]]; then
      release_name="${release_path##*/}"
      if [[ "$release_name" == "template" ]]; then
        continue
      fi

      echo "Generating manifests for $release_name in $env_dir"

      output_dir="$base_dir/$generated_dir/$env_dir/$release_name"
      mkdir -p "$output_dir"

      pushd "$release_path" >/dev/null
      helmfile -e "$(echo "$env_dir")" template --skip-tests --include-crds --log-level error >"$base_dir/$generated_dir/$env_dir/$release_name/manifest.lock.yaml"
      manifest="$base_dir/$generated_dir/$env_dir/$release_name/manifest.lock.yaml"
      if [ -f "$manifest" ] && [ ! -s "$manifest" ]; then
        echo "Manifest for $release_name in $env_dir is empty. Removing it."
        rm "$manifest"
      fi
      popd >/dev/null
    fi
  done
done

echo "Combined YAML files written to $generated_dir"
