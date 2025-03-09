# =============================================================================
# Authors:
#	Adrian Weiland
#
# License:
# =============================================================================
# Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential
# =============================================================================

analyze io.pkg.vhdl
analyze io_Debounce.vhdl
analyze io_FrequencyCounter.vhdl
# analyze io_TimingCounter.vhdl
analyze io_GlitchFilter.vhdl
analyze io_PulseWidthModulation.vhdl

include ./uart/uart.pro
