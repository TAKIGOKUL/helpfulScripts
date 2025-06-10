#!/bin/bash

# Intelligent Git & GitHub Manager
# A comprehensive tool for Git operations with auto-recovery
# Author: Assistant
# Version: 2.0

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration file
CONFIG_FILE="$HOME/.git_manager_config"

# Function to print colored text
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to print command execution
print_command() {
    print_color $CYAN "🔧 Executing: ${BOLD}$1${NC}"
}

# Function to print description
print_description() {
    print_color $YELLOW "ℹ️  $1"
}

# Function to print success message
print_success() {
    print_color $GREEN "✅ $1"
}

# Function to print error message
print_error() {
    print_color $RED "❌ $1"
}

# Function to print warning
print_warning() {
    print_color $YELLOW "⚠️  $1"
}

# Function to print header
print_header() {
    echo
    print_color $BLUE "╔═══════════════════════════════════════════╗"
    printf "${BLUE}║${WHITE}${BOLD}%43s${NC}${BLUE}║${NC}\n" "$1"
    print_color $BLUE "╚═══════════════════════════════════════════╝"
    echo
}

# Function to check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed!"
        print_description "Please install Git first:"
        print_color $CYAN "  Ubuntu/Debian: sudo apt install git"
        print_color $CYAN "  CentOS/RHEL: sudo yum install git"
        print_color $CYAN "  Arch: sudo pacman -S git"
        exit 1
    fi
}

# Function to check if GitHub CLI is installed
check_gh() {
    if ! command -v gh &> /dev/null; then
        print_warning "GitHub CLI not found. Some features will be limited."
        print_description "To install GitHub CLI:"
        print_color $CYAN "  Visit: https://cli.github.com/"
        return 1
    fi
    return 0
}

# Function to save configuration
save_config() {
    local key=$1
    local value=$2
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "/^$key=/d" "$CONFIG_FILE"
    fi
    echo "$key=$value" >> "$CONFIG_FILE"
}

# Function to load configuration
load_config() {
    local key=$1
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2-
    fi
}

