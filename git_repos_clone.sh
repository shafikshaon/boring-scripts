#!/bin/bash

# GitHub Repository Clone Script
# This script clones all repositories that your GitHub account has access to.
# Required: GitHub Personal Access Token with 'repo' scope

# Configuration
TOKEN="<your token goes here>"
OUTPUT_DIR="${PWD}"
GITHUB_API="https://api.github.com"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handling
set -e
trap 'echo -e "${RED}Error: Script failed at line $LINENO${NC}"' ERR

# Function to check dependencies
check_dependencies() {
    local deps=("curl" "git" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${RED}Error: Required dependency '$dep' is not installed.${NC}"
            exit 1
        fi
    done
}

# Function to validate token
validate_token() {
    if [[ -z "$TOKEN" || "$TOKEN" == "your-token-here" ]]; then
        echo -e "${RED}Error: Please set your GitHub token in the script.${NC}"
        echo "Get your token from: https://github.com/settings/tokens"
        echo "Required scopes: repo, read:org"
        exit 1
    fi

    # Test token validity
    if ! curl -s -H "Authorization: token $TOKEN" "$GITHUB_API/user" >/dev/null; then
        echo -e "${RED}Error: Invalid GitHub token or no internet connection.${NC}"
        exit 1
    fi
}

# Function to clone repositories
clone_repos() {
    local page=1
    local repos_count=0
    
    echo -e "${GREEN}Starting repository clone process...${NC}"
    
    while true; do
        # Fetch repositories for current page
        local repos=$(curl -s -H "Authorization: token $TOKEN" \
            "$GITHUB_API/user/repos?per_page=100&page=$page")
        
        # Break if no more repositories
        if [[ $(echo "$repos" | jq '. | length') -eq 0 ]]; then
            break
        fi
        
        # Process each repository
        echo "$repos" | jq -r '.[] | .ssh_url' | while read -r repo_url; do
            local repo_name=$(basename "$repo_url" .git)
            
            echo -e "${YELLOW}Cloning: $repo_name${NC}"
            
            if [ -d "$repo_name" ]; then
                echo -e "${YELLOW}Directory $repo_name already exists, updating...${NC}"
                (cd "$repo_name" && git pull origin main) || \
                (cd "$repo_name" && git pull origin master)
            else
                git clone "$repo_url"
            fi
            
            ((repos_count++))
            echo -e "${GREEN}Successfully processed: $repo_name${NC}"
        done
        
        ((page++))
    done
    
    echo -e "${GREEN}Completed! Processed $repos_count repositories.${NC}"
}

# Main execution
main() {
    echo "GitHub Repository Clone Script"
    echo "-----------------------------"
    
    check_dependencies
    validate_token
    clone_repos
}

main
