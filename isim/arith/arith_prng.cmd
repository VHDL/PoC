set OLD_PWD=%CD%

call ..\config.cmd

echo "load settings..."
call %ISE_HOME%\settings64.bat

echo "move working directory to %POC_HOME%\temp\isim"
cd %POC_HOME%
mkdir temp\isim
cd temp\isim

echo "compile vhdl sources..."
%ISE_BIN%\vhpcomp.exe -prj %POC_HOME%\isim\arith\arith_prng.prj

echo "linking compiled sources..."
%ISE_BIN%\fuse.exe work.test_arith_prng -prj %POC_HOME%\isim\arith\arith_prng.prj -o arith_prng.exe

echo "start simulation in batch-mode..."
arith_prng.exe -tclbatch %POC_HOME%\isim\arith\arith_prng.tcl

cd %OLD_PWD%