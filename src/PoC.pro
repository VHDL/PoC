# =============================================================================
# Authors:
#   Adrian Weiland, Jonas Schreiner
#
# License:
# =============================================================================
# Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential
# =============================================================================

library PoC

include ./common/common.pro
include ./arith/arith.pro
include ./mem/mem.pro
include ./misc/misc.pro
include ./fifo/fifo.pro

include ./misc/gearbox/gearbox.pro
analyze ./io/io_TimingCounter.vhdl

include ./dstruct/dstruct.pro
include ./io/io.pro
include ./bus/bus.pro
include ./comm/comm.pro
include ./sort/sort.pro
include ./cache/cache.pro
include ./net/net.pro

