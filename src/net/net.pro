# =============================================================================
# Authors: Guy Eschemann
#          Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

analyze ./net.pkg.vhdl
analyze ./net_FrameChecksum.vhdl

include ./arp/arp.pro
include ./icmpv4/icmpv4.pro
include ./ipv4/ipv4.pro
include ./ipv6/ipv6.pro
include ./mac/mac.pro
include ./udp/udp.pro
