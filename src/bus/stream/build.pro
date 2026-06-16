# =============================================================================
# Authors:
#	Adrian Weiland, Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

# analyze stream.pkg.vhdl
analyze stream_FIFO.vhdl
disabled stream_FIFO_tempput.vhdl
# analyze stream_Delay.vhdl                    ;  # already analyzed
# analyze stream_DeMux.vhdl                    ;  # already analyzed
disabled stream_fast_cutter.vhdl
disabled stream_fast_to_stream_adapter.vhd
analyze stream_FrameGenerator.vhdl
disabled stream_Frame_checker.vhdl
disabled stream_Stage.vhdl
disabled stream_Stage_vector.vhdl
analyze stream_Mirror.vhdl
# analyze stream_Mux.vhdl                        ;  # already analyzed
disabled stream_PacketGenerator.vhdl
disabled stream_Padder.vhdl
analyze stream_Source.vhdl
disabled stream_Statistics.vhdl
disabled stream_to_stream_fast_adapter.vhd

disabled stream_utils.pkg.vhdl
disabled stream_Presplitter.vhdl
disabled stream_Prepender.vhdl
disabled generic_fast_appender.vhdl
disabled generic_fast_post_splitter.vhdl
disabled generic_fast_pre_splitter.vhdl
