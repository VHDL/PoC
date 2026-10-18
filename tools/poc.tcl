## =============================================================================
## Authors:
##   Jonas Schreiner
##   Stefan Unrein
##   Patrick Lehmann
##   Adrian Weiland
##
## Script:          poc.tcl
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
## each proc body (Ruff! reads them via [info body]), and each namespace's
## own overview lives in its _ruff_preamble variable, not in this header.
## Generate the reference HTML with:
##   tclsh ruff.tcl document -r -e "source tools/poc.tcl" -d docs/ -s html \
##       --exclude-procs {^_} ::poc::OSVVM ::regression ::poc::synth ::version

## =============================================================================
## ::poc -- general PoC Namespace
## =============================================================================
namespace eval ::poc {
	variable _ruff_preamble {
		General PoC Namespace with currently only variables.
	}

	proc getEnv {var {default ""}} {
		# Return environment variable var, or default if unset.
		# var - name of the environment variable
		# default - value to return if var is not set
		if {[info exists ::env($var)]} {
			return $::env($var)
		}
		return $default
	}

	variable vendorName [getEnv VENDOR "GENERIC"]
	variable boardName  [getEnv BOARD  "GENERIC"]

	namespace export getEnv
}

## =============================================================================
## ::poc::OSVVM -- simulation helpers
## =============================================================================
namespace eval ::poc::OSVVM {
	variable _ruff_preamble {
		Simulation-regression helpers used by regression.tcl: configuration,
		build-error/run-error checking, and OSVVM *.pro-file helpers
		(`disabled`/`duplicate`). See regression.tcl for the actual
		build-step orchestration.

		These procs don't depend on any EDA tool -- only on OSVVM being
		loaded first, which regression.tcl already does via
		`OSVVM-Scripts/StartUp.tcl` before sourcing tools/poc.tcl. If OSVVM
		isn't loaded (e.g. this file sourced under Vivado instead), the
		OSVVM-dependent setup is skipped rather than erroring -- the procs
		still exist, they just have nothing to configure.

		## Usage

			source OSVVM-Scripts/StartUp.tcl   ;# must come first -- ::osvvm must exist
			source <pocRoot>/tools/poc.tcl
			namespace import ::poc::OSVVM::*
			namespace import ::regression::*

			configurePoC -P <root>             ;# set project folder root for poc scripting
			configureOSVVM -stop 1             ;# configure OSVVM stop counts / debug / waves
	}

	variable prefix   "\[PoC\]        "
	variable prefixNs "\[PoC\] "

	variable projectRoot "."
	variable buildNamePrefix ""

	# Relative to the location of src/build.pro
	variable localConfigurationFolder "tb/common"
	variable projectConfigurationFile "$localConfigurationFolder/project_configuration_${::poc::boardName}.vhdl"
	variable projectConfigurationPath "$projectRoot/$localConfigurationFolder/project_configuration.vhdl"
	variable localConfigurationFile   "$localConfigurationFolder/local_configuration.vhdl"
	variable localConfigurationPath   "$projectRoot/$localConfigurationFolder/local_configuration.vhdl"

	# All of the following depends on OSVVM's ::osvvm namespace already
	# existing (regression.tcl sources OSVVM-Scripts/StartUp.tcl before this
	# file). Skipped entirely when it isn't loaded -- e.g. this file sourced
	# under Vivado, which never touches OSVVM -- rather than erroring.
	if {[info exists ::osvvm::ToolName]} {
		# Skip report generation if executed within Sigasi/VS Code
		if {[info exists ::env(OSVVM_TOOL)] && $::env(OSVVM_TOOL) eq "Sigasi"} {
			set ::osvvm::GenerateOsvvmReports "false"
		}
		if {[info exists ::env(GITLAB_CI)]} {
			if {[info exists ::env(GHDL_BACKEND)]} {
				set buildNamePrefix "${::osvvm::ToolName}-$::env(GHDL_BACKEND)-"
			} else {
				set buildNamePrefix "${::osvvm::ToolName}-"
			}

			# WORKAROUND for Riviera-PRO: tcl_interactive is always 1 (even on CI server)
			if {$::osvvm::ToolName eq "RivieraPRO"} {
				global tcl_interactive
				set tcl_interactive 0
			}

		} elseif {[info exists ::env(GITHUB_ACTIONS)]} {
			set buildNamePrefix ""
		} else {
			set buildNamePrefix "${::osvvm::ToolNameVersion}-"
		}
	}

	proc exitScript {{code 1}} {
		# Exit the interpreter with code, unless running interactively.
		# code - exit code to use (default 1)
		global tcl_interactive
		if {$tcl_interactive == 1} {
			return
		}
		set toolsWithDashCode {ActiveHDL ModelSim NVC QuestaSim RivieraPRO}

		if {[lsearch -exact $toolsWithDashCode $::osvvm::ToolName] >= 0} {
			# noqa: E003
			exit -code $code
		} else {
			exit $code
		}
	}

	proc configureOSVVM {args} {
		# Configure OSVVM stop counts, debug mode, and simulator-specific
		# extended options for the currently detected simulator.
		# args - option/value pairs; recognises -stop/-s, -debug/-d, -waves/-w
		set stopCount 0
		set debugMode 0

		set i 0
		while {$i < [llength $args]} {
			set arg [lindex $args $i]
			switch -glob -- $arg {
				"-stop" -
				"-s" {
					incr i
					if {$i < [llength $args]} {
						set stopCount [lindex $args $i]
					} else {
						puts "${::poc::OSVVM::prefix}Option -stopCount requires an integer value."
						exitScript
					}
				}
				"-debug" -
				"-d" {
					set debugMode 1
				}
				"-waves" -
				"-w" {
					SetSaveWaves
				}
				default {
					puts "${::poc::OSVVM::prefix}ERROR: Unknown option $arg"
					exitScript
				}
			}
			incr i
		}

		set ::osvvm::AnalyzeErrorStopCount  $stopCount
		set ::osvvm::SimulateErrorStopCount $stopCount
		set ::osvvm::TclDebug               $debugMode
		set ::osvvm::FailOnBuildErrors      $debugMode

		if {$::osvvm::ToolName eq "GHDL"} {
			SetExtendedAnalyzeOptions  {-frelaxed -Wno-specs -Wno-elaboration}
			SetExtendedSimulateOptions {-frelaxed -Wno-specs -Wno-binding}

		} elseif {$::osvvm::ToolName eq "RivieraPRO"} {
			set RivieraSimOptions {-unbounderror}

		} elseif {$::osvvm::ToolName eq "NVC"} {
			append ::osvvm::ExtendedGlobalOptions " --ignore-time"
			SetExtendedAnalyzeOptions {--relaxed}

		} elseif {$::osvvm::ToolName eq "Sigasi"} {

		} else {
			puts [format {
${::poc::OSVVM::prefix}======================================
${::poc::OSVVM::prefix}Unknown simulator selected: %s
${::poc::OSVVM::prefix}
${::poc::OSVVM::prefix}Supported simulators:
${::poc::OSVVM::prefix}  - GHDL
${::poc::OSVVM::prefix}  - NVC
${::poc::OSVVM::prefix}  - Riviera-PRO
${::poc::OSVVM::prefix}Other tools:
${::poc::OSVVM::prefix}  - Sigasi in VSCode
${::poc::OSVVM::prefix}======================================
} $::osvvm::ToolName]
			exitScript
		}
	}

