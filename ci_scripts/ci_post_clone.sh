#!/bin/sh
# ci_post_clone.sh
# This script runs after the repo has been cloned and before the Xcode build process starts.

# Ensure the script exits on any error
set -e


# Use CI_XCODE_PROJECT if set, otherwise find the .xcodeproj in the current directory
if [ -z "$CI_XCODE_PROJECT" ]; then
    echo "CI_XCODE_PROJECT not set, searching for Xcode project..."
    XCODE_PROJECT_PATH=$(find . -name "*.xcodeproj" -maxdepth 1 | head -1)

    if [ -n "$XCODE_PROJECT_PATH" ]; then
        APP_NAME=$(basename "$XCODE_PROJECT_PATH" .xcodeproj)
        echo "Found Xcode project: $APP_NAME"
    else
        echo "No Xcode project found in the current directory."
        exit 1  # Exit if no project is found
    fi
else
    APP_NAME=$(basename "$CI_XCODE_PROJECT" .xcodeproj)
    echo "Using CI_XCODE_PROJECT: $APP_NAME"
fi

# Define the path to where Secrets.plist should be stored in your project
SECRETS_PLIST_PATH="./$APP_NAME/Secrets.plist"

# Your GitHub repository URL for Secrets.plist
# Replace `your_username` and `your_repo` with your actual GitHub account and repository details
GITHUB_REPO_URL="https://api.github.com/repos/swiftlysingh/AppKeys/contents/$APP_NAME/Secrets.plist?ref=main"

# Use curl to download Secrets.plist from the private GitHub repo
# Assumes GITHUB_TOKEN is set in your Xcode Cloud environment variables and marked as secret
curl -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" -L $GITHUB_REPO_URL -o "$SECRETS_PLIST_PATH"

echo "Secrets.plist has been successfully downloaded and placed at $SECRETS_PLIST_PATH"

