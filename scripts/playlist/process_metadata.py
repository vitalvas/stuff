#!/usr/bin/env python3
"""
Process downloaded MP3 files: clean filenames and update metadata with channel name as artist.
"""

import os
import re
import sys
import json
import subprocess
from typing import Optional


def extract_channel_name(info_json_path: str) -> Optional[str]:
    """Extract channel name from YouTube metadata JSON file."""
    if not os.path.exists(info_json_path):
        return None
    
    try:
        with open(info_json_path, "r", encoding="utf-8") as f:
            info = json.load(f)
            channel_name = info.get("uploader", "") or info.get("channel", "")
            return channel_name if channel_name else None
    except (json.JSONDecodeError, IOError):
        return None


def clean_filename(name_part: str) -> str:
    """Clean filename by removing square brackets and extra characters."""
    # Remove content in square brackets and clean up
    clean_name = re.sub(r"\[.*?\]", "", name_part)
    # Clean up extra spaces, underscores, and trailing punctuation
    clean_name = re.sub(r"[_\s]+", "_", clean_name.strip())
    clean_name = re.sub(r"_+\.", ".", clean_name)  # Remove underscores before dots
    clean_name = re.sub(r"^_+|_+$", "", clean_name)
    return clean_name


def update_mp3_metadata(file_path: str, artist: str) -> bool:
    """Update MP3 metadata with artist information using ffmpeg."""
    if not os.path.exists(file_path):
        return False
    
    temp_path = file_path + ".tmp"
    cmd = ["ffmpeg", "-i", file_path, "-metadata", f"artist={artist}", "-codec", "copy", "-y", temp_path]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0 and os.path.exists(temp_path):
            os.replace(temp_path, file_path)
            return True
        elif os.path.exists(temp_path):
            os.remove(temp_path)
    except (subprocess.SubprocessError, OSError):
        if os.path.exists(temp_path):
            os.remove(temp_path)
    
    return False


def process_mp3_file(file_path: str) -> None:
    """Process a single MP3 file: clean filename and update metadata."""
    if not file_path.endswith(".mp3"):
        return
    
    dir_name = os.path.dirname(file_path)
    base_name = os.path.basename(file_path)
    name_part, ext = os.path.splitext(base_name)
    
    # Look for corresponding .info.json file
    info_json_path = os.path.join(dir_name, name_part + ".info.json")
    channel_name = extract_channel_name(info_json_path)
    
    # Clean up info.json file after extracting metadata
    if os.path.exists(info_json_path):
        try:
            os.remove(info_json_path)
        except OSError:
            pass
    
    # Clean filename
    clean_name = clean_filename(name_part)
    clean_filename = clean_name + ext
    new_path = os.path.join(dir_name, clean_filename)
    
    # Rename file if needed
    final_path = file_path
    if file_path != new_path and not os.path.exists(new_path):
        try:
            os.rename(file_path, new_path)
            final_path = new_path
        except OSError:
            pass
    
    # Update MP3 metadata with channel name as artist
    if channel_name and os.path.exists(final_path):
        update_mp3_metadata(final_path, channel_name)


def main():
    """Main function to process MP3 file from command line argument."""
    if len(sys.argv) != 2:
        sys.exit(1)
    
    file_path = sys.argv[1]
    try:
        process_mp3_file(file_path)
    except Exception:
        # Silent failure to match original behavior
        pass


if __name__ == "__main__":
    main()