	proc configurePoC {args} {
		# Configure vendor/board/project-root/config-file-path settings for
		# PoC scripting.
		# args - option/value pairs; recognises -vendor/-v, -board/-b,
		#  -projectRoot/-P, -projectFile/-p, -configFile/-c
		set i 0
		while {$i < [llength $args]} {
			set arg [lindex $args $i]

			switch -glob -- $arg {
				"-vendor" -
				"-v" {
					incr i
					if {$i < [llength $args]} {
						set ::poc::vendorName [lindex $args $i]
					}
				}

				"-board" -
				"-b" {
					incr i
					if {$i < [llength $args]} {
						set ::poc::boardName [lindex $args $i]
					}
				}

				"-projectRoot" -
				"-P" {
					incr i
					if {$i < [llength $args]} {
						set ::poc::OSVVM::projectRoot [lindex $args $i]
					}
                    set ::poc::OSVVM::projectConfigurationPath "$::poc::OSVVM::projectRoot/$::poc::OSVVM::projectConfigurationFile"
                    set ::poc::OSVVM::localConfigurationPath   "$::poc::OSVVM::projectRoot/$::poc::OSVVM::localConfigurationFile"
				}

				"-projectFile" -
				"-p" {
					incr i
					if {$i < [llength $args]} {
						set ::poc::OSVVM::localConfigurationFile [lindex $args $i]
		                set ::poc::OSVVM::localConfigurationPath   "$::poc::OSVVM::projectRoot/$::poc::OSVVM::localConfigurationFile"
					}
				}

				"-configFile" -
				"-c" {
					incr i
					if {$i < [llength $args]} {
						set ::poc::OSVVM::projectConfigurationFile [lindex $args $i]
	                    set ::poc::OSVVM::projectConfigurationPath "$::poc::OSVVM::projectRoot/$::poc::OSVVM::projectConfigurationFile"
					}
				}

				default {
					puts "${::poc::OSVVM::prefix}ERROR: Unknown option $arg"
					exitScript
				}
			}
			incr i
		}

		puts "${::poc::OSVVM::prefix}Relative to project root:"
		puts "${::poc::OSVVM::prefix}  projectConfigurationFile is '$::poc::OSVVM::projectConfigurationFile'"
		puts "${::poc::OSVVM::prefix}  localConfigurationFile is '$::poc::OSVVM::localConfigurationFile'"
        set ::poc::OSVVM::projectConfigurationPath [file normalize $::poc::OSVVM::projectConfigurationPath]
        set ::poc::OSVVM::localConfigurationPath   [file normalize $::poc::OSVVM::localConfigurationPath]
		puts "${::poc::OSVVM::prefix}  projectConfigurationPath is '$::poc::OSVVM::projectConfigurationPath'"
		puts "${::poc::OSVVM::prefix}  localConfigurationPath is '$::poc::OSVVM::localConfigurationPath'"

	}

	proc WriteLocalConfiguration {} {
		# Generate src/<localConfigurationFile> with LOCAL_PROJECT_DIR set to
		# the current projectRoot.
		puts "${::poc::OSVVM::prefix}Generate local configuration in '$::poc::OSVVM::localConfigurationPath'"
		set content "package local_configuration is\n"
		append content "\tconstant LOCAL_PROJECT_DIR : string := \"$::poc::OSVVM::projectRoot\";\n"
		append content "end package;\n"

		set fileHandle [open "$::poc::OSVVM::localConfigurationPath" "w"]
		puts -nonewline $fileHandle $content
		close $fileHandle
	}

	proc checkForBuildErrors {} {
		# Print and act on any OSVVM analyze errors from the last build.
		# Returns 1 and exits (unless interactive) if there were errors, else 0.
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "${::poc::OSVVM::prefix}ERROR: While building $::osvvm::LastBuildName"
			puts "${::poc::OSVVM::prefix}====================================="
			puts "${::poc::OSVVM::prefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::OSVVM::prefix}====================================="

			exitScript
			return 1
		}
		return 0
	}

	proc checkForRunErrors {} {
		# Print and act on any OSVVM analyze or simulate errors from the last
		# run. Returns 1 and exits (unless interactive) if there were errors,
		# else 0.
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "${::poc::OSVVM::prefix}ERROR: While building $::osvvm::LastBuildName"
			puts "${::poc::OSVVM::prefix}====================================="
			puts "${::poc::OSVVM::prefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::OSVVM::prefix}====================================="

			exitScript 2
			return 1
		} elseif {$::osvvm::SimulateErrorCount > 0} {
			puts "${::poc::OSVVM::prefix}ERROR: While simulating $::osvvm::TestCaseName"
			puts "${::poc::OSVVM::prefix}====================================="
			puts "${::poc::OSVVM::prefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::OSVVM::prefix}====================================="
			exitScript 3
			return 1
		}
		return 0
	}

	# New procedures for OSVVM's *.pro files
	proc disabled {args} {
		# Print a "disabled from analysis" notice for an OSVVM *.pro file entry.
		# args - the disabled file/arguments, printed as-is
		puts "${::poc::OSVVM::prefixNs}Disabled from analysis: $args"
	}
	proc duplicate {args} {
		# Print a "duplicate file" notice for an OSVVM *.pro file entry.
		# args - the duplicate file/arguments, printed as-is
		puts "${::poc::OSVVM::prefixNs}Duplicate file: $args"
	}
	proc ConstraintFile {args} {
		# Dummy for future use
	}
	proc ScopeToRef {args} {
		# Dummy for future use
	}
	proc ScopeToCell {args} {
		# Dummy for future use
	}

	namespace export exitScript configureOSVVM configurePoC \
	                  WriteLocalConfiguration checkForBuildErrors \
	                  checkForRunErrors disabled duplicate ConstraintFile\
	                  ScopeToRef ScopeToCell
}

puts "${::poc::OSVVM::prefix}Loaded tools/poc.tcl ::poc::OSVVM namespace (simulation helpers)."

namespace eval ::regression {
	variable _ruff_preamble {
		Build-step level/argument resolution helpers used by regression.tcl
		to decide which of the `clean`/`all`/`osvvm`/`poc`/`test` steps to
		run, from interactive `argv`, or the `REGRESSION_STEP`/
		`REGRESSION_FROM` environment variables.
	}

	variable putsPrefix "\[Regression\] "

	proc createRegressionLevels {args} {
		# Build a step-name -> level-number map from an ordered step-name list.
		# args - step names in the order they should run, e.g. osvvm poc test
		#
		# "clean" always maps to -1 and "all" always maps to 0, regardless of
		# whether they're passed in args.
		set map(clean) -1
		set map(all) 0

		set i 0
		foreach level $args {
			set map($level) $i
			incr i
		}

		return [array get map]
	}

	proc mapRegressionLevel {step levelMap} {
		# Resolve a step name (or already-numeric level) to its level number.
		# step - step name, or an integer level
		# levelMap - map as returned by createRegressionLevels
		#
		# Returns 0 (the "all" level) with a warning if step is an unknown name.
		if {[string is integer -strict $step]} {
			return $step
		}

		array set map $levelMap

		if {[info exists map($step)]} {
			return $map($step)
		}

		puts "${::regression::putsPrefix}\[WARNING\] Unknown build level '$step', using 'all'."
		return 0
	}

	proc evaluateRegressionLevel {defaultStep regressionLevels} {
		# Resolve the step to build from (in priority order) interactive
		# argv, the REGRESSION_STEP env var, the REGRESSION_FROM env var, or
		# defaultStep, and set ::regression::level and
		# ::regression::executeSingleStep accordingly.
		# defaultStep - step name to use if nothing else specifies one
		# regressionLevels - map as returned by createRegressionLevels
		set ::regression::executeSingleStep 0
		if {[info exists ::env(REGRESSION_STEP)]} {
			set ::regression::executeSingleStep 1  ; # return after selected step
		}

		# 1. argv (when used interactively)
		if {[info exists ::argv] && [llength $::argv] > 0} {
			set buildConfigSource "interactive"
			set selectedStep [lindex $::argv 0]

		# 2. Check for environment variables
		} elseif {[info exists ::env(REGRESSION_STEP)]} {
			set buildConfigSource "environment variable"
			set selectedStep $::env(REGRESSION_STEP)

		} elseif {[info exists ::env(REGRESSION_FROM)]} {
			set buildConfigSource "environment variable"
			set selectedStep $::env(REGRESSION_FROM)

		} else {
			set buildConfigSource "default"
			set selectedStep $defaultStep
			puts "${::regression::putsPrefix}\[REGRESSION INFO\] Undefined or unknown argument, using default settings."
		}
		set ::regression::level [mapRegressionLevel $selectedStep $regressionLevels]

		# 3. output result
		puts "${::regression::putsPrefix}Build configuration"
		puts "${::regression::putsPrefix}  Level: $::regression::level (set by $buildConfigSource)"
		puts "${::regression::putsPrefix}  Executing [expr {$::regression::executeSingleStep ? "only" : "starting from"}] step '$selectedStep'"
	}

