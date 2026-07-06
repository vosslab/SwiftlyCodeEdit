#!/usr/bin/env sh

# This script refreshes the source-built CodeLanguages-Container support files.
#
# Just call it from the root of the project
# $ ./build_framework.sh
#
# If you need debug output, set the --debug flag
# $ ./build_framework.sh --debug
#
# Created by: Lukas Pistrol on 29.10.2022

# convenience function to print a status message in green
status () {
    local GREEN='\033[0;32m'
    local NC='\033[0m' # No Color
    echo "${GREEN}◆ $1${NC}"
}

# If --debug set -quiet flag and redirect output to /dev/null
if [ "$1" = "--debug" ]; then
    QUIET_FLAG=""
    QUIET_OUTPUT=/dev/stdout
else
    QUIET_FLAG="-quiet"
    QUIET_OUTPUT=/dev/null
fi

# Set pipefail to make sure that the script fails if any of the commands fail
set -euo pipefail

# resolve package dependencies for the package graph
status "Resolving Swift package dependencies..."
swift package resolve $QUIET_FLAG &> $QUIET_OUTPUT
status "Package resolution complete!"

CHECKOUTS_PATH="$PWD/.build/checkouts"
RESOURCES_PATH="$PWD/Sources/CodeEditLanguages/Resources"

# remove previous copied files
status "Copying language queries to package resources..."
rm -rf "$RESOURCES_PATH"

# find and copy language queries
LIST=$(find "$CHECKOUTS_PATH" -maxdepth 1 -type d -name 'tree-*' | sort)

OLD_PWD="$PWD"

for lang in $LIST ; do
    # determine how many targets a given package has
    cd "$lang"

    # get package info as JSON
    manifest=$(swift package dump-package)

    # use jq to get the target path
    targets=$(echo "$manifest" | jq -r '.targets[] | select(.type != "test") | .path')

    # use jq to count number of targets
    count=$(echo "$manifest" | jq '[.targets[] | select(.type != "test")] | length')

    # Determine if target paths are all '.'
    same=1
    for target in $targets; do
        if [[ $target != "." ]]; then
            same=0
            break
        fi
    done

    # loop through targets
    for target in $targets; do
        name=${lang##*/}

        # if there is only one target, use name
        # otherwise use target
        if [[ $count -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
            mkdir -p $RESOURCES_PATH/$name
        else
            mkdir -p $RESOURCES_PATH/$target
        fi

        highlights=$(find "$lang/$target" -type f -name "*.scm")
        for highlight in $highlights ; do
            highlight_name=${highlight##*/}

            # if there is only one target, use name
            # otherwise use target
            if [[ $count -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
                cp "$highlight" "$RESOURCES_PATH/$name/$highlight_name"
            else
                cp "$highlight" "$RESOURCES_PATH/$target/$highlight_name"
            fi
        done

        # If target paths are all '.', break out of loop
        if [[ $same -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
            break
        fi
    done
done
status "Language queries copied to package resources!"

# cleanup derived data

cd $OLD_PWD

if [ -d "$PWD/DerivedData" ]; then
    status "Cleaning up DerivedData..."
    rm -rf "$PWD/.build"
fi

status "Done!"
