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
## axi4lite_GitVersionRegister.
##
## The relative paths are used as for the default project-folder-structure of PoC
##
## License:
## =============================================================================
## Copyright 2025-2026 The PoC-Library Authors
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
# Project root = one level above the directory containing the .xpr file.
#
# [current_project]'s DIRECTORY property is NOT reliable here: TCL.PRE hooks
# run in a separate, forked-off process for the run itself, where it has
# been observed returning "." instead of the real project directory.
# PARENT.PROJECT_PATH is reliable, though -- confirmed via a full property
# dump against a real synthesis run -- and gives the .xpr's absolute path
# directly, no filesystem search needed.
set xprPath [get_property PARENT.PROJECT_PATH [current_project]]
if {$xprPath eq ""} {
    # Fallback: PARENT.PROJECT_PATH empty (unexpected, but seen mentioned as
    # possibly specific to child/derivative projects) -- search upward from
    # pwd for the *.xpr file instead. Vivado runs this script with the
    # working directory set to the run's own output directory (e.g.
    # <project>.runs/synth_1/), regardless of nesting depth, so this works
    # at any folder depth without hardcoding a fixed number of ../ hops.
    puts "BuildVersion: PARENT.PROJECT_PATH is empty, falling back to searching\
          upward from \[pwd\] ([pwd]) for a .xpr file"
    set dir [pwd]
    for {set i 0} {$i < 10} {incr i} {
        set xprs [glob -nocomplain -directory $dir -- "*.xpr"]
        if {[llength $xprs] > 0} {
            set xprPath [lindex $xprs 0]
            break
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} { break }  ;# reached filesystem root
        set dir $parent
    }
    if {$xprPath eq ""} {
        error "BuildVersion: could not determine the project's .xpr path via\
               PARENT.PROJECT_PATH or by searching upward from [pwd]"
    }
}

# .xpr's directory is the project directory; PoC's convention is that the
# project root is one level above that (matches tools/Vivado/poc_vivado.tcl).
set prjRoot [file normalize [file join [file dirname $xprPath] ".."]]
puts "BuildVersion: prjRoot = $prjRoot  (from .xpr at $xprPath)"

set version_file         [file join $prjRoot "temp" "GitVersion.mem"]
set project_version_path [file join $prjRoot "Project_Version"]

package require fileutil
set version_file [fileutil::relative [pwd] $version_file]

set crop_str "gitlab.plc2.de"
set crop_after 1


set dirname $prjRoot/temp/
if {[file exist $dirname]} {
    # check that it's a directory
    if {! [file isdirectory $dirname]} {
        puts "$dirname exists, but it's a file"
    }
} else {
    file mkdir $dirname
}

# Project Versioning
# Git information
set git_hash                 [exec git rev-parse HEAD]
set tags_hash [exec git rev-list --tags --max-count=15]
foreach a $tags_hash {
	if { [string match v* [exec  git describe --tags --abbrev=0 --always $a]] } {
		set tag [exec  git describe --tags --abbrev=0 --always $a]
		set Commits_to_Tag $a
		break
	} elseif { [string match i* [exec  git describe --tags --abbrev=0 --always $a]] } {
		set tag [exec  git describe --tags --abbrev=0 --always $a]
		set Commits_to_Tag $a
		break
	}
}
if {[info exists tag]} {
	set tag [string range $tag 1 end]
	set tag [split $tag .]
	set Project_Major [lindex $tag 0]
	set Project_Minor [lindex $tag 1]
	set Project_Release [lindex $tag 2]
	set Commits_to_Tag [exec git rev-list ${Commits_to_Tag}.. --count]
	if {$Commits_to_Tag > 63} {
		set Commits_to_Tag 63
	}
} else {
	set Commits_to_Tag 0
	if {[catch {open "$project_version_path" r} results]} {
		set Project_Major 0
		set Project_Minor 0
		set Project_Release [exec git rev-list --count HEAD]
		if {$Project_Release > 250} {
			puts "ERROR: Fallback Version Number overflow! Change to correct versioning!"
			exit 1
		}
	} else {
		set project_version_file [open "$project_version_path" r]
		set project_version [read $project_version_file]
		close $project_version_file
		set project_version [split $project_version "."]
		set Project_Major [lindex $project_version 0]
		set Project_Minor [lindex $project_version 1]
		set Project_Release [lindex $project_version 2]
		if {$Project_Release eq ""} {set Project_Release [exec git rev-list --count HEAD]}
	}
}

puts "Commits to tag: $Commits_to_Tag"

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

if {[catch {$env(CI)} results]} {
	if {[catch {exec git symbolic-ref --short HEAD} results]} {
		set git_branch "HEAD detached"
	} else {
		set git_branch [exec git symbolic-ref --short HEAD]
	}
	if {[catch {exec git status -s | findstr /b /i ".m"} results]} {set dirty_modified 0} else {set dirty_modified 1}
	if {[catch {exec git status -s | findstr /b /i "??"} results]} {set dirty_untracked 0} else {set dirty_untracked 1}
} else {
	if {[catch {$env(CI_COMMIT_REF_NAME)} results]} {
		set git_branch "HEAD detached"
	} else {
		set git_branch $env(CI_COMMIT_REF_NAME)
	}
	set dirty_modified 0
	set dirty_untracked 0
}
set git_remote               [lindex [exec git remote] 0]

set git_url  [exec git remote get-url $git_remote]
set crop_pos [expr {[string first $crop_str $git_url] + [string length $crop_str]}]
set git_url    [string range $git_url [expr {$crop_pos + $crop_after}] [expr {$crop_pos + $crop_after + 127}]]

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


puts "BuildVersion: Writing Version Data to '$version_file'"

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
$Commits_to_Tag
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

if {[file exists $version_file]} {
    puts "Succesfully written version file"
} else {
    puts "Error during file write"
}

puts "=============="
