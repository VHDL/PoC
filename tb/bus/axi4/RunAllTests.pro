# =============================================================================
# Authors:
#	Iqbal Asif
#	Patrick Lehmann
#	Adrian Weiland
#	Stefan Unrein
#
# License:
# =============================================================================
# Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential
# =============================================================================

# TestSuite PoC.bus.axi4
# Deactivated to avoid failure on non-existing testcases

library tb_axi4

include ./AXI4Lite/RunAllTests.pro

#include ./AXI4Stream/Buffer/RunAllTests.pro
#include ./AXI4Stream/Buffer_CDC/RunAllTests.pro
#include ./AXI4Stream/DeMux/RunAllTests.pro
#include ./AXI4Stream/Delay/RunAllTests.pro
#include ./AXI4Stream/Splitter/RunAllTests.pro
#include ./AXI4Stream/DestHandler/RunAllTests.pro
#include ./AXI4Stream/Realign/RunAllTests.pro