# Function to setup Git user configuration
setup_git_user() {
    print_header "Git User Configuration"
    
    local current_name=$(git config --global user.name 2>/dev/null)
    local current_email=$(git config --global user.email 2>/dev/null)
    
    if [[ -n "$current_name" && -n "$current_email" ]]; then
        print_success "Current Git configuration:"
        echo "  Name: $current_name"
        echo "  Email: $current_email"
        echo
        read -p "Do you want to change this configuration? (y/N): " change_config
        if [[ ! "$change_config" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    read -p "Enter your name: " git_name
    read -p "Enter your email: " git_email
    
    print_command "git config --global user.name \"$git_name\""
    git config --global user.name "$git_name"
    
    print_command "git config --global user.email \"$git_email\""
    git config --global user.email "$git_email"
    
    print_description "Setting up useful Git defaults..."
    print_command "git config --global init.defaultBranch main"
    git config --global init.defaultBranch main
    
    print_command "git config --global pull.rebase false"
    git config --global pull.rebase false
    
    print_success "Git user configuration completed!"
    
    save_config "git_name" "$git_name"
    save_config "git_email" "$git_email"
}

# Function to authenticate with GitHub
authenticate_github() {
    print_header "GitHub Authentication"
    
    if ! check_gh; then
        print_error "GitHub CLI is required for authentication"
        return 1
    fi
    
    # Check if already authenticated
    if gh auth status &>/dev/null; then
        print_success "Already authenticated with GitHub!"
        gh auth status
        return 0
    fi
    
    print_description "Authenticating with GitHub..."
    print_command "gh auth login"
    
    if gh auth login; then
        print_success "GitHub authentication successful!"
        return 0
    else
        print_error "GitHub authentication failed!"
        return 1
    fi
}

# Function to initialize a new repository
init_repository() {
    print_header "Initialize New Repository"
    
    if [[ -d ".git" ]]; then
        print_warning "Git repository already exists in current directory"
        return 0
    fi
    
    print_command "git init"
    if git init; then
        print_success "Repository initialized successfully!"
        print_description "Created .git directory and initialized empty repository"
        
        # Create initial .gitignore if it doesn't exist
        if [[ ! -f ".gitignore" ]]; then
            read -p "Create a basic .gitignore file? (Y/n): " create_gitignore
            if [[ ! "$create_gitignore" =~ ^[Nn]$ ]]; then
                create_gitignore_file
            fi
        fi
        
        return 0
    else
        print_error "Failed to initialize repository!"
        return 1
    fi
}

# Function to create .gitignore file
create_gitignore_file() {
    print_description "Creating basic .gitignore file..."
    cat > .gitignore << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/

# Logs
*.log
logs/

# Runtime data
pids
*.pid
*.seed

# Dependency directories
node_modules/
__pycache__/
*.pyc

# Build outputs
dist/
build/
*.o
*.so

# Environment variables
.env
.env.local
EOF
    print_success "Created .gitignore file with common patterns"
}

# Function to check repository status
check_status() {
    print_header "Repository Status"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        print_description "Run 'Initialize Repository' first"
        return 1
    fi
    
    print_command "git status"
    git status
    
    echo
    print_command "git log --oneline -5"
    print_description "Last 5 commits:"
    git log --oneline -5 2>/dev/null || print_warning "No commits yet"
}

# Function to add files
add_files() {
    print_header "Add Files to Staging"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        return 1
    fi
    
    # Show current status
    print_description "Current repository status:"
    git status --short
    
    echo
    echo "Choose files to add:"
    echo "1. Add all files (git add .)"
    echo "2. Add specific files"
    echo "3. Add by pattern"
    echo "4. Interactive add"
    echo "5. Back to main menu"
    
    read -p "Enter your choice (1-5): " add_choice
    
    case $add_choice in
        1)
            print_command "git add ."
            if git add .; then
                print_success "All files added to staging area"
            else
                print_error "Failed to add files"
            fi
            ;;
        2)
            read -p "Enter filenames (space-separated): " files
            print_command "git add $files"
            if git add $files; then
                print_success "Files added to staging area"
            else
                print_error "Failed to add specified files"
            fi
            ;;
        3)
            read -p "Enter file pattern (e.g., *.txt): " pattern
            print_command "git add $pattern"
            if git add $pattern; then
                print_success "Files matching pattern added"
            else
                print_error "Failed to add files matching pattern"
            fi
            ;;
        4)
            print_command "git add -i"
            print_description "Starting interactive add mode..."
            git add -i
            ;;
        5)
            return 0
            ;;
        *)
            print_error "Invalid choice!"
            ;;
    esac
}

# Function to commit changes
commit_changes() {
    print_header "Commit Changes"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        return 1
    fi
    
    # Check if there are staged changes
    if ! git diff --cached --quiet 2>/dev/null; then
        print_description "Staged changes found:"
        git diff --cached --name-only
    else
        print_warning "No staged changes found!"
        read -p "Do you want to add files first? (Y/n): " add_first
        if [[ ! "$add_first" =~ ^[Nn]$ ]]; then
            add_files
        else
            return 0
        fi
    fi
    
    echo
    read -p "Enter commit message: " commit_msg
    
    if [[ -z "$commit_msg" ]]; then
        print_error "Commit message cannot be empty!"
        return 1
    fi
    
    print_command "git commit -m \"$commit_msg\""
    if git commit -m "$commit_msg"; then
        print_success "Changes committed successfully!"
        print_description "Commit created with message: $commit_msg"
    else
        print_error "Commit failed!"
        auto_fix_commit_issues
    fi
}

