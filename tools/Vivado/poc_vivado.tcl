## =============================================================================
## Authors:         Stefan Unrein
##
## Script:          poc_vivado.tcl
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
##
## Documented for Ruff! (https://ruff.magicsplat.com): proc docs live inside
## each proc body (Ruff! reads them via [info body]), and the namespace's own
## overview lives in the _ruff_preamble variable below, not in this header.
## Generate the reference HTML with:
##   tclsh ruff.tcl document -r \
##       -e "source tools/poc.tcl; source tools/Vivado/poc_vivado.tcl" \
##       -d docs/ -s html ::poc::synth::backend::vivado

namespace eval ::poc::synth::backend::vivado {
    variable _ruff_preamble {
        Vivado implementation of the `::poc::synth` backend contract (see
        tools/poc.tcl for the full contract description).

        Talks to Vivado's native Tcl API (add_files, get_files, set_property,
        get_property, current_fileset, current_project) so that `::poc::synth`
        never has to know it is running under Vivado.

        Normally you never source this file yourself — `::poc::synth`
        auto-detects Vivado and sources it on first use. It is still a plain
        backend file and can be sourced manually (registerBackend must exist
        first, i.e. after tools/poc.tcl) if you ever need to force this
        backend.

        ## Usage

            source <pocRoot>/tools/poc.tcl                  ;# registerBackend must exist first
            source <pocRoot>/tools/Vivado/poc_vivado.tcl     ;# self-registers
    }

    # Constraint files always land in Vivado's default constraints fileset,
    # regardless of the -fileset the caller targeted for VHDL sources — this
    # mirrors Vivado project conventions (one constrs_* fileset per project).
    variable constraintsFileset "constrs_1"

    # This directory, captured at source time (info script only reliably
    # names the currently-sourcing file, not whatever calls a proc later).
    # Used to locate sibling hook scripts such as
    # preSynth_GitVersionRegister_Vivado.tcl.
    variable backendDir [file normalize [file dirname [info script]]]

    # Full core key that triggers the GitVersionRegister pre-synthesis hook.
    variable gitVersionRegisterCore "PoC.bus.axi4lite.GitVersionRegister"

    proc addSourceFile {fp fileset lib fileType} {
        # Add one VHDL source to a fileset and set its library and file_type.
        # fp - absolute path of the source file
        # fileset - Vivado fileset to add it to
        # lib - VHDL library to assign
        # fileType - Vivado file_type value, e.g. "VHDL 2008"
        add_files -norecurse -fileset $fileset $fp
        set fobj [get_files $fp]
        set_property library   $lib      $fobj
        set_property file_type $fileType $fobj
    }

    proc addConstraintFile {fp fileset} {
        # Add one XDC constraint file. Always targets the constraintsFileset
        # (see the namespace variable of the same name), regardless of
        # fileset. Scoping (SCOPED_TO_REF) and any other properties arrive
        # afterward via `setAttribute` — this proc only files the source.
        # fp - absolute path of the constraint file
        # fileset - ignored; kept only to satisfy the backend contract signature
        variable constraintsFileset
        add_files -norecurse -fileset $constraintsFileset $fp
    }

    proc setAttribute {fp name value} {
        # Apply one arbitrary Vivado property to an already-added file.
        # fp - absolute path of the file
        # name - Vivado property name
        # value - value to assign
        set_property $name $value [get_files $fp]
    }

    proc vhdlFileType {version} {
        # Map a YAML vhdlVersion value to the Vivado file_type string.
        # version - VHDL version, e.g. 2008; 87 and 93 both map to bare
        #  "VHDL" since Vivado has no separate 87/93 file_type.
        switch -- $version {
            87 - 93 { return "VHDL" }
            default { return "VHDL $version" }
        }
    }

    proc defaultFileType {} {
        # Vivado file_type string used when a source entry has no
        # vhdlVersion. Must be a valid Vivado file_type value: "VHDL",
        # "VHDL 2008", "VHDL 2019".
        return "VHDL 2008"
    }

    proc defaultFileset {} {
        # Return the currently active fileset, used when poc_Add is called
        # without -fileset.
        return [current_fileset]
    }

    proc isInProject {fp} {
        # Return 1 if the normalised file path is already in the current
        # project.
        # fp - path to check
        return [expr {[get_files -quiet [file normalize $fp]] ne ""}]
    }

    proc hasProjectFile {namePattern} {
        # Return 1 if a file whose name matches the glob pattern is already
        # part of the current project.
        # namePattern - glob pattern matched against each file's NAME property
        return [expr {[get_files -quiet -filter "NAME =~ ${namePattern}"] ne ""}]
    }

    proc getProjectFilePath {namePattern} {
        # Return the absolute on-disk path Vivado has recorded for the
        # first file whose name matches the glob pattern, or "" if no such
        # file is part of the current project.
        # namePattern - glob pattern matched against each file's NAME property
        #
        # Used to recover the real file-set path of an already-added file
        # (e.g. local_configuration.vhdl) so callers can check whether it
        # still exists on disk -- Vivado's project only remembers the path
        # it was added from, it does not verify the file is still there.
        set files [get_files -quiet -filter "NAME =~ ${namePattern}"]
        if {$files eq ""} { return "" }
        return [file normalize [lindex $files 0]]
    }

    proc projectRoot {} {
        # Return the absolute path one level above the Vivado project
        # directory — the PoC convention for the consuming project's root
        # (where src/PoC/ is created).
        set prjDir [get_property DIRECTORY [current_project]]
        return [file normalize [file join $prjDir ".."]]
    }

    proc partHint {} {
        # Return the current Vivado project's target part, or "" if
        # unavailable.
        if {[catch {set part [get_property PART [current_project]]} err] == 0 \
                && $part ne ""} {
            return $part
        }
        return ""
    }

    proc defaultDependenciesFile {} {
        # Return Vivado's generated YAML dependency file, next to this
        # backend file. Generated by graphml2yml.py — see that script for
        # how it is built.
        variable backendDir
        return [file join $backendDir "dependency_Vivado.yml"]
    }

    proc onCoreAdded {coreName} {
        # Optional `::poc::synth` hook (see tools/poc.tcl). Reacts to one
        # specific, known core: axi4lite_GitVersionRegister needs a
        # companion pre-synthesis Tcl script
        # (preSynth_GitVersionRegister_Vivado.tcl, next to this file)
        # registered on the project's synthesis run so it can generate
        # temp/GitVersion.mem before synthesis starts.
        # coreName - full core key just added, e.g. PoC.bus.axi4lite.GitVersionRegister
        #
        # Registration is skipped — with printed instructions instead — in
        # the two cases where auto-wiring would be ambiguous or destructive:
        #   - more than one synthesis run exists (which one is "the" run?)
        #   - the run already has a pre-synthesis Tcl script registered
        #     (never clobber something the user already wired up)
        variable gitVersionRegisterCore
        if {$coreName ne $gitVersionRegisterCore} { return }
        _registerGitVersionPreSynthHook
    }

    proc _registerGitVersionPreSynthHook {} {
        # Register preSynth_GitVersionRegister_Vivado.tcl as the
        # pre-synthesis Tcl hook on the project's single synthesis run, if
        # unambiguous and not already occupied. See `onCoreAdded`.
        variable backendDir

        set hookScript [file join $backendDir "preSynth_GitVersionRegister_Vivado.tcl"]
        set prefix     $::poc::synth::prefix

        set synthRuns [get_runs -filter {IS_SYNTHESIS == 1}]
        if {[llength $synthRuns] != 1} {
            puts "${prefix}axi4lite_GitVersionRegister added, but found [llength $synthRuns] synthesis run(s) — not auto-registering the pre-synthesis hook (ambiguous which run to use)."
            puts "${prefix}  To register it yourself on the run you want:"
            puts "${prefix}    set_property STEPS.SYNTH_DESIGN.TCL.PRE {$hookScript} \[get_runs <synth_run_name>\]"
            return
        }

        set synthRun [lindex $synthRuns 0]
        set existing [get_property STEPS.SYNTH_DESIGN.TCL.PRE $synthRun]
        if {$existing ne ""} {
            puts "${prefix}axi4lite_GitVersionRegister added, but run '$synthRun' already has a pre-synthesis Tcl script registered:"
            puts "${prefix}    $existing"
            puts "${prefix}  Not overwriting it. To also run the PoC GitVersionRegister hook, add this line to that script instead:"
            puts "${prefix}    source {$hookScript}"
            return
        }

        set_property STEPS.SYNTH_DESIGN.TCL.PRE $hookScript $synthRun
        puts "${prefix}axi4lite_GitVersionRegister added — registered pre-synthesis hook on run '$synthRun':"
        puts "${prefix}    $hookScript"
    }
}

::poc::synth::registerBackend ::poc::synth::backend::vivado "Vivado"
