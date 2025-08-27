#!/bin/bash

set -euo pipefail

# Configuration
DEFAULT_OUTPUT_DIR="$HOME/Music/downloads"
DEFAULT_QUALITY="320"
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
Usage: $SCRIPT_NAME [OPTIONS] URL

Download YouTube playlist or video in high-quality MP3 format.

OPTIONS:
    -o, --output DIR        Output directory (default: ~/Music/downloads)
    -q, --quality KBPS      Audio quality in kbps (default: $DEFAULT_QUALITY)
                           Available: 128, 192, 256, 320
    -h, --help             Show this help message

EXAMPLES:
    # Download playlist
    $SCRIPT_NAME "https://www.youtube.com/playlist?list=PLxxx"
    
    # Download single video
    $SCRIPT_NAME "https://www.youtube.com/watch?v=VIDEO_ID"
    
    # Custom output directory and quality
    $SCRIPT_NAME -o ~/Music/my-downloads -q 256 "https://www.youtube.com/playlist?list=PLxxx"

REQUIREMENTS:
    - yt-dlp (pip install yt-dlp)
    - ffmpeg (brew install ffmpeg or apt-get install ffmpeg)

EOF
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yt-dlp &> /dev/null; then
        missing_deps+=("yt-dlp")
    fi
    
    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Install instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "yt-dlp")
                    echo "  pip install yt-dlp"
                    ;;
                "ffmpeg")
                    echo "  macOS: brew install ffmpeg"
                    echo "  Ubuntu/Debian: apt-get install ffmpeg"
                    ;;
            esac
        done
        exit 1
    fi
}

# Function to validate quality
validate_quality() {
    local quality=$1
    case $quality in
        128|192|256|320)
            return 0
            ;;
        *)
            print_error "Invalid quality: $quality. Available: 128, 192, 256, 320"
            exit 1
            ;;
    esac
}

# Function to validate YouTube URL (playlist or video)
validate_url() {
    local url=$1
    if [[ ! $url =~ ^https?://(www\.)?(youtube\.com|youtu\.be) ]]; then
        print_error "Invalid YouTube URL: $url"
        exit 1
    fi
    
    # Accept both playlist and video URLs
    if [[ ! $url =~ (playlist\?list=|list=|watch\?v=|youtu\.be/) ]]; then
        print_error "URL does not appear to be a valid YouTube playlist or video: $url"
        exit 1
    fi
}

# Function to download playlist or video
download_content() {
    local url=$1
    local output_dir=$2
    local quality=$3
    
    # Determine if it's a playlist or single video
    if [[ $url =~ (playlist\?list=|list=) ]]; then
        print_info "Starting download of playlist: $url"
    else
        print_info "Starting download of video: $url"
    fi
    print_info "Output directory: $output_dir"
    print_info "Audio quality: ${quality}kbps"
    
    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Ensure the Music directory exists 
    if [[ "$output_dir" == "$HOME/Music/"* ]]; then
        mkdir -p "$HOME/Music"
    fi
    
    # Download playlist and filter out exec output
    yt-dlp \
        --format "bestaudio/best" \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality "$quality"k \
        --output "$output_dir/%(uploader)s/%(title).200s.%(id)s.%(ext)s" \
        --exec 'python3 -c "
import os, re, sys
try:
    old_path = sys.argv[1]
    if old_path.endswith(\".mp3\"):
        dir_name = os.path.dirname(old_path)
        base_name = os.path.basename(old_path)
        # Split filename and extension
        name_part, ext = os.path.splitext(base_name)
        # Remove content in square brackets and clean up
        clean_name = re.sub(r\"\[.*?\]\", \"\", name_part)
        # Clean up extra spaces, underscores, and trailing punctuation
        clean_name = re.sub(r\"[_\s]+\", \"_\", clean_name.strip())
        clean_name = re.sub(r\"_+\.\", \".\", clean_name)  # Remove underscores before dots
        clean_name = re.sub(r\"^_+|_+$\", \"\", clean_name)
        # Reconstruct filename
        clean_filename = clean_name + ext
        new_path = os.path.join(dir_name, clean_filename)
        if old_path != new_path and not os.path.exists(new_path):
            os.rename(old_path, new_path)
except: pass
" {} 2>/dev/null' \
        --restrict-filenames \
        --embed-metadata \
        --add-metadata \
        --ignore-errors \
        --no-playlist-reverse \
        --download-archive "$output_dir/.downloaded" \
        "$url" 2>&1 | grep -v -E "^\[Exec\] Executing command:|^(import|try:|except:|    |\" )"
    
    if [ $? -eq 0 ]; then
        if [[ $url =~ (playlist\?list=|list=) ]]; then
            print_success "Playlist download completed successfully!"
        else
            print_success "Video download completed successfully!"
        fi
        print_info "Files saved to: $output_dir"
    else
        print_error "Download failed"
        exit 1
    fi
}

# Main function
main() {
    local output_dir="$DEFAULT_OUTPUT_DIR"
    local quality="$DEFAULT_QUALITY"
    local youtube_url=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -q|--quality)
                quality="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
            *)
                if [ -z "$youtube_url" ]; then
                    youtube_url="$1"
                else
                    print_error "Multiple URLs provided. Only one YouTube URL is allowed."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [ -z "$youtube_url" ]; then
        print_error "YouTube URL is required"
        echo
        show_help
        exit 1
    fi
    
    validate_quality "$quality"
    validate_url "$youtube_url"
    check_dependencies
    
    # Download content
    download_content "$youtube_url" "$output_dir" "$quality"
}

# Run main function with all arguments
main "$@"