	namespace export createRegressionLevels
	namespace export evaluateRegressionLevel
}

puts "${::regression::putsPrefix}Loaded tools/poc.tcl regression namespace."

## =============================================================================
## ::poc::synth -- synthesis engine (IP-core dependency resolution)
## =============================================================================
namespace eval ::poc::synth {
	variable _ruff_preamble {
		Tool-agnostic engine for importing PoC IP cores into an EDA tool
		project. Loads the YAML dependency file, resolves IP core names,
		walks the dependency graph, and exposes the public `poc_*` API. All
		tool-specific actions (adding a source file, adding a constraint
		file, querying the current project, ...) are delegated to a
		"backend" namespace registered via `registerBackend`.

		This namespace auto-detects which EDA tool it is running under (by
		matching against `info nameofexecutable`) and sources the matching
		backend file itself, the first time a backend is actually needed
		(e.g. Vivado -> tools/Vivado/poc_vivado.tcl).

		Manual registration still works and always wins over auto-detection:
		source a backend file and call `registerBackend` yourself before
		`poc_Init`/`poc_Add` -- this is how tests/benchmarks plug in the
		in-memory dummy backend instead of a real tool.

		## Backend contract

		A backend is a namespace (e.g. `::poc::synth::backend::vivado`) that
		calls `registerBackend` *namespace displayName* once, after having
		defined the following procs inside that namespace:

		### addSourceFile {fp fileset lib fileType}

		Add one HDL source file to the given fileset/library/file-type.

		### addConstraintFile {fp fileset}

		Add one constraint file to the given fileset. Any scoping (e.g.
		Vivado's SCOPED_TO_REF) arrives afterward as a plain attribute via
		`setAttribute` -- it is not a special case of this contract.

		### setAttribute {fp name value}

		Apply one arbitrary property to an already-added file (Vivado:
		`set_property $name $value [get_files $fp]`). Used for whatever a
		source entry's optional "attributes" map declares, e.g.
		SCOPED_TO_REF on an XDCConstraintFile entry. Backends that don't
		recognise a given name may ignore it.

		### vhdlFileType {version}

		Map a YAML vhdlVersion value (e.g. 2008) to the tool's file_type
		token.

		### defaultFileType {}

		Return the tool's default HDL file_type token (used when a source
		entry has no explicit vhdlVersion).

		### defaultFileset {}

		Return the tool's notion of "the current/default fileset" to use
		when `poc_Add` is called without -fileset.

		### isInProject {fp}

		Return 1 if the normalised file path is already part of the project.

		### hasProjectFile {namePattern}

		Return 1 if a file whose name matches the glob pattern is already
		part of the project (used to detect existing configuration files).

		### getProjectFilePath {namePattern}

		Return the absolute on-disk path recorded for the first file whose
		name matches the glob pattern, or "" if no such file is part of the
		project. Used to recover the real path of a file that
		`hasProjectFile` reports as present, so it can be checked for actual
		existence on disk -- a project's file-set can reference a file that
		has since been deleted from disk, e.g. after a fresh checkout that
		didn't restore an untracked generated configuration file.

		### projectRoot {}

		Return the absolute path of the consuming project's root directory
		(the directory under which src/PoC/ is created for generated
		configuration files).

		### partHint {}

		Return the currently targeted device/part string, or "" if unknown
		or not applicable to the tool.

		### defaultDependenciesFile {}

		Return the absolute path of this backend's generated YAML dependency
		file (e.g. Vivado: `<pocRoot>/tools/Vivado/dependency_Vivado.yml`).
		Used by `poc_Init` when called without an explicit depsFile -- each
		backend owns its own generated file, so this namespace itself never
		hardcodes a filename or location for any particular tool.

		### onCoreAdded {coreName} (optional)

		`poc_Add` calls this only if the backend namespace defines it, so
		most backends can ignore it entirely. Called once per core (full
		key, e.g. PoC.bus.axi4lite.axi4lite_...) right after its files and
		attributes have been added, whether it was the requested core or
		pulled in transitively. Lets a backend react to specific, known
		cores needing extra tool-specific project wiring (e.g. registering a
		pre-synthesis Tcl hook) without this engine having to know that core
		exists.

		## YAML dependency file format

		Per-backend filename, e.g. Vivado's
		tools/Vivado/dependency_Vivado.yml -- see defaultDependenciesFile
		above.

			version: "1.3"
			dependencies:

			  PoC.namespace.core_name:
			    kind: VHDLSourceFile        # VHDLSourceFile | XDCConstraintFile
			    sources:
			      - file: src/path/to/file.vhdl
			        vhdlVersion: 2008        # optional; omit to use the backend default
			        attributes:              # optional map, applied via set_property
			          SomeProperty: value    # (or tool equivalent) after the file is added
			    dependsOn:
			      - PoC.other.core           # may itself be an XDCConstraintFile entry

		version lives at the document root, ahead of (and outside) the
		dependencies: map -- not nested inside it.

		vhdlVersion, attributes and dependsOn are all optional and simply
		omitted from the YAML when not applicable (see graphml2yml.py's
		write_yml), rather than written as ~. `poc_Add` treats an absent key
		as "use the default" via a portable huddle-keys-based existence
		check (`_hasKey`) -- not "huddle exists", which is not available in
		every huddle build this tooling has to run against.

		Constraint files are ordinary entries too (kind: XDCConstraintFile)
		-- there is no separate "constraints:" key any more. A VHDL core
		that needs a scoped constraint file lists it in dependsOn, e.g.:

			PoC.sync.sync_Command:
			  kind: VHDLSourceFile
			  sources:
			    - file: src/sync/sync_Command.vhdl
			  dependsOn:
			    - PoC.sync.sync_Command.xdc

			PoC.sync.sync_Command.xdc:
			  kind: XDCConstraintFile
			  sources:
			    - file: ucf/sync/sync_Command.xdc
			      attributes:
			        SCOPED_TO_REF: sync_Command

		dependsOn may be omitted entirely (as above), or given as ~ (null)
		or an empty list -- all three mean "no dependencies".
		graphml2yml.py omits it; hand-written overrides may use whichever
		reads best.

		## Usage

			source <pocRoot>/tools/poc.tcl
			namespace import ::poc::synth::*

			poc_Init                           ;# loads backend's default deps file, library = PoC
			poc_Init /path/to/deps.yml MyLib   ;# explicit file and library override
			poc_Add ic_got                     ;# add one IP core and all its dependencies
			poc_Add fifo_ic_got                ;# same core, resolved by its original filename too
			poc_Add fifo                       ;# namespace match: lists all PoC.fifo.*
			poc_Add ic                         ;# prefix match: lists all ic* cores
			poc_Add ic_got -force              ;# re-add even if already present
			poc_Add ic_got -fileset sim_1      ;# target a specific fileset
			poc_ListIPs                        ;# list all known IP cores
			poc_ListIPs fifo                   ;# list all cores in the fifo namespace
			poc_ListIPs "ic_*"                 ;# list with glob pattern
			poc_Help                           ;# print this command overview

		Dispatcher shorthand (after namespace import):

			poc init                           ;# same as poc_Init
			poc add ic_got                     ;# same as poc_Add
			poc list fifo                      ;# same as poc_ListIPs fifo
			poc help                           ;# same as poc_Help
	}

