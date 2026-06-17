namespace eval ::poc {
	proc getEnv {var {default ""}} {
		if {[info exists ::env($var)]} {
			return $::env($var)
		}
		return $default
	}

	variable vendorName [getEnv VENDOR "GENERIC"]
	variable boardName  [getEnv BOARD  "GENERIC"]
	variable buildNamePrefix ""

	variable myConfigFolder "../tb/common"
	variable myConfigFile  [file join $myConfigFolder "my_config_${::poc::boardName}.vhdl"]
	variable myProjectFile [file join $myConfigFolder "my_project.vhdl"]

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
						puts "Option -stopCount requires an integer value."
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
					puts "ERROR: Unknown option $arg"
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
			SetExtendedAnalyzeOptions {--relaxed}

		} elseif {$::osvvm::ToolName eq "Sigasi"} {

		} else {
			puts [format {
======================================
Unknown simulator selected: %s

Supported simulators:
  - GHDL
  - NVC
  - Riviera-PRO
Other tools:
  - Sigasi in VSCode
======================================
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

				"-projectFile" -
				"-p" {
					incr i
					if {$i < [llength $args]} {
							set ::poc::myProjectFile [lindex $args $i]
					}
				}

				"-configFile" -
				"-c" {
					incr i
					if {$i < [llength $args]} {
							set ::poc::myConfigFile [lindex $args $i]
					}
				}

				default {
					puts "ERROR: Unknown option $arg"
					exitScript
				}
			}
			incr i
		}
	}

	proc checkForBuildErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "ERROR: While building $::osvvm::LastBuildName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="

			exitScript
			return 1
		}
		return 0
	}

	proc checkForRunErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "ERROR: While building $::osvvm::LastBuildName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="

			exitScript 2
			return 1
		} elseif {$::osvvm::SimulateErrorCount > 0} {
			puts "ERROR: While simulating $::osvvm::TestCaseName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="
			exitScript 3
			return 1
		}
		return 0
	}

	# New procedures for OSVVM's *.pro files
	proc disabled {args} {
		puts "Disabled from analysis: $args"
	}
	proc duplicate {args} {
		puts "Duplicate file: $args"
	}

	namespace export exitScript
	namespace export configureOSVVM
	namespace export configurePoC
	namespace export checkForBuildErrors
	namespace export checkForRunErrors
	namespace export disabled
	namespace export duplicate
}

puts "Loaded PoC extensions for OSVVM."

namespace eval ::regression {
	proc createRegressionLevels {args} {
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

		puts "\[WARNING\] Unknown build level '$step', using 'all'."
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
			puts "\[REGRESSION INFO\] Undefined or unknown argument, using default settings."
		}
		set ::regression::level [mapRegressionLevel $selectedStep $regressionLevels]
		
		# 3. output result
		puts "=================================="
		puts "Build configuration"
		puts "  Level: $::regression::level (set by $buildConfigSource)"
		puts "  Executing [expr {$::regression::executeSingleStep ? "only" : "starting from"}] step '$selectedStep'"
		puts "=================================="
	}

	namespace export createRegressionLevels
	namespace export evaluateRegressionLevel
}

puts "Loaded regression extensions."
