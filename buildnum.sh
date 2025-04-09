#/bin/bash

if [ ! "$BUILDREF" ]; then
	# This is where this script is
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	BUILDREF="$DIR/.builds"
fi

# Make it if it's missing.
[ ! -d "$BUILDREF" ] && mkdir -p "$BUILDREF"

# Make sure the branch is YYYY.MM.DD format
BRANCH=$1
if [[ ! "$BRANCH" =~ ^20[0-9\.]{5}$ ]]; then
  BRANCH=$(date +%Y.%m)
fi

# This is where it's going
BUILDFILE="$BUILDREF/$BRANCH"

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

if [[ "$2" == --date ]]; then
  date --date=@$(stat --format=%Y $BUILDFILE) --utc
else
  echo $BUILDNUM
fi