    variable prefix          "\[PoC\] "
    variable scriptVersion   "1.3"

    # Derived from this script's own path: tools/poc.tcl -> ..
    variable pocRoot         [file normalize [file join [file dirname [info script]] ".."]]

    # This file's own directory (tools/), used to auto-locate backend files
    # by tool, e.g. <toolsDir>/Vivado/poc_vivado.tcl. Captured at source time
    # — [info script] only reliably names the currently-sourcing file here,
    # not whatever calls a proc later.
    variable toolsDir        [file dirname [info script]]

    # Default VHDL library assigned to every source file.
    # Overridable via poc_Init -library <name>.
    variable defaultLibrary  "PoC"

    # Huddle mapping node for the "dependencies" key from the loaded YAML
    # dependency file. Set by poc_Init; all other procs read from this variable.
    variable dependencies    {}

    # Active backend: namespace + human-readable name, set via registerBackend
    # (either by auto-detection or by a manual pre-registration).
    variable backendNs       ""
    variable backendName     ""

    # Traversal state, reset before each poc_Add call
    variable _visited        {}
    variable _order          {}

    proc registerBackend {ns {displayName ""}} {
        # Register the active backend namespace and update the log prefix.
        # ns - backend namespace, e.g. ::poc::synth::backend::vivado
        # displayName - human-readable tool name, e.g. "Vivado"; defaults to ns
        #
        # Called once by a tool-specific backend file after defining its
        # procs. The log prefix becomes e.g. "PoC::Vivado".
        variable backendNs
        variable backendName
        variable prefix

        set backendNs   $ns
        set backendName [expr {$displayName ne "" ? $displayName : $ns}]
        set prefix      "\[PoC::${backendName}\] "

        puts "${prefix}Backend registered: $backendName ($ns)"
    }

    proc _detectBackendFile {} {
        # Identify the running EDA tool from the interpreter's own
        # executable path and return the backend file to source for it, or
        # "" if no supported tool is detected.
        #
        # Uses `info nameofexecutable` rather than probing for tool-specific
        # Tcl commands (e.g. Vivado's current_project/get_property) or
        # calling a tool-specific command like Vivado's `version`: both
        # approaches depend on that command actually being defined in the
        # running build, which isn't guaranteed. `info nameofexecutable` is
        # a core Tcl command, always present, so this needs no catch around
        # it.
        #
        # Add further tools here as backends are implemented (Quartus,
        # Lattice Diamond, ...) -- each just needs a distinctive substring
        # of its own executable path to match on.
        variable toolsDir

        set exe [string tolower [info nameofexecutable]]

        if {[string match "*vivado*" $exe]} {
            return [file join $toolsDir "Vivado" "poc_vivado.tcl"]
        }

        # Quartus, Lattice Diamond, ... — not implemented yet.

        return ""
    }

    proc _backend {} {
        # Return the active backend namespace, auto-detecting and loading
        # one if none has been registered yet.
        #
        # If none has been registered, auto-detect the running EDA tool and
        # source its backend file, which self-registers via registerBackend.
        # Errors out with a clear message if detection fails or the
        # detected tool has no backend yet.
        #
        # Manual registration (source a backend + call registerBackend
        # yourself before poc_Init/poc_Add) always takes precedence over
        # auto-detection -- this is how tests/benchmarks plug in the
        # in-memory dummy backend.
        variable backendNs
        variable prefix

        if {$backendNs eq ""} {
            set backendFile [_detectBackendFile]
            if {$backendFile eq ""} {
                error "${prefix}No supported EDA tool detected in this Tcl\
                       interpreter — no backend available. Currently\
                       supported: Vivado. To use a backend manually (e.g. for\
                       testing), source it and call ::poc::synth::registerBackend\
                       before calling poc_Init/poc_Add."
            }
            source -quiet $backendFile
        }

        if {$backendNs eq ""} {
            error "${prefix}Backend file '$backendFile' did not register\
                   itself via ::poc::synth::registerBackend"
        }

        return $backendNs
    }

    proc _addSource {fp fileset lib fileType} {
        # Thin indirection to the active backend's addSourceFile.
        # fp - absolute path of the source file
        # fileset - target fileset
        # lib - VHDL library to assign
        # fileType - backend-specific file_type token
        [_backend]::addSourceFile $fp $fileset $lib $fileType
    }

    proc _relpath {base target} {
        # Return the shortest relative path from base to target.
        # base - absolute base path (normalised if not already)
        # target - absolute target path (normalised if not already)
        #
        # Uses only Tcl built-ins -- no tcllib dependency.
        set base   [file split [file normalize $base]]
        set target [file split [file normalize $target]]

        # Strip common prefix
        set i 0
        while {$i < [llength $base] && $i < [llength $target] &&
               [lindex $base $i] eq [lindex $target $i]} { incr i }

        set rel {}
        for {set j $i} {$j < [llength $base]}   {incr j} { lappend rel ".." }
        for {set j $i} {$j < [llength $target]} {incr j} { lappend rel [lindex $target $j] }

        if {[llength $rel] == 0} { return "." }
        return [file join {*}$rel]
    }

    proc _tag {node} {
        # Return a huddle node's raw YAML tag (e.g. "!!str", "!!seq", "!!map").
        # node - a huddle node
        #
        # Indexes directly into its on-the-wire {HUDDLE {tag value}} list
        # form, rather than going through any huddle command.
        #
        # Deliberately does NOT use huddle's own `unwrap` (which does
        # exactly this): unwrap is a documented, exported subcommand, but is
        # still not present in every observed tcllib build -- huddle 0.1.3
        # (bundled with Vivado releases before 2025.1) raises "invalid
        # command name ::huddle::unwrap" for it. The wire *format* is the
        # one thing that has held constant across every version seen so far
        # (0.1.3 through 0.4), so depending on that shape directly is more
        # portable here than depending on any accessor command, public or
        # not -- commands can be added/renamed/dropped between releases;
        # the tag is part of the YAML 1.1 core schema huddle merely stores,
        # not something it can rename.
        return [lindex [lindex $node 1] 0]
    }

    proc _val {node} {
        # Return a huddle node's raw scalar value.
        # node - a huddle scalar leaf node (never a mapping or sequence)
        #
        # Uses the same on-the-wire indexing as _tag.
        return [lindex [lindex $node 1] 1]
    }

    proc _stripped {node key} {
        # Portable equivalent of "huddle get_stripped $node $key".
        # node - a huddle mapping node
        # key - key to look up in node
        #
        # Gets the child node then unwraps it to a plain Tcl scalar. Does
        # NOT call huddle's own get_stripped -- huddle 0.1.3 (see _tag)
        # doesn't implement it at all ("invalid command name
        # ::huddle::get_stripped").
        return [_val [huddle get $node $key]]
    }

    proc _isSeq {node} {
        # Return 1 if node is a huddle sequence.
        # node - a huddle node
        #
        # Portable replacement for "huddle type $node eq sequence" -- the
        # friendly type name returned by huddle's own `type` command is NOT
        # stable across tcllib versions: huddle 0.4 (this repo's dev
        # tcllib) returns "sequence"/"mapping", but huddle 0.1.3 (bundled
        # with Vivado releases before 2025.1) returns the Tcl superclass
        # name "list"/"dict" instead -- silently breaking every "eq
        # sequence"/"eq mapping" check (poc_Add would then skip every
        # core's sources without erroring). The raw tag (see _tag) is
        # stable across both.
        return [expr {[_tag $node] eq "!!seq"}]
    }
    proc _isMap {node} {
        # Return 1 if node is a huddle mapping. See _isSeq for why this
        # doesn't use huddle's own `type` command.
        # node - a huddle node
        return [expr {[_tag $node] eq "!!map"}]
    }
    proc _isNull {node} {
        # Return 1 if node is an explicit YAML "~", as opposed to a real
        # value. Used together with _hasKey so a present-but-null field and
        # an absent field are both treated as "no value, use the default".
        # node - a huddle node
        return [expr {[_tag $node] eq "!!null"}]
    }

