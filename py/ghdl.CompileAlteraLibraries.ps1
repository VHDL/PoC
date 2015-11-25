# configure Altera folder here
$SIMLIB = "C:\Altera\15.0\quartus\eda\sim_lib"
$DestinationDirectory = "Altera"

# ---------------------------------------------
# save working directory
$WorkingDir = Get-Location

# define global GHDL options
$OPTIONS = ("-a", "-fexplicit", "-frelaxed-rules", "--warn-binding", "--no-vital-checks", "--mb-comments", "--ieee=synopsys", "--std=93c")

# create "Altera" directory and change to it
mkdir $DestinationDirectory
cd $DestinationDirectory

Write-Host "Analysing library 'lpm' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\220pack.vhd",
	"$SIMLIB\220model.vhd")
& ghdl.exe $OPTIONS --work=lpm $Files

Write-Host "Analysing library 'sgate' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\sgate_pack.vhd",
	"$SIMLIB\sgate.vhd")
& ghdl.exe $OPTIONS --work=sgate $Files

Write-Host "Analysing library 'altera' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\altera_europa_support_lib.vhd",
	"$SIMLIB\altera_mf_components.vhd",
	"$SIMLIB\altera_mf.vhd",
	"$SIMLIB\altera_primitives_components.vhd",
	"$SIMLIB\altera_primitives.vhd",
	"$SIMLIB\altera_standard_functions.vhd",
	"$SIMLIB\altera_syn_attributes.vhd",
	"$SIMLIB\alt_dspbuilder_package.vhd")
& ghdl.exe $OPTIONS --work=altera $Files

Write-Host "Analysing library 'altera_mf' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\altera_mf_components.vhd",
	"$SIMLIB\altera_mf.vhd")
& ghdl.exe $OPTIONS --work=altera_mf $Files

Write-Host "Analysing library 'altera_lnsim' ..." -ForegroundColor Cyan
& ghdl.exe $OPTIONS --work=altera_lnsim $SIMLIB\altera_lnsim_components.vhd

Write-Host "Analysing library 'arriaii' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriaii_atoms.vhd",
	"$SIMLIB\arriaii_components.vhd",
	"$SIMLIB\arriaii_hssi_components.vhd",
	"$SIMLIB\arriaii_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=arriaii $Files

Write-Host "Analysing library 'arriaii_pcie_hip' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriaii_pcie_hip_components.vhd",
	"$SIMLIB\arriaii_pcie_hip_atoms.vhd")
& ghdl.exe $OPTIONS --work=arriaii_pcie_hip $Files

Write-Host "Analysing library 'arriaiigz' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriaiigz_atoms.vhd",
  "$SIMLIB\arriaiigz_components.vhd",
  "$SIMLIB\arriaiigz_hssi_components.vhd")
& ghdl.exe $OPTIONS --work=arriaiigz $Files

Write-Host "Analysing library 'arriav' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriav_atoms.vhd",
	"$SIMLIB\arriav_components.vhd",
	"$SIMLIB\arriav_hssi_components.vhd",
	"$SIMLIB\arriav_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=arriav $Files

Write-Host "Analysing library 'arriavgz' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriavgz_atoms.vhd",
	"$SIMLIB\arriavgz_components.vhd",
	"$SIMLIB\arriavgz_hssi_components.vhd",
	"$SIMLIB\arriavgz_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=arriavgz $Files

Write-Host "Analysing library 'arriavgz_pcie_hip' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\arriavgz_pcie_hip_components.vhd",
	"$SIMLIB\arriavgz_pcie_hip_atoms.vhd")
& ghdl.exe $OPTIONS --work=arriavgz_pcie_hip $Files

Write-Host "Analysing library 'cycloneiv' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\cycloneiv_atoms.vhd",
	"$SIMLIB\cycloneiv_components.vhd",
	"$SIMLIB\cycloneiv_hssi_components.vhd",
	"$SIMLIB\cycloneiv_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=cycloneiv $Files

Write-Host "Analysing library 'cycloneiv_pcie_hip' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\cycloneiv_pcie_hip_components.vhd",
	"$SIMLIB\cycloneiv_pcie_hip_atoms.vhd")
& ghdl.exe $OPTIONS --work=cycloneiv_pcie_hip $Files

Write-Host "Analysing library 'cycloneive' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\cycloneive_atoms.vhd",
	"$SIMLIB\cycloneive_components.vhd")
& ghdl.exe $OPTIONS --work=cycloneive $Files

Write-Host "Analysing library 'cyclonev' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\cyclonev_atoms.vhd",
	"$SIMLIB\cyclonev_components.vhd",
	"$SIMLIB\cyclonev_hssi_components.vhd",
	"$SIMLIB\cyclonev_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=cyclonev $Files

Write-Host "Analysing library 'max' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\max_atoms.vhd",
	"$SIMLIB\max_components.vhd")
& ghdl.exe $OPTIONS --work=max $Files

Write-Host "Analysing library 'maxii' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\maxii_atoms.vhd",
	"$SIMLIB\maxii_components.vhd")
& ghdl.exe $OPTIONS --work=maxii $Files

Write-Host "Analysing library 'maxv' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\maxv_atoms.vhd",
	"$SIMLIB\maxv_components.vhd")
& ghdl.exe $OPTIONS --work=maxv $Files

Write-Host "Analysing library 'stratixiv' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\stratixiv_atoms.vhd",
	"$SIMLIB\stratixiv_components.vhd",
	"$SIMLIB\stratixiv_hssi_components.vhd",
	"$SIMLIB\stratixiv_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=stratixiv $Files

Write-Host "Analysing library 'stratixiv_pcie_hip' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\stratixiv_pcie_hip_components.vhd",
	"$SIMLIB\stratixiv_pcie_hip_atoms.vhd")
& ghdl.exe $OPTIONS --work=stratixiv_pcie_hip $Files

Write-Host "Analysing library 'stratixv' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\stratixv_atoms.vhd",
	"$SIMLIB\stratixv_components.vhd",
	"$SIMLIB\stratixv_hssi_components.vhd",
	"$SIMLIB\stratixv_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=stratixv $Files

Write-Host "Analysing library 'stratixv_pcie_hip' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\stratixv_pcie_hip_components.vhd",
	"$SIMLIB\stratixv_pcie_hip_atoms.vhd")
& ghdl.exe $OPTIONS --work=stratixv_pcie_hip $Files

Write-Host "Analysing library 'fiftyfivenm' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\fiftyfivenm_atoms.vhd",
	"$SIMLIB\fiftyfivenm_components.vhd")
& ghdl.exe $OPTIONS --work=fiftyfivenm $Files

Write-Host "Analysing library 'twentynm' ..." -ForegroundColor Cyan
$Files = (
	"$SIMLIB\twentynm_atoms.vhd",
	"$SIMLIB\twentynm_components.vhd",
	"$SIMLIB\twentynm_hip_components.vhd",
	"$SIMLIB\twentynm_hip_atoms.vhd",
	"$SIMLIB\twentynm_hssi_components.vhd",
	"$SIMLIB\twentynm_hssi_atoms.vhd")
& ghdl.exe $OPTIONS --work=twentynm $Files

Write-Host "--------------------------------------------------------------------------------"
Write-Host "Analyze complete" -ForegroundColor Green

# restore working directory
cd $WorkingDir