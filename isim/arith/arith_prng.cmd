echo off

rem save current working directory
echo starting automated testbench for PoC.arith_prng...
echo ================================================================================
set OLD_PWD=%CD%

rem load configuration (installation paths)
echo load configuration...
call ..\config.cmd

rem load xilinx environment
echo load settings...
call %ISE_HOME%\settings64.bat

rem goto \temp\isim; all temporary files are stored in this directory; if not existent, create it
echo move working directory to %POC_HOME%\temp\isim
mkdir %POC_HOME%\temp\isim
cd %POC_HOME%\temp\isim

rem step 1 - compile sources
echo compiling vhdl sources...
echo ================================================================================
%ISE_BIN%\vhpcomp.exe -prj %POC_HOME%\isim\arith\arith_prng.prj

rem step 2 - link sources
echo linking compiled sources...
echo ================================================================================
%ISE_BIN%\fuse.exe work.test_arith_prng -prj %POC_HOME%\isim\arith\arith_prng.prj -o arith_prng.exe

rem step 3 - run executable
echo starting simulation in batch-mode...
echo ================================================================================
arith_prng.exe -tclbatch %POC_HOME%\isim\arith\arith_prng.tcl
echo ================================================================================

cd %OLD_PWD%
echo on