# Function to auto-fix common commit issues
auto_fix_commit_issues() {
    print_description "Checking for common commit issues..."
    
    # Check if user is configured
    if ! git config user.name &>/dev/null || ! git config user.email &>/dev/null; then
        print_warning "Git user not configured!"
        setup_git_user
        
        # Retry commit
        read -p "Retry commit? (Y/n): " retry
        if [[ ! "$retry" =~ ^[Nn]$ ]]; then
            read -p "Enter commit message: " commit_msg
            if git commit -m "$commit_msg"; then
                print_success "Commit successful after fixing user configuration!"
            fi
        fi
    fi
}

# Function to create GitHub repository
create_github_repo() {
    print_header "Create GitHub Repository"
    
    if ! check_gh; then
        print_error "GitHub CLI is required for this operation"
        return 1
    fi
    
    if ! gh auth status &>/dev/null; then
        print_warning "Not authenticated with GitHub"
        authenticate_github
    fi
    
    read -p "Enter repository name: " repo_name
    if [[ -z "$repo_name" ]]; then
        print_error "Repository name cannot be empty!"
        return 1
    fi
    
    read -p "Enter repository description (optional): " repo_desc
    
    echo "Repository visibility:"
    echo "1. Public"
    echo "2. Private"
    read -p "Choose (1-2): " visibility_choice
    
    local visibility_flag=""
    case $visibility_choice in
        1) visibility_flag="--public" ;;
        2) visibility_flag="--private" ;;
        *) visibility_flag="--public" ;;
    esac
    
    local gh_command="gh repo create $repo_name $visibility_flag"
    if [[ -n "$repo_desc" ]]; then
        gh_command="$gh_command --description \"$repo_desc\""
    fi
    
    print_command "$gh_command"
    
    if eval "$gh_command"; then
        print_success "GitHub repository '$repo_name' created successfully!"
        
        # Ask if user wants to add remote
        read -p "Add this repository as remote origin? (Y/n): " add_remote
        if [[ ! "$add_remote" =~ ^[Nn]$ ]]; then
            add_remote_origin "$repo_name"
        fi
    else
        print_error "Failed to create GitHub repository!"
    fi
}

# Function to add remote origin
add_remote_origin() {
    local repo_name=${1:-}
    
    if [[ -z "$repo_name" ]]; then
        read -p "Enter repository name (username/repo or just repo): " repo_name
    fi
    
    # Get GitHub username if not provided
    if [[ ! "$repo_name" =~ "/" ]]; then
        local username=$(gh api user --jq .login 2>/dev/null)
        if [[ -n "$username" ]]; then
            repo_name="$username/$repo_name"
        else
            read -p "Enter your GitHub username: " username
            repo_name="$username/$repo_name"
        fi
    fi
    
    local remote_url="https://github.com/$repo_name.git"
    
    print_command "git remote add origin $remote_url"
    if git remote add origin "$remote_url" 2>/dev/null; then
        print_success "Remote origin added successfully!"
        print_description "Remote URL: $remote_url"
    else
        print_warning "Remote origin might already exist"
        print_command "git remote set-url origin $remote_url"
        if git remote set-url origin "$remote_url"; then
            print_success "Remote origin URL updated!"
        else
            print_error "Failed to set remote origin!"
        fi
    fi
}

# Function to push changes
push_changes() {
    print_header "Push Changes to GitHub"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        return 1
    fi
    
    # Check if remote exists
    if ! git remote get-url origin &>/dev/null; then
        print_warning "No remote origin configured!"
        read -p "Do you want to add remote origin? (Y/n): " add_origin
        if [[ ! "$add_origin" =~ ^[Nn]$ ]]; then
            add_remote_origin
        else
            return 1
        fi
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        current_branch="main"
    fi
    
    print_description "Current branch: $current_branch"
    
    # Check if there are commits to push
    if ! git log origin/$current_branch..$current_branch &>/dev/null; then
        print_description "First push to this branch"
        print_command "git push -u origin $current_branch"
        if git push -u origin "$current_branch"; then
            print_success "Changes pushed successfully!"
            print_description "Upstream tracking set for branch '$current_branch'"
        else
            auto_fix_push_issues "$current_branch"
        fi
    else
        print_command "git push"
        if git push; then
            print_success "Changes pushed successfully!"
        else
            auto_fix_push_issues "$current_branch"
        fi
    fi
}

