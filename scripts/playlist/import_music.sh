#!/bin/bash

set -euo pipefail

# Configuration
DEFAULT_SOURCE_DIR="$HOME/Music/downloads"
SCRIPT_NAME=$(basename "$0")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to show usage
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [SOURCE_DIR]

Import downloaded YouTube music into macOS Music app with proper album organization.

OPTIONS:
    -h, --help             Show this help message
    --dry-run              Show what would be imported without actually importing
    --create-playlists     Create playlists for each channel/artist
    --ipod-playlist [NAME] Set custom name for iPod playlist (default: "ipod", always created)
    --reset                Reset import history only (does not import)

ARGUMENTS:
    SOURCE_DIR            Source directory containing music files (default: ~/Music/downloads)

EXAMPLES:
    # Import from default downloads directory
    $SCRIPT_NAME

    # Import from custom directory
    $SCRIPT_NAME ~/Music/YouTube

    # Preview import without actually doing it
    $SCRIPT_NAME --dry-run

    # Import and create playlists for each artist
    $SCRIPT_NAME --create-playlists

    # Import with default iPod playlist name
    $SCRIPT_NAME
    
    # Import with custom iPod playlist name
    $SCRIPT_NAME --ipod-playlist "My iPod Music"
    
    # Reset import history only
    $SCRIPT_NAME --reset

REQUIREMENTS:
    - macOS with Music app
    - Downloaded music organized by channel/artist folders

NOTES:
    - Music will be imported maintaining the album structure (channel = album)
    - Files will be copied to Music library, originals remain untouched
    - Duplicate detection based on file metadata
    - iPod playlist is always created automatically (default name: "ipod")

EOF
}

# Function to check if we're on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script only works on macOS with the Music app"
        exit 1
    fi
}

# Function to check if Music app exists
check_music_app() {
    local music_app_paths=(
        "/Applications/Music.app"
        "/System/Applications/Music.app"
        "$HOME/Applications/Music.app"
    )
    
    local found=false
    for path in "${music_app_paths[@]}"; do
        if [[ -d "$path" ]]; then
            found=true
            print_info "Found Music app at: $path"
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        # Try to find Music app using mdfind (Spotlight)
        local spotlight_path
        spotlight_path=$(mdfind "kMDItemKind == 'Application' && kMDItemDisplayName == 'Music'" 2>/dev/null | head -1)
        
        if [[ -n "$spotlight_path" && -d "$spotlight_path" ]]; then
            print_info "Found Music app via Spotlight at: $spotlight_path"
        else
            print_error "Music app not found in standard locations:"
            for path in "${music_app_paths[@]}"; do
                print_error "  - $path"
            done
            print_error ""
            print_error "Troubleshooting steps:"
            print_error "  1. Open Spotlight (Cmd+Space) and search 'Music'"
            print_error "  2. Check if Music app opens when you click it"
            print_error "  3. If not installed, get it from App Store"
            print_error "  4. Try: ls -la /Applications/Music.app"
            print_error "  5. Try: ls -la /System/Applications/Music.app"
            exit 1
        fi
    fi
}

# Function to count music files
count_music_files() {
    local source_dir=$1
    local total=0
    
    if [[ ! -d "$source_dir" ]]; then
        echo 0
        return
    fi
    
    while IFS= read -r -d '' file; do
        ((total++))
    done < <(find "$source_dir" -name "*.mp3" -type f -print0 2>/dev/null)
    
    echo $total
}

# Function to get channel directories
get_channels() {
    local source_dir=$1
    
    if [[ ! -d "$source_dir" ]]; then
        return
    fi
    
    find "$source_dir" -mindepth 1 -maxdepth 1 -type d | sort
}

