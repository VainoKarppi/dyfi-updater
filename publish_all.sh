#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version-id>"
  echo "Example: $0 1.2.3"
  exit 1
fi

version="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
publish_root="$repo_root/publish"
target_root="$publish_root/dyfi_updater_$version"
csharp_publish_dir="$repo_root/csharp/publish"

echo "Running C# publish..."
cd "$repo_root/csharp"
bash ./publish.sh

echo "Preparing publish folder: $target_root"
rm -rf "$target_root"
mkdir -p "$target_root"

if [ ! -d "$csharp_publish_dir" ]; then
  echo "ERROR: C# publish output not found at $csharp_publish_dir"
  exit 1
fi

mkdir -p "$target_root/csharp"
echo "Copying C# published outputs..."
cp -R "$csharp_publish_dir/." "$target_root/csharp/"
find "$target_root/csharp" -type f \( -name 'log.log' -o -name 'lastupdate.txt' \) -delete

for dir in python docker powershell shell; do
  source_dir="$repo_root/$dir"
  target_dir="$target_root/$dir"

  if [ ! -d "$source_dir" ]; then
    echo "WARNING: directory '$dir' not found, skipping."
    continue
  fi

  echo "Copying $dir..."
  rm -rf "$target_dir"
  cp -R "$source_dir" "$target_dir"
  find "$target_dir" -type f \( -name 'log.log' -o -name 'lastupdate.txt' \) -delete
  echo "Copied $dir to $target_dir"
done

if [ -f "$repo_root/USAGE.txt" ]; then
  echo "Copying root documentation..."
  cp "$repo_root/USAGE.txt" "$target_root/USAGE.txt"
fi

echo "Removing extra runtime artifacts from final package..."
find "$target_root" -type f \( -name 'log.log' -o -name 'lastupdate.txt' \) -delete

# ---------------- APPEND HASHES TO USAGE.TXT ----------------
echo "Appending build hashes to USAGE.txt..."
usage_file="$target_root/USAGE.txt"
if [ -f "$usage_file" ]; then
  echo "" >> "$usage_file"
  echo "Build Hashes (Created automatically on 'publish_all')" >> "$usage_file"
  echo "============" >> "$usage_file"
  for platform in win-x64 linux-arm64 linux-x64 osx-x64; do
    hash_file="$target_root/csharp/$platform/hashes.sha256"
    if [ -f "$hash_file" ]; then
      echo "" >> "$usage_file"
      echo "$platform:" >> "$usage_file"
      cat "$hash_file" >> "$usage_file"
    fi
  done
fi

echo "Published package created at: $target_root"
