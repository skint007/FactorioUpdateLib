#!/bin/bash

source ./updateFunctions.sh

# Ensure the functions library was loaded
if ! declare -F get_factorio_version > /dev/null; then
  echo "Update functions library was not loaded."
  exit 1
fi

# Default parameters
jsonConfig=""
modHost="mods.factorio.com"
basePath="/opt/factorio"

# Parse command line arguments
while (( $# )); do
    case "$1" in
        --server-settings)
            jsonConfig="$2"
            shift 2
        ;;
        --basePath)
            basePath="$2"
            shift 2
        ;;
        *)
            echo "Error: Invalid argument $1"
            exit 1
        ;;
    esac
done

# Get game version and check if there was a problem
currentGameVersion=$(get_factorio_version "$basePath")
if [ $? -eq 0 ]; then
    echo -e "Game Version: $currentGameVersion"
else
    exit 1
fi

# Ensure config was provided
if [ -z "$jsonConfig" ]; then
    echo "Error: --jsonConfig is missing"
    exit 1
fi

# Set mods path based on basePath
modsPath="$basePath/mods"

# Get the username and token from the config file
username=$(jq -r '.username' "$jsonConfig")
token=$(jq -r '.token' "$jsonConfig")

# Read the local mod data
#modNames=$(jq -r '.mods[] | select(.name != "base") | .name' $modsPath/mod-list.json)
IFS=$'\n' read -rd '' -a modNames <<< "$(jq -r '.mods[] | select(.name != "base") | .name' $modsPath/mod-list.json)"

# Counter for skipped mods
currentMods=0

# Get mod count
modCount=${#modNames[@]}
echo -e "Checking \e[33m$modCount\e[0m mods for updates "

oldIFS=$IFS
IFS=$'\n' # Fix for mod names with spaces

# Get max mod name length - for formatting
maxNameLength=0
for modName in $modNames; do
    if ((${#modName} > maxNameLength)); then
        maxNameLength=${#modName}
    fi
done

# Build string array to fetch all mods at once
modQueryString=$(join_by_comma "${modNames[@]}")

# Check if there are any updates for the mods (doesn't consider dependencies yet)
declare -a checkMods
fullModList=$(curl -s "https://$modHost/api/mods?page_size=$modCount&namelist=$modQueryString")
while read mod; do
    modName=$(echo "$mod" | jq -r '.name')
    fileName=$(echo "$mod" | jq -r '.last_release.file_name')
    if [ ! -f "$modsPath/$fileName" ]; then
        checkMods+=("$mod")
    else
        ((currentMods++))
    fi
done < <(echo "$fullModList" | jq -c '.results[] | {name: .name, last_release: .releases[-1]}')

# Go through mods that didn't exist or might have a newer version
for mod in "${checkMods[@]}"; do
    modName=$(echo "$mod" | jq -r '.name')
    echo -e " -> Dependency check for \e[33m$modName\e[0m"
    modData=$(curl -s "https://$modHost/api/mods/$modName/full")
    releases=$(echo "$modData" | jq -c '.releases[]')

    declare -a eligibleReleases=()
    for release in $releases; do
        dependencies=$(echo "$release" | jq -c '.info_json.dependencies')
        isEligible=true
        for dependency in "${dependencies[@]}"; do
          if [[ $dependency == *"base"* ]]; then
              # Extract the base version
              baseVersion=$(echo "$dependency" | grep -oP '(?<=base >= )[0-9\.]+')
              # Exclude dependencies whose dependencies are greater than $currentGameVersion
              if [ "$(compare_versions "$baseVersion" "$currentGameVersion")" = true ]; then
                  isEligible=false
                  break
              fi
          fi
        done

        # If the release is eligible, add it to the list of eligible releases
        if [ "$isEligible" = true ]; then
            eligibleReleases+=("$release")
        fi
    done

    # Get the last release that is left in the list of eligible releases
    currentRelease=${eligibleReleases[-1]}
    
    modFile="$modsPath/$(echo "$currentRelease" | jq -r '.file_name')"
    if [ -f "$modFile" ]; then
        ((currentMods++))
    else
        printf " -> Installing\e[33m %-*s" "$maxNameLength" "$modName "

        modDownloadUri="https://$modHost$(echo "$currentRelease" | jq -r '.download_url')?username=$username&token=$token"
        curl -L -s -o "$modFile" "$modDownloadUri"

        # Verify checksum
        modsha1=$(echo "$currentRelease" | jq -r '.sha1')
        computedSha1=$(sha1sum $modFile | awk '{ print $1 }')
        if [[ $modsha1 = $computedSha1 ]]; then
            echo -e "\e[0m[\e[32mDone\e[0m]"
            chmod 0775 "$modFile"
        else
            echo -e "\e[0m[\e[31mFailed\e[0m]"
            echo -e " ---> Checksum \e[33mmis\e[36mmatch\e[0m" 1>&2
            echo " ---> Expected: $modsha1" 1>&2
            echo " ---> Computed: $computedSha1" 1>&2
        fi

        # Delete old versions
        find "$modsPath" -type f -name "$modName\_*.zip" ! -name "$(basename $modFile)" -delete
    fi
done
echo -e " -> Skipped \e[36m$currentMods\e[0m current mods"