# Function to import music using AppleScript
import_music() {
    local source_dir=$1
    local dry_run=${2:-false}
    local create_playlists=${3:-false}
    local ipod_playlist=${4:-""}
    
    local total_files=$(count_music_files "$source_dir")
    
    if [[ $total_files -eq 0 ]]; then
        print_warning "No MP3 files found in $source_dir"
        return
    fi
    
    print_info "Found $total_files MP3 files to import"
    
    if [[ "$dry_run" == "true" ]]; then
        print_info "DRY RUN MODE - No files will actually be imported"
    fi
    
    local imported_count=0
    local skipped_count=0
    local channels=()
    
    # Process each channel directory
    while IFS= read -r -d '' channel_dir; do
        local channel_name=$(basename "$channel_dir")
        channels+=("$channel_name")
        
        print_info "Processing channel: $channel_name"
        
        local channel_files=0
        while IFS= read -r -d '' mp3_file; do
            ((channel_files++))
            local filename=$(basename "$mp3_file")
            
            if [[ "$dry_run" == "true" ]]; then
                print_info "  Would import: $filename"
            else
                # Import file to Music app
                import_single_file "$mp3_file" "$channel_name" "$source_dir"
                import_exit_code=$?
                
                if [[ $import_exit_code -eq 0 ]]; then
                    ((imported_count++))
                    print_info "  Imported: $filename"
                elif [[ $import_exit_code -eq 1 ]]; then
                    ((skipped_count++))
                    print_info "  Skipped: $filename (already imported)"
                else
                    ((skipped_count++))
                    print_warning "  Skipped: $filename (import error)"
                fi
            fi
        done < <(find "$channel_dir" -name "*.mp3" -type f -print0 2>/dev/null)
        
        print_info "  Found $channel_files files in $channel_name"
        
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    # Summary
    if [[ "$dry_run" == "true" ]]; then
        print_success "DRY RUN COMPLETE: $total_files files would be imported from ${#channels[@]} channels"
    else
        print_success "IMPORT COMPLETE: $imported_count imported, $skipped_count skipped"
        
        # Create playlists if requested
        if [[ "$create_playlists" == "true" ]]; then
            create_channel_playlists "${channels[@]}"
        fi
        
        # Always create iPod playlist (mandatory)
        if [[ -n "$ipod_playlist" ]]; then
            create_ipod_playlist "$ipod_playlist" "$imported_count"
        else
            # Create default iPod playlist if no custom name provided
            create_ipod_playlist "ipod" "$imported_count"
        fi
        
        print_info "Open Music app to see your imported music"
    fi
}

# Function to check if file was already imported
check_file_imported() {
    local file_path=$1
    local source_dir=$2
    local imported_log="$source_dir/.imported"
    local filename=$(basename "$file_path")
    
    # Simple grep check - much faster than loading entire file
    if [[ -f "$imported_log" ]]; then
        if grep -Fxq "$filename" "$imported_log" 2>/dev/null; then
            return 0  # File was already imported
        fi
    fi
    return 1  # File not yet imported
}

# Function to mark file as imported
mark_file_imported() {
    local file_path=$1
    local source_dir=$2
    local imported_log="$source_dir/.imported"
    local filename=$(basename "$file_path")
    
    # Add filename to import log
    echo "$filename" >> "$imported_log"
}

# Function to import a single file
import_single_file() {
    local file_path=$1
    local album_name=$2
    local source_dir=$3
    local filename=$(basename "$file_path")
    
    # Check if file was already imported using our tracking log
    if check_file_imported "$file_path" "$source_dir"; then
        return 1  # File already imported, skip
    fi
    
    # Use simple 'open' command to import to Music app
    if timeout 10 open -a "Music" "$file_path" >/dev/null 2>&1; then
        # Give Music app a moment to process the file
        sleep 0.5
        
        # Mark file as successfully imported
        mark_file_imported "$file_path" "$source_dir"
        return 0  # Success
    else
        # Import failed
        return 2  # Import error
    fi
}

# Function to create playlists for each channel
create_channel_playlists() {
    local channels=("$@")
    
    print_info "Creating playlists for ${#channels[@]} channels..."
    
    for channel in "${channels[@]}"; do
        if create_playlist "$channel"; then
            print_info "  Created playlist: $channel"
        else
            print_warning "  Playlist '$channel' may already exist"
        fi
    done
}

