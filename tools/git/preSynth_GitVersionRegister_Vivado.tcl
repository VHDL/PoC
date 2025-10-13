## EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
## vim: tabstop=2:shiftwidth=2:noexpandtab
## kate: tab-width 2; replace-tabs off; indent-width 2;
## =============================================================================
## Authors:         Stefan Unrein
##                  Max Kraft-Kugler
##                  Patrick Lehmann
##                  Iqbal Asif
##
## Script:         preSynth_GitVersionRegister_Vivado.tcl
##
## Description:
## -------------------------------------
## Use as pre-synthesis tcl file to create the memory file for the
## AXI4Lite_GitVersionRegister.
##
## The relative paths are used as for the default project-folder-structure of PoC
##
## License:
## =============================================================================
## Copyright 2025-2025 The PoC-Library Authors
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
## =============================================================================

puts "BuildVersion: Running script..."

# Script configuration
# Go up by three folders from ./project/my_project.runs/synth_1
set version_file ../../../temp/GitVersion.mem;

# Project Versioning
if {[catch {open "../../../Project_Version" r} results]} {
	set Project_Major 0
	set Project_Minor 0
	set Project_Release [exec git rev-list --count HEAD]
} else {
	set project_version_file [open "../../../Project_Version" r]
	set project_version [read $project_version_file]
	close $project_version_file
	set project_version [split $project_version "."]
	set Project_Major [lindex $project_version 0]
	set Project_Minor [lindex $project_version 1]
	set Project_Release [lindex $project_version 2]
	if {$Project_Release eq ""} {set Project_Release [exec git rev-list --count HEAD]}
}

# Constants
set VersionOfVersionReg 1

# Build date
set systemTime      [clock seconds]
set BuildDate_Day   [clock format $systemTime -format {%d}]
set BuildDate_Month [clock format $systemTime -format {%m}]
set BuildDate_Year  [clock format $systemTime -format {%Y}]

# Vivado information
set VivadoVersion            [version -short]
set VivadoVersion_Year       [string range $VivadoVersion 0 3]
set VivadoVersion_Release    [string range $VivadoVersion 5 5]
set VivadoVersion_SubRelease [string range $VivadoVersion 7 7]

if {$VivadoVersion_SubRelease eq ""} {set VivadoVersion_SubRelease 0}

set ProjectName [get_property NAME [current_project]]

# Git information
set git_hash                 [exec git rev-parse HEAD]
set git_branch               [exec git symbolic-ref --short HEAD]
set git_remote               [lindex [exec git remote] 0]
set git_url    [string range [exec git remote get-url $git_remote] 19 127]

if {[catch {exec git status -s | findstr /b /i ".m"} results]} {set dirty_modified 0} else {set dirty_modified 1}
if {[catch {exec git status -s | findstr /b /i "??"} results]} {set dirty_untracked 0} else {set dirty_untracked 1}

set GitDateTime   [exec git show -s --format=%ci HEAD]
set GitDate_Year  [string range $GitDateTime 0 3]
set GitDate_Month [string range $GitDateTime 5 6]
set GitDate_Day   [string range $GitDateTime 8 9]
set GitTime_Hour  [string range $GitDateTime 11 12]
set GitTime_Min   [string range $GitDateTime 14 15]
set GitTime_Sec   [string range $GitDateTime 17 18]
set GitTime_Zone  [string range $GitDateTime 20 22]

# Modules
set NumberModule 0


puts "BuildVersion: Writing Version Data to $version_file"

set fo [open $version_file w]

# Automated Build Version Script
puts $fo "$BuildDate_Day
$BuildDate_Month
$BuildDate_Year
$NumberModule
$VersionOfVersionReg
$VivadoVersion_Year
$VivadoVersion_Release
$VivadoVersion_SubRelease
$ProjectName
$Project_Major
$Project_Minor
$Project_Release
0
$dirty_untracked
$dirty_modified
$git_hash
$GitDate_Day
$GitDate_Month
$GitDate_Year
$GitTime_Hour
$GitTime_Min
$GitTime_Sec
$GitTime_Zone
$git_branch
$git_url
"
close $fo

puts "=============="
