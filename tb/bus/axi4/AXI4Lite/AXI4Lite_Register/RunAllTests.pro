# =============================================================================
# Authors:
#	Iqbal Asif (PLC2 Design GmbH)
#	Patrick Lehmann (PLC2 Design GmbH)
#	Adrian Weiland (PLC2 Design GmbH)
#
# License:
# =============================================================================
# Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential
# =============================================================================

TestSuite PoC.bus.axi4.axi4lite.Register

library tb_axi4liteRegister

analyze AXI4Lite_Register_pkg.vhdl
analyze AXI4Lite_Register_TestController.vhdl
analyze AXI4Lite_Register_TestHarness.vhdl

# Test cases
RunTest AXI4Lite_Register_initial.vhdl
RunTest AXI4Lite_Register_ReadWrite.vhdl