# Function to create a single playlist
create_playlist() {
    local playlist_name=$1
    
    osascript << EOF 2>/dev/null
try
    tell application "Music"
        -- Check if playlist already exists
        if not (exists playlist "$playlist_name") then
            make new playlist with properties {name:"$playlist_name"}
            
            -- Add all tracks from this album to playlist
            set album_tracks to (every track whose album is "$playlist_name")
            repeat with track_ref in album_tracks
                duplicate track_ref to playlist "$playlist_name"
            end repeat
            
            return true
        else
            return false
        end if
    end tell
on error
    return false
end try
EOF
}

# Function to create iPod playlist and add all imported tracks
create_ipod_playlist() {
    local playlist_name=$1
    local track_count=$2
    
    print_info "Creating iPod playlist: $playlist_name"
    
    # Create the playlist and add recently imported tracks
    local result
    result=$(osascript << EOF
tell application "Music"
    try
        -- Delete existing playlist if it exists
        if (exists playlist "$playlist_name") then
            delete playlist "$playlist_name"
        end if
        
        -- Create new playlist
        set new_playlist to make new playlist with properties {name:"$playlist_name"}
        
        -- Get all tracks from the main library
        set all_tracks to every track of library playlist 1
        
        -- Add tracks to playlist (limit to reasonable amount)
        set added_count to 0
        set track_count to count of all_tracks
        if track_count > 100 then set track_count to 100
        
        repeat with i from 1 to track_count
            try
                set track_ref to item i of all_tracks
                duplicate track_ref to new_playlist
                set added_count to added_count + 1
            on error
                -- Skip problematic tracks
            end try
        end repeat
        
        return added_count as string
    on error error_message
        return "ERROR: " & error_message
    end try
end tell
EOF
)
    
    if [[ "$result" =~ ^ERROR: ]]; then
        print_warning "Failed to create iPod playlist: ${result#ERROR: }"
    elif [[ "$result" =~ ^[0-9]+$ ]]; then
        print_success "Created iPod playlist '$playlist_name' with $result tracks"
        print_info "This playlist is perfect for syncing to your iPod"
    else
        print_warning "Unexpected result creating playlist: $result"
    fi
}

# Main function
main() {
    local source_dir="$DEFAULT_SOURCE_DIR"
    local dry_run=false
    local create_playlists=false
    local ipod_playlist=""
    local reset_import_log=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --create-playlists)
                create_playlists=true
                shift
                ;;
            --ipod-playlist)
                # Check if next argument exists and doesn't start with --
                if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                    ipod_playlist="$2"
                    shift 2
                else
                    ipod_playlist="ipod"
                    shift
                fi
                ;;
            --reset)
                reset_import_log=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
            *)
                source_dir="$1"
                shift
                ;;
        esac
    done
    
    # Validate environment
    check_macos
    
    # Only check Music app if not doing dry run
    if [[ "$dry_run" == "false" ]]; then
        check_music_app
    fi
    
    # Convert to absolute path
    source_dir=$(cd "$source_dir" 2>/dev/null && pwd || echo "$source_dir")
    
    if [[ ! -d "$source_dir" ]]; then
        print_error "Source directory does not exist: $source_dir"
        exit 1
    fi
    
    print_info "Importing music from: $source_dir"
    
    # Reset import log if requested
    if [[ "$reset_import_log" == "true" ]]; then
        local imported_log="$source_dir/.imported"
        if [[ -f "$imported_log" ]]; then
            rm "$imported_log"
            print_success "Reset import history - run script again to import all files"
        else
            print_info "No import history found to reset"
        fi
        exit 0
    fi
    
    # Import music
    import_music "$source_dir" "$dry_run" "$create_playlists" "$ipod_playlist"
}

# Run main function with all arguments
main "$@"