#!/bin/bash

source ./updateFunctions.sh

# Ensure the functions library was loaded
if ! declare -F get_factorio_version > /dev/null; then
  echo "Update functions library was not loaded."
  exit 1
fi

updateCheckUrl="https://factorio.com/api/latest-releases"
webVersion=$(curl -s "$updateCheckUrl" | jq -r '.stable.headless')
updateHeadlessUrl="https://factorio.com/get-download/stable/headless/linux64"
updateHeadlessFile="factorio_headless_x64_$webVersion.tar.xz"
checksumsUrl="https://www.factorio.com/download/sha256sums/"
basePath="$HOME/factoriosvr"

# Check for update
echo "Checking for update"
fileVersion=$(get_factorio_version "$basePath/factorio")
echo "Your version: '$fileVersion'"
echo " Web version: '$webVersion'"

if [ -z "$fileVersion" ]; then
    echo "Error: Unable to determine factorio file version." 1>&2
    exit 1
fi

# If it doesn't match, we need to update
if [[ $fileVersion != $webVersion* ]]; then
    echo "Version mismatch... Updating from: $updateHeadlessUrl"
    
    downloadPath="$basePath/$updateHeadlessFile"
    echo "Downloading to: $downloadPath"
    if wget -q -O "$downloadPath" "$updateHeadlessUrl"; then
        # Download checksums
        checksums=$(curl -s "$checksumsUrl")
        
        # Extract the sha256sum from the checksums string
        downloadedSha256=$(echo "$checksums" | grep $updateHeadlessFile | awk '{ print $1 }')
        
        # Compute the sha256sum of the downloaded file
        computedSha256=$(sha256sum $downloadPath | awk '{ print $1 }')
        
        # Compare the sha256sums
        if [[ $downloadedSha256 = $computedSha256 ]]; then
            echo "Checksums match"
            # Change location for extracting, to just outside factorio folder
            echo "Extracting to: $basePath"
            tar -xJf "$downloadPath" -C "$basePath" || echo "Error extracting $downloadPath" 1>&2
            # Cleanup
            rm "$downloadPath"
        else
            echo "Checksums do not match" 1>&2
            echo -e "Expected $downloadedSha256" 1>&2
            echo -e "Computed $computedSha256" 1>&2
            exit 1
        fi
    else
        echo "Error downloading $updateHeadlessUrl" 1>&2
    fi
else
    echo "Up-to-date"
fi
