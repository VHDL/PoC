# =============================================================================
# Authors:
#   Adrian Weiland, Jonas Schreiner
# =============================================================================

library PoC

analyze $::poc::myConfigFile
analyze $::poc::myProjectFile

include ./common/common.pro
include ./arith/arith.pro
include ./mem/mem.pro
include ./sync/sync.pro
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

