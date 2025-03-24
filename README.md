# CAST.AI Resource Optimizer

Automatically optimize your Kubernetes resource configurations based on CAST.AI recommendations. This tool generates pull requests to update CPU and memory settings in your Kubernetes manifests according to actual usage patterns detected by CAST.AI.

## Features

- Fetches resource recommendations from the CAST.AI API
- Generates Kubernetes patch files in the proper format
- Creates Git branches with recommended changes
- Submits pull requests for team review
- Updates specific containers or entire workloads
- Supports dry runs for testing

## Prerequisites

- Python 3.6+
- Bash shell environment
- `kubectl` command-line tool (for applying patches)
- Git (for repository operations)
- GitHub CLI (`gh`) - optional, for automated PR creation

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/castai-resource-optimizer.git
   cd castai-resource-optimizer
   ```

2. Make scripts executable:
   ```bash
   chmod +x workload-recommendation-parser.py update_workload.sh
   ```

## Usage

### Generate a Patch File Only

If you want to just generate a patch file without applying any changes:

```bash
python workload-recommendation-parser.py \
  --cluster-id YOUR_CLUSTER_ID \
  --api-key YOUR_API_KEY \
  --name YOUR_WORKLOAD_NAME \
  --namespace YOUR_NAMESPACE \
  --output-file workload-patch.json \
  --pretty
```

### Complete Workflow with PR Creation

For a complete workflow that:
1. Gets recommendations from CAST.AI
2. Creates a patch file
3. Applies the patch to your Kubernetes manifest
4. Creates a Git branch with changes
5. Submits a PR

```bash
./update_workload.sh \
  --cluster-id YOUR_CLUSTER_ID \
  --api-key YOUR_API_KEY \
  --workload YOUR_WORKLOAD_NAME \
  --namespace YOUR_NAMESPACE \
  --repo-path ./path/to/your/repo \
  --manifest-path kubernetes/deployment.yaml
```

### Additional Options

**Update a specific container:**
```bash
./update_workload.sh \
  --cluster-id YOUR_CLUSTER_ID \
  --api-key YOUR_API_KEY \
  --workload YOUR_WORKLOAD_NAME \
  --namespace YOUR_NAMESPACE \
  --container CONTAINER_NAME \
  --repo-path ./path/to/your/repo \
  --manifest-path kubernetes/deployment.yaml
```

**Dry run mode (no changes applied):**
```bash
./update_workload.sh \
  --cluster-id YOUR_CLUSTER_ID \
  --api-key YOUR_API_KEY \
  --workload YOUR_WORKLOAD_NAME \
  --namespace YOUR_NAMESPACE \
  --dry-run
```

## Command Line Arguments

### workload-recommendation-parser.py

```
--cluster-id      CAST.AI cluster ID (required)
--api-key         CAST.AI API key (required)
--name            Name of the workload to find (required)
--namespace       Namespace of the workload (default: "default")
--container       Specific container to update (optional)
--output-file     File to write the patch (default: stdout)
--pretty          Format JSON output with indentation
```

### update_workload.sh

```
--cluster-id      CAST.AI cluster ID (required)
--api-key         CAST.AI API key (required)
--workload        Name of the workload to update (required)
--namespace       Namespace of the workload (default: "default")
--repo-path       Path to the git repository (required, unless dry-run)
--manifest-path   Path to the K8s manifest file relative to repo root (required)
--container       Container name to update (default: updates all containers)
--dry-run         Only generate the patch without applying changes
--output          Write patch to specified file (default: <workload>-patch.json)
--help            Display help message
```

## Integrating with CI/CD

You can integrate these scripts with CI/CD pipelines to periodically create PRs for resource optimizations.

### Example GitHub Actions Workflow

Create a file at `.github/workflows/resource-optimization.yml` with the following content:

```yaml
name: Resource Optimization

on:
  schedule:
    - cron: '0 2 * * 1'  # Run weekly on Monday at 2 AM UTC
  workflow_dispatch:     # Allow manual triggers
    inputs:
      workload:
        description: 'Specific workload to update'
        required: false

# Important: Give the workflow permission to create PRs and push to the repository
permissions:
  contents: write
  pull-requests: write

jobs:
  optimize-resources:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get install -y curl kubectl
      - name: Run optimizer
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ./update_workload.sh \
            --cluster-id ${{ secrets.CAST_CLUSTER_ID }} \
            --api-key ${{ secrets.CAST_API_KEY }} \
            --workload frontend \
            --repo-path . \
            --manifest-path kubernetes/frontend.yaml
```

Make sure you add the required secrets to your GitHub repository.

## GitHub Actions Authentication

For GitHub Actions to properly push changes and create PRs, you need to:

1. Add the CAST.AI credentials as repository secrets:
   - `CAST_CLUSTER_ID`
   - `CAST_API_KEY`

2. Configure appropriate permissions in the workflow file:
   ```yaml
   permissions:
     contents: write
     pull-requests: write
   ```

3. Pass the `GITHUB_TOKEN` to your script:
   ```yaml
   env:
     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
   ```

The script uses this token to authenticate Git operations.

