#!/bin/bash
# Script to generate a Kubernetes patch from CAST.AI recommendations and create a Github PR

set -e

# Default values
NAMESPACE="default"
BRANCH_PREFIX="update-resources"
COMMIT_MESSAGE_PREFIX="Update resource requests for"
PR_DESCRIPTION="This PR updates the Kubernetes resource requests/limits based on CAST.AI recommendations to optimize resource usage and cost."

# Function to display help
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --cluster-id <id>       CAST.AI cluster ID (required)"
  echo "  --api-key <key>         CAST.AI API key (required)"
  echo "  --workload <n>          Name of the workload to update (required)"
  echo "  --namespace <ns>        Namespace of the workload (default: 'default')"
  echo "  --repo-path <path>      Path to the git repository (required)"
  echo "  --manifest-path <path>  Path to the K8s manifest file relative to repo root (required)"
  echo "  --container <n>         Container name to update (default: updates all containers)"
  echo "  --dry-run               Only generate the patch without applying changes"
  echo "  --output <file>         Write patch to specified file (default: <workload>-patch.json)"
  echo "  --help                  Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 --cluster-id abc123 --api-key xyz789 --workload frontend --repo-path ./my-k8s-repo --manifest-path deployment/frontend.yaml"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --cluster-id)
      CLUSTER_ID="$2"
      shift 2
      ;;
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    --workload)
      WORKLOAD="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --repo-path)
      REPO_PATH="$2"
      shift 2
      ;;
    --manifest-path)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --container)
      CONTAINER="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$CLUSTER_ID" ] || [ -z "$API_KEY" ] || [ -z "$WORKLOAD" ]; then
  echo "Error: Missing required parameters"
  show_help
  exit 1
fi

# Set default output file if not specified
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="${WORKLOAD}-patch.json"
fi

# Ensure parser script is available and executable
PARSER_SCRIPT="./workload-recommendation-parser.py"
if [ ! -f "$PARSER_SCRIPT" ]; then
  echo "Error: Parser script not found: $PARSER_SCRIPT"
  exit 1
fi
chmod +x "$PARSER_SCRIPT"

echo "Fetching recommendations for $WORKLOAD in namespace $NAMESPACE..."

# Set container param if specified
CONTAINER_PARAM=""
if [ ! -z "$CONTAINER" ]; then
  CONTAINER_PARAM="--container $CONTAINER"
fi

# Generate the patch
"$PARSER_SCRIPT" \
  --cluster-id "$CLUSTER_ID" \
  --api-key "$API_KEY" \
  --name "$WORKLOAD" \
  --namespace "$NAMESPACE" \
  --output-file "$OUTPUT_FILE" \
  --pretty \
  $CONTAINER_PARAM

# Check if we got a valid patch
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "Error: Failed to generate a patch for $WORKLOAD"
  exit 1
fi

echo "Patch file generated: $OUTPUT_FILE"

# Show the patch contents
echo "Patch contents:"
cat "$OUTPUT_FILE"

# If dry run, exit here
if [ "$DRY_RUN" = true ]; then
  echo "Dry run complete. No changes applied."
  exit 0
fi

# If no repo path specified, exit here
if [ -z "$REPO_PATH" ] || [ -z "$MANIFEST_PATH" ]; then
  echo "No repository or manifest path specified. Patch generation complete."
  exit 0
fi

# Check repository path exists
if [ ! -d "$REPO_PATH" ]; then
  echo "Error: Repository directory does not exist: $REPO_PATH"
  exit 1
fi

# Store the current directory to return to later
CURRENT_DIR=$(pwd)

# Full path to the manifest file
FULL_MANIFEST_PATH="$REPO_PATH/$MANIFEST_PATH"
if [ ! -f "$FULL_MANIFEST_PATH" ]; then
  echo "Error: Manifest file does not exist: $FULL_MANIFEST_PATH"
  exit 1
fi

# Git operations
cd "$REPO_PATH"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
  echo "Error: $REPO_PATH is not a git repository"
  exit 1
fi

# Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Create a new branch
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BRANCH_NAME="${BRANCH_PREFIX}-${WORKLOAD}-${TIMESTAMP}"
echo "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Apply the patch to the manifest
echo "Applying patch to manifest: $MANIFEST_PATH"
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl not found. Cannot apply patch to manifest."
  exit 1
fi

# Apply the patch using kubectl
TMP_FILE=$(mktemp)

# Get the absolute path to the patch file
if [ "$REPO_PATH" = "./" ] || [ "$REPO_PATH" = "." ]; then
  # If repo path is current directory, use the path relative to current dir
  PATCH_PATH="$CURRENT_DIR/$OUTPUT_FILE"
else
  # If repo path is somewhere else, use the path relative to repo dir
  PATCH_PATH="$CURRENT_DIR/$OUTPUT_FILE"
fi

echo "Using patch file: $PATCH_PATH"
kubectl patch --local -f "$MANIFEST_PATH" --patch-file "$PATCH_PATH" -o yaml > "$TMP_FILE"
mv "$TMP_FILE" "$MANIFEST_PATH"

# Show the changes
echo "Changes to $MANIFEST_PATH:"
git diff "$MANIFEST_PATH"

# Commit changes
COMMIT_MESSAGE="${COMMIT_MESSAGE_PREFIX} ${WORKLOAD}"
echo "Committing changes: $COMMIT_MESSAGE"
git add "$MANIFEST_PATH"
git commit -m "$COMMIT_MESSAGE"

# Configure git to use the token for authentication
# This is crucial for GitHub Actions
if [ ! -z "${GITHUB_TOKEN}" ]; then
  # Get the repository name from remote URL or environment variable
  if [ ! -z "${GITHUB_REPOSITORY}" ]; then
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  else
    GITHUB_REPOSITORY=$(git remote get-url origin | sed -e 's/.*github.com[:\/]\(.*\)\.git/\1/')
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  fi
  
  # Set the authenticated remote URL
  git remote set-url origin "${REPO_URL}"
  echo "Configured Git with token authentication"
fi

# Push the branch
echo "Pushing branch $BRANCH_NAME to origin"
git push -u origin "$BRANCH_NAME"

# Create PR if GitHub CLI is available
if command -v gh &> /dev/null; then
  echo "Creating pull request..."
  PR_TITLE="${COMMIT_MESSAGE_PREFIX} ${WORKLOAD}"
  
  # If GITHUB_TOKEN is set, we don't need to do extra auth for gh CLI
  # gh CLI will use the token automatically
  
  gh pr create \
    --title "$PR_TITLE" \
    --body "$PR_DESCRIPTION" \
    --base "$CURRENT_BRANCH" \
    --head "$BRANCH_NAME"
    
  echo "Pull request created successfully!"
else
  echo "GitHub CLI (gh) not found. Please create a PR manually."
  echo "Branch: $BRANCH_NAME"
fi

# Return to original branch
git checkout "$CURRENT_BRANCH"

# Return to the original directory
cd "$CURRENT_DIR"

echo "Process completed successfully!"