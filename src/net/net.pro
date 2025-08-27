# =============================================================================
# Authors:
#   Guy Eschemann, Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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

analyze ./arp/arp_IPPool.vhdl
analyze ./arp/arp_BroadCast_Receiver.vhdl
analyze ./arp/arp_BroadCast_Requester.vhdl
analyze ./arp/arp_Cache.vhdl
analyze ./arp/arp_UniCast_Receiver.vhdl
analyze ./arp/arp_UniCast_Responder.vhdl
analyze ./arp/arp_Wrapper.vhdl

analyze ./icmpv4/icmpv4_RX.vhdl
analyze ./icmpv4/icmpv4_TX.vhdl
analyze ./icmpv4/icmpv4_Wrapper.vhdl
analyze ./ipv4/ipv4_FrameLoopback.vhdl
analyze ./ipv4/ipv4_RX.vhdl
analyze ./ipv4/ipv4_TX.vhdl
analyze ./ipv4/ipv4_Wrapper.vhdl
analyze ./ipv6/ipv6_FrameLoopback.vhdl
analyze ./ipv6/ipv6_RX.vhdl
analyze ./ipv6/ipv6_TX.vhdl
analyze ./ipv6/ipv6_Wrapper.vhdl
analyze ./mac/mac_TX_Type_Prepender.vhdl
analyze ./mac/mac_FrameLoopback.vhdl
analyze ./mac/mac_RX_DestMAC_Switch.vhdl
analyze ./mac/mac_RX_SrcMAC_Filter.vhdl
analyze ./mac/mac_RX_Type_Switch.vhdl
analyze ./mac/mac_TX_DestMAC_Prepender.vhdl
analyze ./mac/mac_TX_SrcMAC_Prepender.vhdl
analyze ./mac/mac_Wrapper.vhdl
analyze ./net_FrameChecksum.vhdl
analyze ./udp/udp_FrameLoopback.vhdl
analyze ./udp/udp_RX.vhdl
analyze ./udp/udp_TX.vhdl
analyze ./udp/udp_Wrapper.vhdl