    proc _hasKey {node key} {
        # Return 1 if mapping node has key.
        # node - a huddle mapping node
        # key - key to check for
        #
        # Portable replacement for "huddle exists $node $key" -- huddle
        # 0.1.3 (see _tag) doesn't implement `exists` at all ("invalid
        # command name ::huddle::exists"). Built on `huddle keys`, which --
        # unlike type, get_stripped, unwrap and exists -- has been
        # confirmed to behave identically on both 0.1.3 and 0.4.
        #
        # Optional YAML fields (vhdlVersion, attributes, dependsOn) are
        # simply omitted from the generated file rather than written as ~
        # (see graphml2yml.py), so poc_Add checks this before reading them,
        # falling back to a default when absent instead of erroring.
        return [expr {[lsearch -exact [huddle keys $node] $key] >= 0}]
    }

    proc _coreNames {} {
        # Return a plain Tcl list of all core names from the loaded
        # dependencies huddle mapping.
        #
        # version lives at the document root (see _loadYaml), not inside
        # this mapping, so every key here is a real core.
        variable dependencies
        return [huddle keys $dependencies]
    }

    proc _loadYaml {yamlFile} {
        # Open and parse a YAML dependency file via huddle.
        # yamlFile - path to the YAML dependency file
        #
        # Validates the root-level version against scriptVersion. Returns
        # the huddle mapping node for the "dependencies" key.
        #
        # package require yaml/huddle happen here, not at file-load time --
        # this is the first (and only) place either is actually needed, so
        # a pure-simulation session (regression.tcl, no synthesis backend)
        # never requires tcllib's yaml/huddle packages to be installed at
        # all.
        variable prefix
        variable scriptVersion

        package require yaml
        package require huddle

        set fd [open $yamlFile r]
        set content [read $fd]
        close $fd

        set hDoc [::yaml::yaml2huddle $content]

        set fileVersion [_stripped $hDoc version]
        if {$fileVersion ne $scriptVersion} {
            error "${prefix}Version mismatch: script expects v${scriptVersion},\
                   [file tail $yamlFile] declares v${fileVersion}"
        }

        return [huddle get $hDoc dependencies]
    }

    proc _createLocalConfig {prjRoot dest {addToProject 1}} {
        # Generate local_configuration.vhdl from its template at dest, and
        # add it via the active backend.
        # prjRoot - absolute path of the consuming project's root
        # dest - absolute path to write the generated file to
        # addToProject - 1 (default) to also register dest via the active
        #  backend; 0 to only (re)write the physical file -- used when the
        #  file is already present in the project's file-set and only its
        #  on-disk copy needs to be restored.
        #
        # Sets LOCAL_PROJECT_DIR to the actual project root.
        variable pocRoot
        variable prefix
        variable defaultLibrary

        set tmpl [file join $pocRoot "src" "common" "local_configuration.vhdl.template"]

        set fh [open $tmpl r]
        set content [read $fh]
        close $fh

        # Normalise path to forward slashes for the VHDL string literal
        set prjRootFwd [string map {\\ /} $prjRoot]
        set content [string map \
            [list "CHANGE THIS in local_configuration.vhdl" "${prjRootFwd}/"] \
            $content]

        set fh [open $dest w]
        puts -nonewline $fh $content
        close $fh

        set fp [file normalize $dest]
        if {$addToProject} {
            _addSource $fp [[_backend]::defaultFileset] $defaultLibrary [[_backend]::defaultFileType]
        }

        puts "${prefix}  Created: [_relpath [pwd] $fp]"
        puts "${prefix}    LOCAL_PROJECT_DIR = \"${prjRootFwd}/\""
    }

    proc _createProjectConfig {dest {addToProject 1}} {
        # Generate project_configuration.vhdl from its template at dest,
        # and add it via the active backend.
        # dest - absolute path to write the generated file to
        # addToProject - 1 (default) to also register dest via the active
        #  backend; 0 to only (re)write the physical file -- used when the
        #  file is already present in the project's file-set and only its
        #  on-disk copy needs to be restored.
        #
        # MY_DEVICE is pre-filled from the backend's partHint when
        # available; MY_BOARD is left for the user to fill in manually.
        variable pocRoot
        variable prefix
        variable defaultLibrary

        set tmpl [file join $pocRoot "src" "common" "project_configuration.vhdl.template"]

        set fh [open $tmpl r]
        set content [read $fh]
        close $fh

        # Pre-fill MY_DEVICE from the backend's current part, if available
        set partHint ""
        set part [[_backend]::partHint]
        if {$part ne ""} {
            set content [string map \
                [list "\"CHANGE THIS\"; -- e.g. GENERIC, XC5VLX50T-1FF1136, EP2SGX90FF1508C3" \
                      "\"${part}\"; -- e.g. GENERIC, XC5VLX50T-1FF1136, EP2SGX90FF1508C3"] \
                $content]
            set partHint " (MY_DEVICE pre-filled as \"$part\")"
        }

        set fh [open $dest w]
        puts -nonewline $fh $content
        close $fh

        set fp [file normalize $dest]
        if {$addToProject} {
            _addSource $fp [[_backend]::defaultFileset] $defaultLibrary [[_backend]::defaultFileType]
        }

        set display [_relpath [pwd] $fp]
        puts "${prefix}  Created: ${display}${partHint}"
        puts "${prefix}    MY_BOARD still needs to be set — edit: $display"
    }

    proc _checkConfigurations {} {
        # Verify local_configuration.vhdl and project_configuration.vhdl are
        # present in the current project, auto-generating either that's
        # missing from its PoC template. For either that IS present in the
        # project's file-set, also verify it still exists on disk at its
        # recorded path and regenerate it there if it has gone missing
        # (e.g. an untracked file lost across a fresh checkout).
        #
        # hasProjectFile only proves the file-set *references* the file --
        # it says nothing about whether that path still exists on disk.
        # Vivado (and EDA tools generally) never re-verifies this once a
        # file has been added, so a project can silently carry a dangling
        # reference until something actually tries to read the file.
        #
        # No prompting -- the user is notified of what was created/restored.
        variable prefix

        set hasLocal   [[_backend]::hasProjectFile "*local_configuration*.vhdl"]
        set hasProject [[_backend]::hasProjectFile "*project_configuration*.vhdl"]

        set prjRoot [[_backend]::projectRoot]

        if {$hasLocal} {
            set fp [[_backend]::getProjectFilePath "*local_configuration*.vhdl"]
            if {$fp ne "" && ![file exists $fp]} {
                puts "${prefix}WARNING: local_configuration.vhdl is registered in the project but missing on disk: $fp"
                file mkdir [file dirname $fp]
                _createLocalConfig $prjRoot $fp 0
                puts "${prefix}  Re-created missing file: [_relpath [pwd] $fp]"
            }
        }
        if {$hasProject} {
            set fp [[_backend]::getProjectFilePath "*project_configuration*.vhdl"]
            if {$fp ne "" && ![file exists $fp]} {
                puts "${prefix}WARNING: project_configuration.vhdl is registered in the project but missing on disk: $fp"
                file mkdir [file dirname $fp]
                _createProjectConfig $fp 0
                puts "${prefix}  Re-created missing file: [_relpath [pwd] $fp]"
            }
        }

        if {$hasLocal && $hasProject} {
            puts "${prefix}Configuration files OK."
            return
        }

        set cfgDir [file join $prjRoot "src" "PoC"]

        set missing {}
        if {!$hasLocal}   { lappend missing "local_configuration*.vhdl" }
        if {!$hasProject} { lappend missing "project_configuration*.vhdl" }
        puts "${prefix}Missing: [join $missing {, }]"
        puts "${prefix}Auto-creating in: [file join [file tail $prjRoot] src PoC]"

        file mkdir $cfgDir

        if {!$hasLocal}   { _createLocalConfig   $prjRoot [file join $cfgDir "local_configuration.vhdl"] }
        if {!$hasProject} { _createProjectConfig          [file join $cfgDir "project_configuration.vhdl"] }

        puts "${prefix}Done — review [_relpath [pwd] [file join $cfgDir project_configuration.vhdl]] and set MY_BOARD / MY_DEVICE."
    }

