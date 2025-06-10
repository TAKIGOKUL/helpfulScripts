#!/bin/bash

# Intelligent File Organizer Script
# Organizes files by type into appropriate directories
# Author: Assistant
# Version: 1.0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set base directory (current user's home)
BASE_DIR="$HOME"

# Define target directories
PICTURES_DIR="$BASE_DIR/Pictures"
VIDEOS_DIR="$BASE_DIR/Videos"
DOCUMENTS_DIR="$BASE_DIR/Documents"
OS_DIR="$BASE_DIR/Desktop/OS"

# File extensions arrays
declare -a IMAGE_EXTS=("jpg" "jpeg" "png" "gif" "bmp" "tiff" "tif" "webp" "svg" "ico" "raw" "cr2" "nef" "orf" "sr2" "arw" "dng" "heic" "heif")
declare -a VIDEO_EXTS=("mp4" "avi" "mkv" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "3gp" "ogv" "ts" "mts" "m2ts" "vob")
declare -a DOCUMENT_EXTS=("pdf" "doc" "docx" "txt" "rtf" "odt" "xls" "xlsx" "ppt" "pptx" "ods" "odp" "csv" "epub" "mobi")
declare -a ISO_EXTS=("iso" "img" "dmg" "vhd" "vhdx" "vmdk" "qcow2" "bin" "cue" "mds" "nrg")

# Statistics counters
moved_images=0
moved_videos=0
moved_documents=0
moved_iso=0
skipped_files=0
errors=0

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to create directory if it doesn't exist
create_dir() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_color $GREEN "Created directory: $dir"
    fi
}

# Function to get file extension in lowercase
get_extension() {
    local filename=$1
    echo "${filename##*.}" | tr '[:upper:]' '[:lower:]'
}

# Function to check if extension is in array
contains_extension() {
    local ext=$1
    local -n arr=$2
    for element in "${arr[@]}"; do
        if [[ "$element" == "$ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to move file safely
move_file() {
    local source="$1"
    local dest_dir="$2"
    local file_type="$3"
    
    local filename=$(basename "$source")
    local dest_path="$dest_dir/$filename"
    
    # Check if destination file already exists
    if [[ -f "$dest_path" ]]; then
        # Generate unique filename
        local name="${filename%.*}"
        local ext="${filename##*.}"
        local counter=1
        
        while [[ -f "$dest_dir/${name}_${counter}.${ext}" ]]; do
            ((counter++))
        done
        
        dest_path="$dest_dir/${name}_${counter}.${ext}"
        print_color $YELLOW "File exists, renaming to: $(basename "$dest_path")"
    fi
    
    # Move the file
    if mv "$source" "$dest_path" 2>/dev/null; then
        print_color $GREEN "Moved $file_type: $(basename "$source") → $dest_dir"
        return 0
    else
        print_color $RED "Error moving: $source"
        ((errors++))
        return 1
    fi
}

# Function to process a single file
process_file() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local extension=$(get_extension "$filename")
    
    # Skip hidden files and system files
    if [[ "$filename" =~ ^\. ]]; then
        return
    fi
    
    # Skip if file is already in target directories
    local current_dir=$(dirname "$filepath")
    if [[ "$current_dir" == "$PICTURES_DIR" ]] || \
       [[ "$current_dir" == "$VIDEOS_DIR" ]] || \
       [[ "$current_dir" == "$DOCUMENTS_DIR" ]] || \
       [[ "$current_dir" == "$OS_DIR" ]]; then
        return
    fi
    
    # Process based on file type
    if contains_extension "$extension" IMAGE_EXTS; then
        create_dir "$PICTURES_DIR"
        if move_file "$filepath" "$PICTURES_DIR" "image"; then
            ((moved_images++))
        fi
    elif contains_extension "$extension" VIDEO_EXTS; then
        create_dir "$VIDEOS_DIR"
        if move_file "$filepath" "$VIDEOS_DIR" "video"; then
            ((moved_videos++))
        fi
    elif contains_extension "$extension" DOCUMENT_EXTS; then
        create_dir "$DOCUMENTS_DIR"
        if move_file "$filepath" "$DOCUMENTS_DIR" "document"; then
            ((moved_documents++))
        fi
    elif contains_extension "$extension" ISO_EXTS; then
        create_dir "$OS_DIR"
        if move_file "$filepath" "$OS_DIR" "ISO/disk image"; then
            ((moved_iso++))
        fi
    else
        ((skipped_files++))
    fi
}

# Function to scan directory recursively
scan_directory() {
    local dir="$1"
    
    # Check if directory exists and is readable
    if [[ ! -d "$dir" ]] || [[ ! -r "$dir" ]]; then
        print_color $RED "Cannot access directory: $dir"
        return
    fi
    
    print_color $BLUE "Scanning: $dir"
    
    # Process files in current directory
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            process_file "$file"
        fi
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    # Recursively process subdirectories
    while IFS= read -r -d '' subdir; do
        # Skip target directories to avoid moving files back
        local dirname=$(basename "$subdir")
        if [[ "$subdir" != "$PICTURES_DIR" ]] && \
           [[ "$subdir" != "$VIDEOS_DIR" ]] && \
           [[ "$subdir" != "$DOCUMENTS_DIR" ]] && \
           [[ "$subdir" != "$OS_DIR" ]]; then
            scan_directory "$subdir"
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

# Main function
main() {
    print_color $BLUE "==================================="
    print_color $BLUE "  Intelligent File Organizer"
    print_color $BLUE "==================================="
    echo
    
    # Check if running from home directory
    if [[ "$PWD" != "$HOME" ]]; then
        print_color $YELLOW "Switching to home directory: $HOME"
        cd "$HOME" || {
            print_color $RED "Cannot access home directory"
            exit 1
        }
    fi
    
    # Confirm before proceeding
    print_color $YELLOW "This script will organize files in the following directories:"
    echo "  • Images → $PICTURES_DIR"
    echo "  • Videos → $VIDEOS_DIR"
    echo "  • Documents → $DOCUMENTS_DIR"
    echo "  • ISO/Disk Images → $OS_DIR"
    echo
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Operation cancelled."
        exit 0
    fi
    
    echo
    print_color $BLUE "Starting file organization..."
    echo
    
    # Get list of directories to scan (excluding target directories)
    declare -a SCAN_DIRS=()
    for dir in Desktop Documents Downloads Music Public; do
        full_path="$BASE_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            SCAN_DIRS+=("$full_path")
        fi
    done
    
    # Scan each directory
    for dir in "${SCAN_DIRS[@]}"; do
        scan_directory "$dir"
    done
    
    # Print summary
    echo
    print_color $BLUE "==================================="
    print_color $BLUE "         SUMMARY REPORT"
    print_color $BLUE "==================================="
    print_color $GREEN "Images moved: $moved_images"
    print_color $GREEN "Videos moved: $moved_videos"
    print_color $GREEN "Documents moved: $moved_documents"
    print_color $GREEN "ISO/Disk images moved: $moved_iso"
    print_color $YELLOW "Files skipped: $skipped_files"
    
    if [[ $errors -gt 0 ]]; then
        print_color $RED "Errors encountered: $errors"
    else
        print_color $GREEN "No errors encountered!"
    fi
    
    local total_moved=$((moved_images + moved_videos + moved_documents + moved_iso))
    print_color $BLUE "Total files organized: $total_moved"
    echo
    print_color $GREEN "File organization complete!"
}

# Run main function
main "$@"
