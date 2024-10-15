#!/bin/sh

set -e

# Adds testflight notes
if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
  TESTFLIGHT_DIR_PATH="../TestFlight"
  mkdir -p "$TESTFLIGHT_DIR_PATH"

  # Fetch the branch name
  BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

  # Ensure you have enough commit history
  git fetch --deepen=3

  # Write the branch name as the heading
  echo "Branch: $BRANCH_NAME" > "$TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt"

  # Append the last 3 commits with hyphens
  git log -3 --pretty=format:" - %s" >> "$TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt"
fi

# Emerge Tools
required_env_vars=(
    "CI_ARCHIVE_PATH"
    "CI_BRANCH"
    "CI_COMMIT"
    "EMERGE_API_KEY"
)

for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Environment variable $var is not set"
        exit 1
    fi
done

brew install jq

zip_path="$CI_ARCHIVE_PATH.zip"
pushd $(dirname $CI_ARCHIVE_PATH)
zip -r --symlinks "$(basename $zip_path)" "$(basename $CI_ARCHIVE_PATH)"
popd

# Update this with your repo
repo_name='MyOrg/MyRepo'

tag='release'
if [[ "$CI_XCODE_SCHEME" == "My Debug Archive Scheme" ]]; then
    tag='debug'
fi

json_fields=$(cat <<EOF
"filename":"${zip_path}",
"branch":"${CI_BRANCH}",
"sha":"${CI_COMMIT}",
"repoName":"${repo_name}",
"tag":"${tag}"
EOF
)

# For previousSha (required for only some features): Check if git is available
if ! command -v git &> /dev/null; then
    echo "Git is not installed or not in PATH. Cannot fetch previous SHA."
elif ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Not in a Git repository. Cannot fetch previous SHA."
else
    if git rev-parse HEAD^ >/dev/null 2>&1; then
        previous_sha=$(git rev-parse HEAD^)
        json_fields=$(cat <<EOF
${json_fields},
"previousSha":"${previous_sha}"
EOF
        )
    fi
fi


if [[ -n "${CI_PULL_REQUEST_NUMBER}" ]]; then
    pr_required_env_vars=(
        "CI_PULL_REQUEST_NUMBER"
        "CI_PULL_REQUEST_TARGET_COMMIT"
    )

    for var in "${pr_required_env_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Environment variable $var is not set"
            exit 1
        fi
    done

    json_fields=$(cat <<EOF
${json_fields},
"prNumber":"${CI_PULL_REQUEST_NUMBER}",
"baseSha":"${CI_PULL_REQUEST_TARGET_COMMIT}"
EOF
    )
fi

upload_response=$(curl \
    --url "https://api.emergetools.com/upload" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --header "X-API-Token: $EMERGE_API_KEY" \
    --data "{$json_fields}")

# Pull the uploadURL field from the response using jq
upload_url=$(echo "$upload_response" | jq -r .uploadURL)

curl -v -H 'Content-Type: application/zip' -T "$zip_path" "$upload_url"