    proc _fileStems {fullName} {
        # Return the basename (no directory, no .vhdl extension) of every
        # source file belonging to a VHDLSourceFile core.
        # fullName - full core key, e.g. PoC.arith.PRNG
        #
        # E.g. src/arith/arith_PRNG.vhdl -> arith_PRNG. Used by _resolveAll
        # so the original filename still resolves a core even after
        # path_to_key() strips the redundant namespace prefix from its key
        # (PoC.arith.arith_PRNG -> PoC.arith.PRNG).
        #
        # Only VHDLSourceFile cores, never XDCConstraintFile ones: a
        # constraint file's basename often coincides with its scoped VHDL
        # entity's (e.g. both ucf/fifo/fifo_ic_got.xdc and
        # src/fifo/fifo_ic_got.vhdl stem to "fifo_ic_got"), which would
        # otherwise make a single filename resolve to two different cores.
        variable dependencies
        set hCore [huddle get $dependencies $fullName]
        if {[_stripped $hCore kind] ne "VHDLSourceFile"} { return {} }
        set hSrcs [huddle get $hCore sources]
        set stems {}
        if {[_isSeq $hSrcs]} {
            set n [huddle llength $hSrcs]
            for {set i 0} {$i < $n} {incr i} {
                set fp [_stripped [huddle get $hSrcs $i] file]
                lappend stems [file rootname [file tail $fp]]
            }
        }
        return $stems
    }

