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
				"-gui" -
				"-g" {
					set ::poc::disableExit 1
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

	proc checkForBuildErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "ERROR: While building $::osvvm::LastBuildName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="

			exitScript
		}
	}

	proc checkForRunErrors {} {
		if {$::osvvm::AnalyzeErrorCount > 0} {
			puts "ERROR: While building $::osvvm::LastBuildName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="

			exitScript 2
		} elseif {$::osvvm::SimulateErrorCount > 0} {
			puts "ERROR: While simulating $::osvvm::TestCaseName"
			puts "====================================="
			puts $::osvvm::BuildErrorInfo
			puts "====================================="
			exitScript 3
		}
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
	namespace export checkForBuildErrors
	namespace export checkForRunErrors
	namespace export disabled
	namespace export duplicate
}
