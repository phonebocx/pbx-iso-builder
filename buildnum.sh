#/bin/bash

# This is where this script is
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is where our build markers are kept
BUILDDIR="$DIR/.builds"

# Make it if it's missing.
[ ! -d "$BUILDDIR" ] && mkdir -p "$BUILDDIR"

# Make sure the branch is YYYY.MM.DD format
BRANCH=$1
if [[ ! "$BRANCH" =~ ^20[0-9\.]{5}$ ]]; then
  BRANCH=$(date +%Y.%m)
fi

# This is where it's going
BUILDFILE="$BUILDDIR/$BRANCH"

# If it doesn't exist, this is build 1
if [ ! -e "$BUILDFILE" ]; then
  echo 1 > $BUILDFILE
fi

# Get the contents of it
BUILDNUM=$(cat $BUILDFILE)

# Have we been asked to increment it?
if [[ "$2" == --inc* ]]; then
  BUILDNUM=$(( $BUILDNUM + 1 ))
  echo $BUILDNUM > $BUILDFILE
fi

echo $BUILDNUM