    proc _resolveAll {name} {
        # Map a user-supplied name to a list of full core keys.
        # name - full key, short name, original filename, namespace, or glob pattern
        #
        # Always returns a list -- callers add every entry in the result.
        # Resolution order (first non-empty result wins), all comparisons
        # case-insensitive:
        #
        #   1. Exact full key        (PoC.arith.PRNG)      - one result
        #   2. Glob pattern          (arith.* / fifo_ic_*) - all matches
        #   3. Exact short name      (PRNG)                - one result
        #   4. Exact source filename (arith_PRNG)          - one result
        #   5. Namespace segment     (arith)                - all PoC.arith.*
        #   6. Short-name prefix     (PR)                   - all PR*
        variable prefix

        # Pre-split every key once: {key short parts} — reused across all passes
        set cores {}
        foreach key [_coreNames] {
            set parts [split $key "."]
            lappend cores [list $key [lindex $parts end] $parts]
        }

        # 1 — exact full key (case-insensitive)
        foreach c $cores {
            lassign $c key short parts
            if {[string equal -nocase $key $name]} { return [list $key] }
        }

        # 2 — glob pattern: name contains * ? or [ → match against full key,
        # short name, or an original source filename (e.g. "fifo_ic_*" still
        # finds fifo_ic_got/fifo_ic_assembly by their pre-rename filenames,
        # even though their keys/short names dropped the "fifo_ic_" stutter).
        if {[string match {*[*?\[]*} $name]} {
            set matches {}
            foreach c $cores {
                lassign $c key short parts
                if {[string match -nocase $name $key] ||
                    [string match -nocase $name $short]} {
                    lappend matches $key
                    continue
                }
                foreach stem [_fileStems $key] {
                    if {[string match -nocase $name $stem]} {
                        lappend matches $key
                        break
                    }
                }
            }
            if {[llength $matches] > 0} { return $matches }
            error "${prefix}No IP cores match pattern '$name'"
        }

        # 3 — exact short name, last dot-segment (case-insensitive)
        set matches {}
        foreach c $cores {
            lassign $c key short parts
            if {[string equal -nocase $short $name]} { lappend matches $key }
        }
        if {[llength $matches] > 0} { return $matches }

        # 4 — exact source filename (case-insensitive) — e.g. the pre-rename
        # short name "arith_PRNG" still finds PoC.arith.PRNG this way.
        set matches {}
        foreach c $cores {
            lassign $c key short parts
            foreach stem [_fileStems $key] {
                if {[string equal -nocase $stem $name]} { lappend matches $key; break }
            }
        }
        if {[llength $matches] > 0} { return $matches }

        # 5 — namespace segment match  (fifo -> all PoC.fifo.*) (case-insensitive)
        set matches {}
        foreach c $cores {
            lassign $c key short parts
            foreach seg [lrange $parts 0 end-1] {
                if {[string equal -nocase $seg $name]} { lappend matches $key; break }
            }
        }
        if {[llength $matches] > 0} { return $matches }

        # 6 — prefix match on short name  (PR -> PRNG, …)
        set matches {}
        foreach c $cores {
            lassign $c key short parts
            if {[string match -nocase "${name}*" $short]} { lappend matches $key }
        }
        if {[llength $matches] > 0} { return $matches }

        error "${prefix}No IP core found matching '$name'"
    }

    proc _collect {fullName force} {
        # Depth-first traversal of the dependency graph via huddle
        # accessors, appending full core names to _order in post-order.
        # fullName - full core key to collect (and recurse into its deps)
        # force - if false, skip an entire subtree when its first source
        #  file is already present in the project
        #
        # Dependencies are appended before the core that needs them. Skips
        # an entire subtree when the core's first source file is already
        # present in the project and force is not set.
        variable dependencies
        variable pocRoot
        variable _visited
        variable _order

        # Skip already-visited nodes (cycle guard)
        if {[dict exists $_visited $fullName]} { return }
        dict set _visited $fullName 1

        set hCore [huddle get $dependencies $fullName]

        # If the first source file is already in the project, assume all
        # dependencies of this core are present too and skip the subtree.
        if {!$force} {
            set hSrcs [huddle get $hCore sources]
            if {[_isSeq $hSrcs] && [huddle llength $hSrcs] > 0} {
                set first [file normalize \
                    [file join $pocRoot \
                        [_stripped [huddle get $hSrcs 0] file]]]
                if {[[_backend]::isInProject $first]} { return }
            }
        }

        # Recurse into dependsOn before adding this core (post-order).
        # dependsOn is optional -- may be entirely absent, not just ~/[].
        if {[_hasKey $hCore dependsOn]} {
            set hDeps [huddle get $hCore dependsOn]
            if {[_isSeq $hDeps]} {
                set n [huddle llength $hDeps]
                for {set i 0} {$i < $n} {incr i} {
                    _collect [_stripped $hDeps $i] $force
                }
            }
        }

        lappend _order $fullName
    }

    proc poc_Init {{depsFile ""} {library ""}} {
        # Initialise the PoC engine.
        # depsFile - path to the YAML dependency file; defaults to the
        #  active backend's defaultDependenciesFile
        # library - VHDL library name for all sourced files; defaults to
        #  the defaultLibrary variable ("PoC")
        #
        # 1. Optionally overrides the default VHDL library name.
        # 2. Loads and parses the YAML dependency file.
        # 3. Checks for local_configuration.vhdl and
        #    project_configuration.vhdl; auto-creates them from templates
        #    under <prj>/src/PoC/ if missing.
        #
        # Triggers backend auto-detection (see _backend) if none is
        # registered.
        variable pocRoot
        variable prefix
        variable scriptVersion
        variable defaultLibrary
        variable backendName
        variable dependencies

        _backend  ;# ensure a backend is registered (auto-detect if needed)

        if {$library ne ""} {
            set defaultLibrary $library
            puts "${prefix}Library overridden to: $defaultLibrary"
        }

        if {$depsFile eq ""} {
            set depsFile [[_backend]::defaultDependenciesFile]
        }

        if {![file exists $depsFile]} {
            error "${prefix}Dependency file not found: $depsFile"
        }

        set dependencies [_loadYaml $depsFile]

        set count [llength [_coreNames]]
        puts "${prefix}Loaded $count IP core(s) from [file tail $depsFile]\
              (v${scriptVersion}, backend=${backendName}, lib=${defaultLibrary})"

        # Verify project configuration files are present; auto-create if missing
        _checkConfigurations
    }

    proc poc_Add {name args} {
        # Resolve an IP name, walk its dependency graph, and add all
        # required VHDL sources and constraint files to the project via the
        # active backend.
        # name - full key, short name, original filename, namespace, or
        #  glob pattern (see _resolveAll)
        # args - -force to re-add files even if already in the project;
        #  -fileset name to target a specific fileset (default: backend's
        #  defaultFileset)
        #
        # Each source entry's vhdlVersion overrides the backend default for
        # that file only. Library is always taken from defaultLibrary.
        variable dependencies
        variable pocRoot
        variable prefix
        variable defaultLibrary
        variable _visited
        variable _order

        # --- parse options ----------------------------------------------------
        set force   0
        set fileset ""

        for {set i 0} {$i < [llength $args]} {incr i} {
            switch -- [lindex $args $i] {
                -force   { set force 1 }
                -fileset { set fileset [lindex $args [incr i]] }
                default  { error "${prefix}Unknown option: [lindex $args $i]" }
            }
        }

        if {$fileset eq ""} { set fileset [[_backend]::defaultFileset] }

        # --- resolve and traverse --------------------------------------------
        set fullNames [_resolveAll $name]

        set _visited {}
        set _order   {}
        foreach fullName $fullNames { _collect $fullName $force }

        if {[llength $_order] == 0} {
            puts "${prefix}$name already present in the project (use -force to re-add)"
            return
        }

        # --- add files in dependency order -----------------------------------
        set cwd [pwd]
        set filesAdded 0
        foreach coreName $_order {
            set hCore [huddle get $dependencies $coreName]
            set kind  [_stripped $hCore kind]

            set hSrcs [huddle get $hCore sources]
            if {![_isSeq $hSrcs]} { continue }

            set n [huddle llength $hSrcs]
            for {set i 0} {$i < $n} {incr i} {
                set hSrc [huddle get $hSrcs $i]
                set fp   [file normalize [file join $pocRoot [_stripped $hSrc file]]]

                switch -- $kind {
                    VHDLSourceFile {
                        # Per-file vhdlVersion overrides the backend default.
                        # Optional -- usually absent (see graphml2yml.py), but
                        # tolerate an explicit ~ from a hand-written override too.
                        set fileType [[_backend]::defaultFileType]
                        if {[_hasKey $hSrc vhdlVersion]} {
                            set hVer [huddle get $hSrc vhdlVersion]
                            if {![_isNull $hVer]} {
                                set fileType [[_backend]::vhdlFileType [_val $hVer]]
                            }
                        }

                        _addSource $fp $fileset $defaultLibrary $fileType
                        puts "${prefix}Added source:      [_relpath $cwd $fp]  ($fileType, lib=$defaultLibrary)"
                    }
                    XDCConstraintFile {
                        [_backend]::addConstraintFile $fp $fileset
                        puts "${prefix}Added constraint:  [_relpath $cwd $fp]"
                    }
                    default {
                        error "${prefix}Unknown kind '$kind' for core $coreName"
                    }
                }
                incr filesAdded

                # Apply any generic per-source attributes (e.g. SCOPED_TO_REF).
                # Optional -- usually absent when there are none (see
                # graphml2yml.py); tolerate an explicit ~ too.
                if {[_hasKey $hSrc attributes]} {
                    set hAttrs [huddle get $hSrc attributes]
                    if {[_isMap $hAttrs]} {
                        foreach attrName [huddle keys $hAttrs] {
                            set attrValue [_stripped $hAttrs $attrName]
                            [_backend]::setAttribute $fp $attrName $attrValue
                            puts "${prefix}  set attribute:   $attrName = $attrValue"
                        }
                    }
                }
            }

            # Optional: let the backend react to specific, known cores
            if {[llength [info commands [_backend]::onCoreAdded]] > 0} {
                [_backend]::onCoreAdded $coreName
            }
        }

        set nResolved [llength $fullNames]
        if {$nResolved > 1} {
            puts "${prefix}Done — added $filesAdded file(s) for $nResolved IPs matching '$name'"
        } else {
            puts "${prefix}Done — added $filesAdded file(s) for $name"
        }
    }

    proc poc_Help {} {
        # Print a short overview of all available PoC commands.
        variable prefix
        variable scriptVersion
        variable backendName

        set backendLabel [expr {$backendName ne "" ? $backendName : "none registered"}]

        puts "${prefix}PoC engine v${scriptVersion}  (backend: ${backendLabel})"
        puts ""
        puts "  Commands (CamelCase and lowercase aliases are equivalent):"
        puts ""
        puts "  poc_Init  \[depsFile\] \[library\]"
        puts "  poc init  \[depsFile\] \[library\]"
        puts "    Load the YAML dependency file, verify/create project configuration files."
        puts "    depsFile  defaults to the active backend's defaultDependenciesFile"
        puts "    library   defaults to PoC"
        puts ""
        puts "  poc_Add  <name> \[-force\] \[-fileset <name>\]"
        puts "  poc add  <name> \[-force\] \[-fileset <name>\]"
        puts "    Resolve <name> and add it with all dependencies to the project."
        puts "    <name> may be a full key, short name, namespace, or prefix."
        puts "    -force   re-add files already present in the project."
        puts "    -fileset target fileset (default: backend's defaultFileset)."
        puts ""
        puts "  poc_ListIPs  \[pattern\]"
        puts "  poc list     \[pattern\]"
        puts "    List all known IP cores, optionally filtered by pattern."
        puts "    pattern matches against full key, short name, or namespace."
        puts ""
        puts "  poc_Help"
        puts "  poc help"
        puts "    Print this help."
    }

    proc poc_ListIPs {{pattern "*"}} {
        # Print all known IP cores, optionally filtered by a pattern.
        # pattern - glob pattern matched against full key, short name, or
        #  namespace segment (default "*", i.e. everything)
        #
        # A namespace's canonical package (short name "pkg") is displayed
        # under its namespace instead (e.g. PoC.sync.pkg is shown as
        # "sync", not "pkg") -- matching is unaffected, only the printed
        # name.
        variable prefix

        set result {}
        foreach fullName [_coreNames] {
            set parts [split $fullName "."]
            set short [lindex $parts end]
            if {[string match $pattern $fullName]  ||
                [string match $pattern $short]     ||
                [lsearch $parts $pattern] >= 0} {
                # Display-only: a namespace's canonical package has short
                # name "pkg", which doesn't distinguish one package from
                # another in a list of many -- show its namespace instead.
                # Matching above still uses the real short name ("pkg"),
                # consistent with how _resolveAll resolves it.
                set display $short
                if {$display eq "pkg" && [llength $parts] > 1} {
                    set display [lindex $parts end-1]
                }
                lappend result "  [format %-32s $display]  $fullName"
            }
        }

        if {[llength $result] == 0} {
            puts "${prefix}No cores match '$pattern'"
        } else {
            puts "${prefix}[llength $result] core(s) matching '$pattern':"
            puts [join $result "\n"]
        }
    }

    proc poc_init {args} {
        # Lowercase alias for poc_Init, usable after namespace import.
        # args - forwarded to poc_Init as-is
        poc_Init {*}$args
    }
    proc poc_add {args} {
        # Lowercase alias for poc_Add, usable after namespace import.
        # args - forwarded to poc_Add as-is
        poc_Add {*}$args
    }
    proc poc_listips {args} {
        # Lowercase alias for poc_ListIPs, usable after namespace import.
        # args - forwarded to poc_ListIPs as-is
        poc_ListIPs {*}$args
    }
    proc poc_help {args} {
        # Lowercase alias for poc_Help, usable after namespace import.
        # args - forwarded to poc_Help as-is
        poc_Help {*}$args
    }

    proc poc {{subcmd "help"} args} {
        # Convenience dispatcher: poc ?subcommand? ?args?
        # subcmd - one of init, add, list, help (default "help")
        # args - forwarded to the resolved poc_* command
        variable prefix
        switch -nocase -- $subcmd {
            init   { poc_Init    {*}$args }
            add    { poc_Add     {*}$args }
            list   { poc_ListIPs {*}$args }
            help   { poc_Help             }
            default {
                puts "${prefix}Unknown subcommand '$subcmd'  (init / add / list / help)"
                poc_Help
            }
        }
    }

    namespace export poc_* poc registerBackend
}

puts "${::poc::synth::prefix}Loaded tools/poc.tcl ::poc::synth namespace (synthesis engine, v${::poc::synth::scriptVersion})."

namespace eval ::version {
	variable _ruff_preamble {
		Comparison utilities for version strings of the form:

				\[<prefix>\]<seg1>\[.<seg2>\[.<seg3>\[.<seg4>\]\]\]\[-dev\]

		`prefix` is optional, either `v`/`V` \(external release\) or `i`/`I` \(internal release\). `segN` are
		unsigned integer segments; 1 to 4 may be given, so the minimal valid input is a single segment such
		as `v2`. A trailing `-dev` marks a development build, which sorts strictly below the non-dev release
		carrying the same numeric version.

		Examples of valid input: `v2`, `i1.4`, `3.2.1.0`, `v10.2-dev`, `2-dev`.

		The optional `v`/`i` prefix carries no semantic meaning for comparison purposes -- it is only
		validated for syntax and is otherwise ignored, so `v3` and `i3` compare as equal.

		\[cmp\] returns one of `-2`, `-1`, `0`, `1`, `2`: magnitude 2 marks a strict difference in the numeric
		version, magnitude 1 marks a `-dev`-vs-release difference within the same numeric version, and 0
		marks an exact match. \[compare\] wraps \[cmp\] with Tcl-style `lt`/`le`/`eq`/`ne`/`ge`/`gt` operator
		tokens, returning a boolean instead.
	}