# Function to auto-fix push issues
auto_fix_push_issues() {
    local branch=$1
    print_description "Checking for common push issues..."
    
    # Check if remote branch exists
    if ! git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
        print_warning "Remote branch '$branch' doesn't exist"
        print_command "git push -u origin $branch"
        if git push -u origin "$branch"; then
            print_success "Branch pushed and upstream set!"
            return 0
        fi
    fi
    
    # Check for diverged branches
    if git status | grep -q "have diverged"; then
        print_warning "Branches have diverged!"
        echo "Options:"
        echo "1. Pull and merge (git pull)"
        echo "2. Pull and rebase (git pull --rebase)"
        echo "3. Force push (DANGEROUS - git push --force)"
        read -p "Choose option (1-3): " diverge_choice
        
        case $diverge_choice in
            1)
                print_command "git pull"
                git pull && git push
                ;;
            2)
                print_command "git pull --rebase"
                git pull --rebase && git push
                ;;
            3)
                print_warning "Force pushing - this will overwrite remote changes!"
                read -p "Are you sure? (y/N): " confirm_force
                if [[ "$confirm_force" =~ ^[Yy]$ ]]; then
                    print_command "git push --force"
                    git push --force
                fi
                ;;
        esac
    fi
}

# Function to pull changes
pull_changes() {
    print_header "Pull Changes from GitHub"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        return 1
    fi
    
    if ! git remote get-url origin &>/dev/null; then
        print_error "No remote origin configured!"
        return 1
    fi
    
    print_command "git pull"
    if git pull; then
        print_success "Changes pulled successfully!"
    else
        print_error "Pull failed - checking for conflicts..."
        
        if git status | grep -q "both modified"; then
            print_warning "Merge conflicts detected!"
            print_description "Files with conflicts:"
            git status --short | grep "UU"
            echo
            print_description "Resolve conflicts manually, then run:"
            print_color $CYAN "  git add <resolved-files>"
            print_color $CYAN "  git commit"
        fi
    fi
}

# Function to show repository information
show_repo_info() {
    print_header "Repository Information"
    
    if [[ ! -d ".git" ]]; then
        print_error "Not a Git repository!"
        return 1
    fi
    
    echo "📁 Repository Path: $(pwd)"
    echo
    
    # Show remotes
    print_description "Remote repositories:"
    if git remote -v | grep -q .; then
        git remote -v
    else
        print_warning "No remotes configured"
    fi
    
    echo
    
    # Show branches
    print_description "Branches:"
    git branch -a
    
    echo
    
    # Show recent commits
    print_description "Recent commits:"
    git log --oneline -10 2>/dev/null || print_warning "No commits yet"
    
    echo
    
    # Show repository statistics
    if git log --oneline | head -1 &>/dev/null; then
        local total_commits=$(git rev-list --all --count)
        local contributors=$(git log --format='%ae' | sort -u | wc -l)
        
        print_description "Statistics:"
        echo "  Total commits: $total_commits"
        echo "  Contributors: $contributors"
        
        # Show file changes
        local files_changed=$(git diff --name-only | wc -l)
        local staged_files=$(git diff --cached --name-only | wc -l)
        
        echo "  Modified files: $files_changed"
        echo "  Staged files: $staged_files"
    fi
}

