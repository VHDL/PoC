# =============================================================================
# Authors:
#	Iqbal Asif (PLC2 Design GmbH)
#	Patrick Lehmann (PLC2 Design GmbH)
#
# License:
# =============================================================================
# Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential
# =============================================================================

TestSuite TestBench_AXI4Lite_Register

analyze AXI4Lite_Register_TestController.vhdl
analyze AXI4Lite_Register_TestHarness.vhdl
analyze TC_RandomReadWrite.vhdl

simulate TC_RandomReadWrite
