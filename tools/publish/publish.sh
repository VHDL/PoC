#!/bin/bash
# EMACS settings: -*-   tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Shell Script:		Publish selected parts of the PoC library to the
#									public GitHub repository.
#
#	Authors:				Thomas B. Preußer
#									Patrick Lehmann
#
# Description:
# ------------------------------------
#   Traverses the PoC file hierarchy and copies selected entries to an
#   the export destination <repo root>/../poc.export/.
#
#   The files to be published are enumerated directly by .publish files
#   within the PoC file hierarchy. Typically, these files should simply
#   enlist each directory and each file to export. As the .publish files
#   are evaluated as per-directory filter rules by rsync, additional
#   advanced features, such as exclude lines and wildcard matching, are
#   available. Their use is discouraged to maintain simplicity.
#
#
# License:
# ==============================================================================
# Copyright 2007-2015 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#               http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
set -e

# configure script here
# ----------------------
debug=0
dstSuffix=".export"
ANSI_RED="\e[31m"
ANSI_GREEN="\e[32m"
ANSI_YELLOW="\e[33m"
ANSI_CYAN="\e[36m"
ANSI_RESET="\e[0m"

COLORED_ERROR="$ANSI_RED[ERROR]$ANSI_RESET"
COLORED_DONE="$ANSI_GREEN[DONE]$ANSI_RESET"

while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-p|--publish)
		PUBLISH=TRUE
		;;
		-d|--debug)
		DEBUG=TRUE
		;;
		-h|--help)
		HELP=TRUE
		;;
		*)		# unknown option
		UNKNOWN_OPTION=TRUE
		;;
	esac
	shift # past argument or value
done

echo -e $ANSI_MAGENTA "PoC Library publish script" $ANSI_RESET
echo -e $ANSI_MAGENTA "======================================" $ANSI_RESET

if [ "$UNKNOWN_OPTION" == TRUE ]; then
	echo -e $COLORED_ERROR "Unknown command line option." $ANSI_RESET
	exit -1
elif [ "$HELP" == "TRUE" ]; then
	echo ""
	echo "Usage:"
	echo "  publish.sh [--publish]"
	echo ""
	echo "Options:"
	echo "  -h --help           Print this help page"
	echo "  -p --publish        Publish files"
	echo ""
	exit 0
fi

rsyncOptions=( \
    --archive \
    --itemize-changes \
    --human-readable \
    --verbose \
    '--filter=:en+ .publish' \
    '--filter=- *' \
    '--filter=P .git' \
    --delete --delete-excluded --prune-empty-dirs \
    --stats)

# Collect directory information finally changing into parent of repo base
cd $(dirname $0)             # script location

# Check if output filter grcat is available and install it
if grcat publish.grcrules</dev/null 2>/dev/null; then
	{ coproc grcat publish.grcrules 1>&3; } 3>&1
  exec 1>&${COPROC[1]}-
fi

cd ../..                     # repo base
src="$(basename $(pwd))"
dst="${src}$dstSuffix"
cd ..                        # parent of repo base

# add dry-run option if publish is not set (default)
if [ "$PUBLISH" != TRUE ]; then
	echo -e $ANSI_YELLOW "Running in dry-run mode." $ANSI_RESET
	echo -e $ANSI_YELLOW "Use './publish.sh --publish' to disable dry-run mode." $ANSI_RESET
  rsyncOptions+=(--dry-run)
fi

# print rsync command if debug is enabled
if [ "$DEBUG" == TRUE ]; then
  echo -e $ANSI_CYAN "DEBUG:" $ANSI_RESET "rsync ${rsyncOptions[@]} $src/ $dst/"
fi

echo ""

# Print destination info and perform the export
ret=1
if [ -e "$dst" ]; then
  if [ -d "$dst" ] &&	git -C "$dst" status >/dev/null 2>&1; then
	  echo "Updating existing public export repository $dst ..."
		rsync "${rsyncOptions[@]}" "$src/" "$dst/"
		ret=$?
	else
		echo -e 1>&2 $COLORED_ERROR " No git repository found in existing destination $dst."
	fi
else
  echo -e 1>&2 $COLORED_ERROR " Public export repository does not exist in destination $dst."
fi

# Cleanup and exit
exec 1>&-
wait # for output filter
exit $ret
