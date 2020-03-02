-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:                 Max Kraft-Kugler
--                          Stefan Unrein
--                          Patrick Lehmann
--                          Asif Iqbal
--
-- Package:                 TBD
--
-- Description:
-- -------------------------------------
--      For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2017-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.iic.all;


entity iic_IOB_Pad is
	port (
		enable         : in    std_logic := '1';
		iic_pad        : inout T_IO_IIC_SERIAL_PAD;
		iic_fabric_m2s : in    T_IO_IIC_SERIAL_OUT;
		iic_fabric_s2m : out   T_IO_IIC_SERIAL_IN
	);
end entity;

architecture RTL of iic_IOB_Pad is
	signal internal_iic_in  : T_IO_IIC_SERIAL_IN;
	signal internal_iic_out : T_IO_IIC_SERIAL_OUT;

begin
	
	iic_fabric_s2m.Clock <= internal_iic_in.Clock;
	iic_fabric_s2m.Data  <= internal_iic_in.Data;
	-- let tristate through only when enabled, otherwise keep in receiving state (eq. 'Z')
	internal_iic_out.Clock_o <= iic_fabric_m2s.Clock_o;
	internal_iic_out.Clock_t <= iic_fabric_m2s.Clock_t  when enable = '1' else '1';
	internal_iic_out.Data_o  <= iic_fabric_m2s.Data_o;
	internal_iic_out.Data_t  <= iic_fabric_m2s.Data_t  when enable = '1' else '1';

	-- instatiate IOBs
	SerialData: IOBUF
		port map (
			I  => internal_iic_out.Data_o,
			T  => internal_iic_out.Data_t,
			O  => MIPI_RX_I2C_in(interface_nr - A2_MIPI_RX_MFP'low).Data,
			IO => iic_pad.Data
		);
	SerialClock: IOBUF
		port map (
			I  => internal_iic_out.Clock_o,
			T  => internal_iic_out.Clock_t,
			O  => internal_iic_in.Clock,
			IO => iic_pad.Clock
		);

end architecture;