	variable prefix "\[Version\] "

	variable VERSION_RE {^([vViI])?(\d+(?:\.\d+){0,3})(-dev)?$}

	namespace export cmp compare

	proc Parse {verStr} {
		# Parses a single version string into its normalized components.
		# verStr - version string to parse, e.g. `v1.2.3-dev`, `i4`, `2.0.1.5`.
		#
		# The string must match `[v|i]N[.N]{0,3}[-dev]`. Segments beyond the ones given are treated as
		# zero, so `i4` and `i4.0.0.0` describe the same numeric version. Segments are zero-padded
		# internally to a fixed length of four so callers never need to handle short lists.
		#
		# Returns: a 3-element list `{prefix segments devFlag}` where `prefix` is the lowercase prefix
		# character or an empty string, `segments` is a 4-element list of integers, and `devFlag` is 1 if
		# the string carried a `-dev` marker, 0 otherwise. Raises an error if `verStr` does not match the
		# expected syntax.
		variable VERSION_RE

		if {![regexp $VERSION_RE $verStr -> prefix numPart devPart]} {
			return -code error "Invalid version string \"$verStr\": expected \[v|i\]N\[.N\]\{0,3\}\[-dev\]"
		}

		set segments [split $numPart "."]
		while {[llength $segments] < 4} {
			lappend segments 0
		}

		return [list [string tolower $prefix] $segments [expr {$devPart ne ""}]]
	}

	proc cmp {a b} {
		# Compares two version strings on a five-value scale.
		# a - first version string
		# b - second version string
		#
		# Both strings are parsed with [Parse] and zero-padded to four numeric segments, which are then
		# compared left to right. The optional `v`/`i` prefix is validated for syntax only and has no
		# effect on ordering.
		#
		# If the numeric segments differ, that is a genuine, strict version difference and the magnitude 2
		# is returned (`-2` if a < b, `2` if a > b).
		#
		# If the numeric segments are identical but the `-dev` markers differ, `a` and `b` denote the same
		# release at a different maturity stage rather than a different version, so the weaker magnitude 1
		# is returned instead: `-1` if `a` is the `-dev` build and `b` is the release (a is less-or-equal to
		# b), `1` if `a` is the release and `b` is the `-dev` build (a is greater-or-equal to b).
		#
		# If numeric segments and `-dev` markers both match, `0` is returned.
		#
		# Returns: one of `-2`, `-1`, `0`, `1`, `2`. The sign always indicates direction and can be used
		# directly in `if`/`expr`, e.g. `if {[::version::cmp $a $b] < 0} { ... }`; the magnitude
		# additionally distinguishes a strict version difference (2) from a dev/release difference within
		# the same version (1).
		#
		# See also: Parse
		lassign [Parse $a] prefixA segA devA
		lassign [Parse $b] prefixB segB devB

		foreach sa $segA sb $segB {
			if {$sa < $sb} { return -2 }
			if {$sa > $sb} { return 2 }
		}

		if {$devA == $devB} { return 0 }
		return [expr {$devA ? -1 : 1}]
	}

	proc compare {a op b} {
		# Tests whether a version comparison holds, using Tcl-style operator tokens instead of a numeric
		# result.
		# a - first version string
		# b - second version string
		# op - one of `lt`, `le`, `eq`, `ne`, `ge`, `gt` -- the same tokens Tcl's own `expr` uses for
		#  string comparison (e.g. `expr {$a eq $b}`)
		#
		# Built on top of [cmp], whose `-2/-1/0/1/2` result already distinguishes a strict numeric
		# difference (magnitude 2) from a `-dev`-vs-release difference within the same numeric version
		# (magnitude 1). That distinction maps naturally onto the six operators:
		#
		# lt - true only for a strict numeric difference (magnitude 2); a `-dev` build is not considered
		#  `lt` its own release
		# gt - the mirror image of `lt`
		# le - true for `lt`, equality, *and* the magnitude-1 case where a is the `-dev` build of the same
		#  numeric version as b
		# ge - the mirror image of `le`
		# eq - true only when versions match exactly, including `-dev` status
		# ne - the negation of `eq`
		#
		# Returns: 1 if the comparison holds, 0 otherwise, so the result can be used directly in `if`, e.g.
		# `if {[::version::compare $a le $b]} { ... }`.
		#
		# See also: cmp
		set raw [cmp $a $b]

		switch -exact -- $op {
			lt { return [expr {$raw == -2}] }
			gt { return [expr {$raw ==  2}] }
			le { return [expr {$raw <=  0}] }
			ge { return [expr {$raw >=  0}] }
			eq { return [expr {$raw ==  0}] }
			ne { return [expr {$raw !=  0}] }
			default {
				return -code error "Invalid comparison operator \"$op\": must be one of lt, le, eq, ne, ge, gt"
			}
		}
	}
}

puts "${::version::prefix}Loaded tools/poc.tcl ::version namespace."
