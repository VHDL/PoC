namespace eval ::poc {
	variable putsPrefix   "\[PoC\]        "
	variable putsPrefixNs "\[PoC\] "
	proc getEnv {var {default ""}} {
		if {[info exists ::env($var)]} {
			return $::env($var)
		}
		return $default
	}

	variable projectRoot "."
	variable vendorName [getEnv VENDOR "GENERIC"]
	variable boardName  [getEnv BOARD  "GENERIC"]
	variable buildNamePrefix ""

	# Relative to the location of src/build.pro
	variable localConfigurationFolder "../tb/common"
	variable projectConfigurationFile "$localConfigurationFolder/project_configuration_${::poc::boardName}.vhdl"
	variable localConfigurationFile   "$localConfigurationFolder/local_configuration.vhdl"
	variable localConfigurationPath   "$projectRoot/src/$localConfigurationFolder/local_configuration.vhdl"

	variable disableExit 0

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
	} else {
		set buildNamePrefix "${::osvvm::ToolNameVersion}-"
	}

	proc exitScript {{code 1}} {
		if {$::poc::disableExit == 1} {
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
						puts "${::poc::putsPrefix}Option -stopCount requires an integer value."
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
					puts "${::poc::putsPrefix}ERROR: Unknown option $arg"
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
${::poc::putsPrefix}======================================
${::poc::putsPrefix}Unknown simulator selected: %s
${::poc::putsPrefix}
${::poc::putsPrefix}Supported simulators:
${::poc::putsPrefix}  - GHDL
${::poc::putsPrefix}  - NVC
${::poc::putsPrefix}  - Riviera-PRO
${::poc::putsPrefix}Other tools:
${::poc::putsPrefix}  - Sigasi in VSCode
${::poc::putsPrefix}======================================
} $::osvvm::ToolName]
			exitScript
		}
	}

	proc configurePoC {args} {
		set i 0
		while {$i < [llength $args]} {
			set arg [lindex $args $i]

			switch -glob -- $arg {
				"-gui" -
				"-g" {
					set ::poc::disableExit 1
				}

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
							set ::poc::projectRoot [lindex $args $i]
					}
				}

				"-projectFile" -
				"-p" {
					incr i
					if {$i < [llength $args]} {
							set ::poc::localConfigurationFile [lindex $args $i]
					}
				}

				"-configFile" -
				"-c" {
					incr i
					if {$i < [llength $args]} {
							set ::poc::projectConfigurationFile [lindex $args $i]
					}
				}

				default {
					puts "${::poc::putsPrefix}ERROR: Unknown option $arg"
					exitScript
				}
			}
			incr i
		}

		puts "${::poc::putsPrefix}Relative to src/build.pro:"
		puts "${::poc::putsPrefix}  projectConfigurationFile is '$::poc::projectConfigurationFile'"
		puts "${::poc::putsPrefix}  localConfigurationFile is '$::poc::localConfigurationFile'"

		set ::poc::localConfigurationPath   "$::poc::projectRoot/src/$::poc::localConfigurationFile"
	}

	proc WriteLocalConfiguration {} {
		puts "${::poc::putsPrefix}Generate local configuration in '$::poc::localConfigurationFile' with working dir to root '$::poc::projectRoot'"
		set content "package local_configuration is\n"
		append content "\tconstant LOCAL_PROJECT_DIR : string := \"$::poc::projectRoot\";\n"
		append content "end package;\n"

		set fileHandle [open "$::poc::projectRoot/src/$::poc::localConfigurationFile" "w"]
		puts -nonewline $fileHandle $content
		close $fileHandle
	}

	proc checkForBuildErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "${::poc::putsPrefix}ERROR: While building $::osvvm::LastBuildName"
			puts "${::poc::putsPrefix}====================================="
			puts "${::poc::putsPrefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::putsPrefix}====================================="

			exitScript
			return 1
		}
		return 0
	}

	proc checkForRunErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "${::poc::putsPrefix}ERROR: While building $::osvvm::LastBuildName"
			puts "${::poc::putsPrefix}====================================="
			puts "${::poc::putsPrefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::putsPrefix}====================================="

			exitScript 2
			return 1
		} elseif {$::osvvm::SimulateErrorCount > 0} {
			puts "${::poc::putsPrefix}ERROR: While simulating $::osvvm::TestCaseName"
			puts "${::poc::putsPrefix}====================================="
			puts "${::poc::putsPrefix}$::osvvm::BuildErrorInfo"
			puts "${::poc::putsPrefix}====================================="
			exitScript 3
			return 1
		}
		return 0
	}

	# New procedures for OSVVM's *.pro files
	proc disabled {args} {
		puts "${::poc::putsPrefixNs}Disabled from analysis: $args"
	}
	proc duplicate {args} {
		puts "${::poc::putsPrefixNs}Duplicate file: $args"
	}

	namespace export exitScript
	namespace export configureOSVVM
	namespace export configurePoC
	namespace export WriteLocalConfiguration
	namespace export checkForBuildErrors
	namespace export checkForRunErrors
	namespace export disabled
	namespace export duplicate
}

puts "${::poc::putsPrefix}Loaded tools/poc.tcl poc namespace."

namespace eval ::regression {
	variable putsPrefix "\[Regression\] "
	proc createRegressionLevels {args} {
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
