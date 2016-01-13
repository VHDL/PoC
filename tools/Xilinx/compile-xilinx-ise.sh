#!/bin/bash

Simulator=questa															# questa, ...
Language=vhdl																# all, vhdl, verilog
DestDir=/home/zabel/git/poc-examples/lib/PoC/temp/QuestaSim	# Output directory
SimulatorDir=/opt/questasim/10.4c/questasim/bin	# Path to the simulators bin directory
TargetArchitecture=all														# all, virtex5, virtex6, virtex7, ...


compxlib -64bit -s $Simulator -l $Language -dir $DestDir -p $SimulatorDir -arch $TargetArchitecture -lib unisim -lib simprim -lib xilinxcorelib -intstyle ise
