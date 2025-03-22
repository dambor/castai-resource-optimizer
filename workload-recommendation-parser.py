#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys

def fetch_cast_workloads(cluster_id, api_key):
    """Fetch workloads data from CAST.AI API."""
    try:
        command = [
            "curl", "--silent", "--request", "GET",
            f"https://api.cast.ai/v1/workload-autoscaling/clusters/{cluster_id}/workloads",
            "--header", f"X-API-Key: {api_key}",
            "--header", "accept: application/json"
        ]
        
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching data from CAST.AI API: {e}", file=sys.stderr)
        if e.stderr:
            print(f"API error message: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error decoding JSON response from API", file=sys.stderr)
        sys.exit(1)

def find_workload(workloads_data, name, namespace="default"):
    """Find a workload by name and namespace."""
    if "workloads" not in workloads_data:
        print("Unexpected API response format: 'workloads' field not found", file=sys.stderr)
        sys.exit(1)
        
    for workload in workloads_data["workloads"]:
        if workload["name"] == name and workload["namespace"] == namespace:
            return workload
            
    return None

def create_kubernetes_patch(workload, container_name=None):
    """Create a Kubernetes patch for updating the deployment based on workload recommendations."""
    if not workload:
        return None
    
    # Create the patch structure
    patch = {
        "apiVersion": "apps/v1",
        "kind": workload["kind"],
        "metadata": {
            "name": workload["name"],
            "namespace": workload["namespace"]
        },
        "spec": {
            "template": {
                "spec": {
                    "containers": []
                }
            }
        }
    }
    
    # Filter containers if a specific one is requested
    containers_to_update = []
    if container_name:
        for container in workload["containers"]:
            if container["name"] == container_name:
                containers_to_update.append(container)
                break
        if not containers_to_update:
            print(f"Container '{container_name}' not found in workload", file=sys.stderr)
            return None
    else:
        containers_to_update = workload["containers"]
    
    # Process each container
    for container in containers_to_update:
        # Skip if no recommendation
        if not container.get("recommendation"):
            continue
            
        container_patch = {
            "name": container["name"],
            "resources": {}
        }
        
        # Add requests if present
        if container["recommendation"].get("requests"):
            container_patch["resources"]["requests"] = {}
            requests = container["recommendation"]["requests"]
            
            # Add CPU requests if recommended
            if "cpuCores" in requests:
                container_patch["resources"]["requests"]["cpu"] = str(requests["cpuCores"])
                
            # Add memory requests if recommended (convert GiB to Mi)
            if "memoryGib" in requests:
                mem_mi = int(requests["memoryGib"] * 1024)
                container_patch["resources"]["requests"]["memory"] = f"{mem_mi}Mi"
        
        # Add limits if present
        if container["recommendation"].get("limits"):
            container_patch["resources"]["limits"] = {}
            limits = container["recommendation"]["limits"]
            
            # Add CPU limits if recommended
            if "cpuCores" in limits:
                container_patch["resources"]["limits"]["cpu"] = str(limits["cpuCores"])
                
            # Add memory limits if recommended (convert GiB to Mi)
            if "memoryGib" in limits:
                mem_mi = int(limits["memoryGib"] * 1024)
                container_patch["resources"]["limits"]["memory"] = f"{mem_mi}Mi"
        
        # Only add container to patch if it has resource recommendations
        if container_patch.get("resources"):
            patch["spec"]["template"]["spec"]["containers"].append(container_patch)
    
    # Return None if no containers to update
    if not patch["spec"]["template"]["spec"]["containers"]:
        return None
        
    return patch

def main():
    parser = argparse.ArgumentParser(description="Generate Kubernetes patch from CAST.AI workload recommendations")
    parser.add_argument("--cluster-id", required=True, help="CAST.AI cluster ID")
    parser.add_argument("--api-key", required=True, help="CAST.AI API key")
    parser.add_argument("--name", required=True, help="Name of the workload to find")
    parser.add_argument("--namespace", default="default", help="Namespace of the workload (default: default)")
    parser.add_argument("--container", help="Specific container to update (optional)")
    parser.add_argument("--output-file", help="Output file to write the patch (default: stdout)")
    parser.add_argument("--pretty", action="store_true", help="Pretty print the JSON output")
    
    args = parser.parse_args()
    
    # Fetch workloads data from API
    workloads_data = fetch_cast_workloads(args.cluster_id, args.api_key)
    
    # Find the specific workload
    workload = find_workload(workloads_data, args.name, args.namespace)
    if not workload:
        print(f"Workload '{args.name}' not found in namespace '{args.namespace}'", file=sys.stderr)
        sys.exit(1)
    
    # Create the patch
    patch = create_kubernetes_patch(workload, args.container)
    if not patch:
        print(f"No recommendations found for workload '{args.name}'", file=sys.stderr)
        sys.exit(1)
    
    # Output the patch
    indent = 2 if args.pretty else None
    patch_json = json.dumps(patch, indent=indent)
    
    if args.output_file:
        with open(args.output_file, 'w') as f:
            f.write(patch_json)
        print(f"Patch written to {args.output_file}")
    else:
        print(patch_json)

if __name__ == "__main__":
    main()