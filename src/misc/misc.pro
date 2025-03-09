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
include ./sync/sync.pro

analyze ./misc_Delay.vhdl
analyze ./misc_FrequencyMeasurement.vhdl

analyze ./stat/stat.pkg.vhdl

include ./filter/filter.pro

# Included in PoC.pro for cross-dependency
# include ./gearbox/gearbox.pro
