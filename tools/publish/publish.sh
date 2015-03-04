#!/bin/sh
# EMACS settings: -*-   tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#   Shell Script:  Publish selected parts of the PoC library to the
#                  public GitHub repository.
#
#   Authors: Thomas B. Preußer
#            Patrick Lehmann
#
# Description:
# ------------------------------------
#   Traverses the PoC file hierarchy and copies selected entries to an
#   the export destination <repo root>/../poc.export/.
#
#   The files to be published are enumerated directly by .public files
#   within the PoC file hierachy. Typically, these files should simply
#   enlist each directory and each file to export. As the .public files
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
# suffix for the exported git repository
destRepoSuffix=".export"
debug=0

# gether information from execution environment
workingDir=`pwd`
# TODO: preserve arguments -> see poc.sh/wrapper.sh scripts

# 
# TODO: get repo name from current path
srcRepoName="PoC"

src="$srcRepoName/"
dst="$srcRepoName$destRepoSuffix/"

repoRoot="$workingDir/../../.."

cd $repoRoot
mkdir -p $dst

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

# add dry-run option if debug is enabled
if [ $debug -eq 1 ]; then
    rsyncOptions+=(--dry-run)
    echo "DEBUG: rsync ${rsyncOptions[@]} $src $dst"
fi;


# execute rsync command
if command -v grc $2>/dev/null; then
    rsync "${rsyncOptions[@]}" $src $dst | grcat "$workingDir/publish.grcrules"
else
    rsync "${rsyncOptions[@]}" $src $dst
fi;

# restore working directory
cd $workingDir