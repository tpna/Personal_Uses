#!/bin/bash

# Configuration
TARGET_DIR="$1"
OUTPUT_FILE="duplicates.json"

if [[ -z "$TARGET_DIR" ]]; then
    echo "Usage: $0 /path/to/folder"
    exit 1
fi

# Temp files
TMP_JSON="/tmp/fdupes_json.$$"
TMP_GROUP="/tmp/fdupes_group.$$"

> "$TMP_JSON"
> "$TMP_GROUP"

# Function to collect file metadata as JSON
get_file_info_json() {
    local file="$1"
    local size created ext name

    # File size
    size=$(stat -c "%s" "$file" 2>/dev/null)

    # Birth time (can be 0 if not supported), fallback to modification time
    created=$(stat -c "%W" "$file" 2>/dev/null)
    if [[ "$created" -le 0 ]]; then
        created=$(stat -c "%Y" "$file")
    fi

    ext="${file##*.}"
    name="${file##*/}"

    # Output a single JSON object
    echo "{"
    echo "  \"file\": \"$file\","
    echo "  \"size\": $size,"
    echo "  \"created\": $created,"
    echo "  \"extension\": \"$ext\","
    echo "  \"filename\": \"$name\""
    echo "}"
}

# Read fdupes output, grouping duplicates
fdupes -r "$TARGET_DIR" | while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        # Blank line -> end of a duplicate group
        if [[ -s "$TMP_GROUP" ]]; then
            echo "[" >> "$TMP_JSON"
            while IFS= read -r file; do
                get_file_info_json "$file"
                echo ","  # trailing comma for each file
            done < "$TMP_GROUP"
            # Remove the last trailing comma
            sed -i '$ s/,$//' "$TMP_JSON"
            echo "]," >> "$TMP_JSON"
            > "$TMP_GROUP"
        fi
    else
        # Still in a duplicate group
        echo "$line" >> "$TMP_GROUP"
    fi
done

# If there was a final group without a trailing blank line, handle it:
if [[ -s "$TMP_GROUP" ]]; then
    echo "[" >> "$TMP_JSON"
    while IFS= read -r file; do
        get_file_info_json "$file"
        echo ","  
    done < "$TMP_GROUP"
    sed -i '$ s/,$//' "$TMP_JSON"
    echo "]," >> "$TMP_JSON"
    > "$TMP_GROUP"
fi

# Remove the final trailing comma in TMP_JSON (after the last group)
sed -i '$ s/,$//' "$TMP_JSON"

# Now wrap everything in an array so TMP_JSON is valid JSON: array of arrays
# (i.e. [[{...},{...}], [{...},{...}], ...])
echo "[" > "$OUTPUT_FILE"
cat "$TMP_JSON" >> "$OUTPUT_FILE"
echo "]" >> "$OUTPUT_FILE"

# We'll now group the flattened contents by size, extension, created, and filename.
# Then store them in OUTPUT_FILE.
mv "$OUTPUT_FILE" "$OUTPUT_FILE.tmp"

jq '
  # 1) Turn our array-of-arrays into a single flat list
  [ flatten
    # 2) Group by the requested fields
    | group_by(.size, .extension, .created, .filename)
    # 3) Reshape the data: show size, extension, created, filename,
    #    plus an array of the file paths in "duplicates".
    | map({
        size: .[0].size,
        extension: .[0].extension,
        created: .[0].created,
        filename: .[0].filename,
        duplicates: map(.file)
      })
  ]
  # 4) Finally sort by these fields
  | sort_by(.size, .extension, .created, .filename)
' "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"

# Clean up
rm -f "$TMP_JSON" "$TMP_GROUP" "$OUTPUT_FILE.tmp"

echo "Duplicates information saved to $OUTPUT_FILE"