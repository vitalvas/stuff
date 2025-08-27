# YouTube Downloader

A bash script to download YouTube playlists and individual videos in high-quality MP3 format with clean filenames and skip already downloaded tracks.

## Features

- ✅ Downloads YouTube playlists and individual videos in high-quality MP3 (320kbps)
- ✅ Organizes music into albums based on YouTube channel names
- ✅ Clean, filesystem-safe filenames (no emojis, Unicode characters, removes [brackets])
- ✅ Includes YouTube video ID in filenames for uniqueness
- ✅ Skips already downloaded tracks automatically
- ✅ Configurable audio quality and output directory
- ✅ Cross-platform support (macOS, Linux)

## Requirements

Install the following dependencies before using the script:

### macOS
```bash
# Install yt-dlp
pip install yt-dlp

# Install ffmpeg
brew install ffmpeg
```

### Linux (Ubuntu/Debian)
```bash
# Install yt-dlp
pip install yt-dlp

# Install ffmpeg
sudo apt-get update
sudo apt-get install ffmpeg
```

## Usage

### Basic Usage
```bash
# Download playlist
./download.sh "https://www.youtube.com/playlist?list=YOUR_PLAYLIST_ID"

# Download single video
./download.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Advanced Usage
```bash
# Custom output directory and quality (playlist)
./download.sh -o ./music -q 256 "https://www.youtube.com/playlist?list=YOUR_PLAYLIST_ID"

# Custom output directory and quality (single video)
./download.sh -o ./music -q 256 "https://www.youtube.com/watch?v=VIDEO_ID"

# Show help
./download.sh --help
```

### Options
- `-o, --output DIR`: Output directory (default: ./downloads)
- `-q, --quality KBPS`: Audio quality in kbps (default: 320)
  - Available: 128, 192, 256, 320
- `-h, --help`: Show help message

## Example Output

Downloaded files are organized into albums based on YouTube channel names:
```
downloads/
├── ImagineDragons/
│   ├── Imagine_Dragons_-_Natural.0I647GU3Jsc.mp3
│   └── Imagine_Dragons_-_Thunder.fKopy74weus.mp3
├── Nightwish/
│   └── Nightwish_-_Storytime_OFFICIAL_MUSIC_VIDEO.09MTDBb8qro.mp3
└── Electric_Love_Festival/
    └── Electric_Love_Festival_2024_Opening_Ceremony.r3BvNyw0BJk.mp3
```

**Filename Cleaning Examples:**
- `Song_Name_[Official_Video].abc123.mp3` → `Song_Name.abc123.mp3`
- `Artist_-_Song_[HD]_[Remastered].xyz456.mp3` → `Artist_-_Song.xyz456.mp3`

## Skip Already Downloaded

The script automatically tracks downloaded videos in a `.downloaded` file in the output directory. Re-running the script will skip already downloaded tracks and only download new ones.

## Import Music to Music App

### Automated Import (Recommended)

Use the included import script for easy, organized importing:

```bash
# Import all downloaded music
./import_music.sh

# Preview what will be imported (dry-run)
./import_music.sh --dry-run

# Import and create playlists for each artist
./import_music.sh --create-playlists

# Import and create iPod playlist (recommended for iPod users)
./import_music.sh --ipod-playlist

# Import and create iPod playlist with custom name
./import_music.sh --ipod-playlist "My iPod Music"

# Import from custom directory
./import_music.sh ~/Music/YouTube
```

**Features:**
- ✅ Maintains album structure (channel names become albums)
- ✅ Preserves metadata and file organization
- ✅ Duplicate detection and handling
- ✅ Optional playlist creation per artist/channel
- ✅ iPod playlist creation (perfect for iPod syncing)
- ✅ Dry-run mode to preview imports

### Manual Import

1. **Open Music App** on your Mac
2. **Import music files**:
   - Go to `File > Import` or drag MP3 files into Music app
   - Select all your downloaded MP3 files
3. **Organize by album** (optional):
   - Each channel folder becomes an album in your library

## How to Transfer Music to iPod

### Method 1: Music App (macOS)

After importing music (using automated script or manually):

1. **Connect your iPod** via USB cable
2. **Sync music**:
   - Select your iPod from the sidebar
   - Go to the `Music` tab
   - Choose sync options:
     - `Sync entire music library` (recommended)
     - Or `Selected playlists, artists, albums, and genres`
     - **For iPod playlist users**: Select only your created iPod playlist
   - Click `Apply` or `Sync`

**Pro Tip:** If you used `--ipod-playlist`, simply select the "ipod" playlist (or your custom name) for syncing instead of your entire library.

### Method 2: Third-Party Tools (Alternative)

#### Using gtkpod (Linux)

```bash
# Install gtkpod
sudo apt-get install gtkpod

# Launch gtkpod and connect your iPod
gtkpod
```

### Method 3: Manual Transfer (iPod Touch/iPhone)

For newer iPod Touch models:
1. **Use AirDrop** (macOS to iOS):
   - Select MP3 files in Finder
   - Right-click and choose `Share > AirDrop`
   - Select your iPod Touch
   
2. **Use cloud storage**:
   - Upload MP3s to iCloud Drive, Google Drive, or Dropbox
   - Download using respective apps on iPod Touch
   
3. **Use third-party apps**:
   - Install apps like VLC, Documents by Readdle, or Infuse
   - Transfer files via iTunes File Sharing or cloud sync

### Tips for Better iPod Experience

1. **Organize your music**: Create playlists in iTunes/Music app before syncing
2. **Check file formats**: Ensure MP3 files are compatible (this script outputs standard MP3)
3. **Manage storage**: Monitor iPod storage space, especially with high-quality 320kbps files
4. **Backup**: Keep original downloaded files as backup on your computer
5. **Metadata**: The script embeds metadata, so song info will display correctly on iPod

### Troubleshooting iPod Transfer

**iPod not recognized**:
- Try different USB cable
- Restart both computer and iPod
- Update iTunes/Music app
- Check USB port

**Sync issues**:
- Disable automatic sync, manually select music
- Check available storage space
- Try syncing smaller batches of songs

**File format issues**:
- This script outputs standard MP3 which is compatible with all iPods
- If issues persist, try re-downloading with different quality settings

## File Structure

```
playlist/
├── download.sh                  # Download script (main)
├── import_music.sh              # Import script for Music app
├── README.md                    # This file
├── downloads/                   # Default output directory
│   ├── .downloaded             # Tracks downloaded videos (auto-generated)
│   ├── ChannelName1/           # Album folder (YouTube channel)
│   │   └── *.mp3              # Music files from this channel
│   └── ChannelName2/           # Another album folder
│       └── *.mp3              # Music files from this channel
└── test_*/                     # Test directories (optional)
```

## Examples

### Download a playlist with default settings (320kbps, ./downloads/)
```bash
./download.sh "https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Download a single video
```bash
./download.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

### Download to specific directory with custom quality
```bash
# Playlist
./download.sh -o ~/Music/YouTube -q 192 "https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Single video  
./download.sh -o ~/Music/YouTube -q 192 "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

### Re-run to download only new tracks
```bash
# Running the same command again will skip already downloaded tracks
./download.sh "https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Notes

- Private videos in playlists will show authentication errors but won't stop the download process
- The script sleeps between downloads to respect YouTube's rate limiting
- Large playlists may take considerable time to download
- Downloaded files include embedded metadata (title, artist, etc.)
- Video IDs in filenames ensure uniqueness and prevent conflicts

## License

This script is provided as-is for personal use. Respect YouTube's Terms of Service and only download content you have rights to use.