# Function to clone repository
clone_repository() {
    print_header "Clone Repository"
    
    read -p "Enter repository URL or username/repository: " repo_input
    
    if [[ -z "$repo_input" ]]; then
        print_error "Repository input cannot be empty!"
        return 1
    fi
    
    # Convert short format to full URL if needed
    local repo_url="$repo_input"
    if [[ ! "$repo_input" =~ ^https?:// ]] && [[ ! "$repo_input" =~ ^git@ ]]; then
        repo_url="https://github.com/$repo_input.git"
    fi
    
    read -p "Clone into directory (press Enter for default): " clone_dir
    
    local git_command="git clone $repo_url"
    if [[ -n "$clone_dir" ]]; then
        git_command="$git_command $clone_dir"
    fi
    
    print_command "$git_command"
    
    if eval "$git_command"; then
        print_success "Repository cloned successfully!"
        
        # Change to cloned directory if default name was used
        if [[ -z "$clone_dir" ]]; then
            local repo_name=$(basename "$repo_url" .git)
            if [[ -d "$repo_name" ]]; then
                print_description "Changed to directory: $repo_name"
                cd "$repo_name" || return 1
            fi
        fi
    else
        print_error "Failed to clone repository!"
        print_description "Check if the repository URL is correct and accessible"
    fi
}

# Main menu function
show_main_menu() {
    clear
    print_color $PURPLE "╔═══════════════════════════════════════════════════════════════╗"
    print_color $PURPLE "║                                                               ║"
    print_color $PURPLE "║${WHITE}${BOLD}                 🚀 INTELLIGENT GIT MANAGER 🚀                ${NC}${PURPLE}║"
    print_color $PURPLE "║                                                               ║"
    print_color $PURPLE "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # Show current directory and git status
    print_color $CYAN "📍 Current Directory: ${BOLD}$(pwd)${NC}"
    if [[ -d ".git" ]]; then
        local branch=$(git branch --show-current 2>/dev/null)
        local status=$(git status --porcelain | wc -l)
        print_color $GREEN "🔗 Git Repository (Branch: $branch, Changes: $status)"
    else
        print_color $YELLOW "📂 Not a Git repository"
    fi
    
    echo
    print_color $WHITE "${BOLD}SETUP & CONFIGURATION:${NC}"
    print_color $BLUE "  1.  🔧 Setup Git User Configuration"
    print_color $BLUE "  2.  🔐 Authenticate with GitHub"
    
    echo
    print_color $WHITE "${BOLD}REPOSITORY MANAGEMENT:${NC}"
    print_color $GREEN "  3.  📦 Initialize New Repository"
    print_color $GREEN "  4.  📥 Clone Repository"
    print_color $GREEN "  5.  📊 Repository Status & Info"
    
    echo
    print_color $WHITE "${BOLD}FILE OPERATIONS:${NC}"
    print_color $YELLOW "  6.  ➕ Add Files to Staging"
    print_color $YELLOW "  7.  💾 Commit Changes"
    print_color $YELLOW "  8.  📤 Push Changes to GitHub"
    print_color $YELLOW "  9.  📥 Pull Changes from GitHub"
    
    echo
    print_color $WHITE "${BOLD}GITHUB OPERATIONS:${NC}"
    print_color $PURPLE " 10.  🆕 Create GitHub Repository"
    print_color $PURPLE " 11.  🔗 Add Remote Origin"
    
    echo
    print_color $WHITE "${BOLD}SYSTEM:${NC}"
    print_color $CYAN " 12.  ℹ️  Show Repository Information"
    print_color $RED " 13.  🚪 Exit"
    
    echo
    print_color $WHITE "${BOLD}Enter your choice (1-13): ${NC}"
}

# Main program loop
main() {
    # Initial checks
    check_git
    check_gh
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) setup_git_user ;;
            2) authenticate_github ;;
            3) init_repository ;;
            4) clone_repository ;;
            5) check_status ;;
            6) add_files ;;
            7) commit_changes ;;
            8) push_changes ;;
            9) pull_changes ;;
            10) create_github_repo ;;
            11) add_remote_origin ;;
            12) show_repo_info ;;
            13) 
                print_color $GREEN "👋 Thank you for using Git Manager!"
                exit 0
                ;;
            *)
                print_error "Invalid choice! Please enter a number between 1-13."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..." -r
    done
}

# Run the main program
main "$@"
