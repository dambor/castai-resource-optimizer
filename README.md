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
./workload-recommendation-parser.py \
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

```yaml
name: Resource Optimization

on:
  schedule:
    - cron: '0 0 * * 0'  # Run weekly on Sunday at midnight
  workflow_dispatch:     # Allow manual triggers

jobs:
  optimize-resources:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/stable.txt"
          curl -LO "https://dl.k8s.io/$(cat stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl && sudo mv kubectl /usr/local/bin/
          
      - name: Install GitHub CLI
        run: |
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          sudo apt update
          sudo apt install gh
          
      - name: Update resources
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ./update_workload.sh \
            --cluster-id ${{ secrets.CAST_CLUSTER_ID }} \
            --api-key ${{ secrets.CAST_API_KEY }} \
            --workload frontend \
            --repo-path . \
            --manifest-path kubernetes/frontend.yaml
```

## Security Considerations

- Store your CAST.AI API key securely (in environment variables or CI/CD secrets)
- Consider setting resource limits to prevent unconstrained scaling
- Review all PRs before merging to validate recommendations

## Troubleshooting

**Error: Parser script not found:**
Make sure the `workload-recommendation-parser.py` script is in your current directory.

**Error: Repository directory does not exist:**
Check that the path provided with `--repo-path` is correct.

**Error: kubectl not found:**
Install kubectl or provide the full path to the binary.

