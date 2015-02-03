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
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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
dst=poc.export/
cd $(dirname $0)/../../..
mkdir -p $dst
rsync -av --filter=':en+ .publish' --filter='- *' \
          --prune-empty-dirs --delete poc/ $dst
