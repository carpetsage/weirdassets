#!/usr/bin/env zsh
force=0
filter=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            force=1
            shift
            ;;
        *)
            if [[ -z "$filter" ]]; then
                filter="$1"
            else
                echo "ERROR: Multiple filter arguments provided. Only one filter string is allowed."
                exit 1
            fi
            shift
            ;;
    esac
done

# Detect which ImageMagick command is available
if command -v magick >/dev/null 2>&1; then
    MAGICK_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK_CMD="convert"
else
    echo "ERROR: Neither 'magick' nor 'convert' command found. Please install ImageMagick."
    exit 1
fi


echo "Creating directories..."
for size in 32 64 128 256; do
    mkdir -p $size/egginc $size/egginc-extras $size/egginc-extras/glow
done

echo "Processing files..."

# Build file patterns based on filter
if [[ -n "$filter" ]]; then
    echo "Using filter: *${filter}*.png"
    pattern1="orig/egginc/${filter}*.png"
    pattern2="orig/egginc-extras/**/${filter}*.png"
else
    echo "Processing all PNG files"
    pattern1="orig/egginc/*.png"
    pattern2="orig/egginc-extras/**/*.png"
fi

# Native zsh parallelization with job control
MAX_JOBS=10
typeset -a job_pids=()

# Set null_glob option to handle patterns that don't match anything
setopt null_glob

# Collect all files into an array based on filter
files=(${~pattern1} ${~pattern2})

# Restore default glob behavior
unsetopt null_glob

total_files=${#files[@]}

if (( total_files == 0 )); then
    echo "ERROR: No matching PNG files found!"
    if [[ -n "$filter" ]]; then
        echo "Filter used: *${filter}*.png"
    fi
    exit 1
fi

echo "Found $total_files files to process with $MAX_JOBS parallel jobs..."

for src in "${files[@]}"; do
    # Wait if we've reached the maximum number of jobs
    while (( ${#job_pids[@]} >= MAX_JOBS )); do
        # Check for completed jobs and remove them from the array
        local new_pids=()
        for pid in "${job_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            fi
        done
        job_pids=("${new_pids[@]}")
        
        # If we still have too many jobs, sleep briefly
        if (( ${#job_pids[@]} >= MAX_JOBS )); then
            sleep 0.1
        fi
    done
    
    # Start a new background job
    {
        echo "Processing: $src"

        dst=$src:r.webp
        ((( force )) || [[ ! -e $dst ]]) && {
            echo "Creating WebP: $src => $dst"
            if ! $MAGICK_CMD "$src" -define webp:lossless=true "$dst"; then
                echo "ERROR: $MAGICK_CMD failed for WebP conversion: $src"
                exit 1
            fi
        }

        for size in 32 64 128 256; do
            dst=${size}/${src#orig/}
            ((( force )) || [[ ! -e $dst ]]) && {
                echo "Resizing PNG: $src => $dst (${size}x${size})"
                # Trim whitespace, resize maintaining aspect ratio, then pad to exact size
                if ! $MAGICK_CMD "$src" -trim +repage -resize ${size}x${size} -background transparent -gravity center -extent ${size}x${size} "$dst"; then
                    echo "ERROR: $MAGICK_CMD failed for PNG resize: $src"
                    exit 1
                fi
                echo "Optimizing PNG: $dst"
                if ! optipng -quiet "$dst"; then
                    echo "ERROR: optipng failed for: $dst"
                    exit 1
                fi
            }
            dst=$dst:r.webp
            ((( force )) || [[ ! -e $dst ]]) && {
                echo "Creating resized WebP: $src => $dst (${size}x${size})"
                # Trim whitespace, resize maintaining aspect ratio, then pad to exact size
                if ! $MAGICK_CMD "$src" -trim +repage -resize ${size}x${size} -background transparent -gravity center -extent ${size}x${size} "$dst"; then
                    echo "ERROR: $MAGICK_CMD failed for WebP resize: $src"
                    exit 1
                fi
            }
        done
    } &
    
    # Store the PID of the background job
    job_pids+=($!)
done

# Wait for all remaining jobs to complete
for pid in "${job_pids[@]}"; do
    wait "$pid"
done

echo "Script completed successfully!"
