-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;


use work.config.all;
use work.xil.all;


entity misc_ClockBuffer is
	port (
		Clock_In      : in  std_logic;
		Clock_Enable  : in  std_logic := '1';
		Clock_Out     : out std_logic
	);
end entity;


architecture rtl of misc_ClockBuffer is
begin
	buf_gen : if VENDOR = VENDOR_XILINX generate
		Buf : component xil_ClockBuffer
			port map (
				Clock_In      => Clock_In,
				Clock_Enable  => Clock_Enable,
				Clock_Out     => Clock_Out
			);
	else generate
		Clock_Out <= Clock_In when Clock_Enable = '1' else '0';
		assert false report "Buffer for Vendor '" & T_Vendor'image(Vendor) & "' not implemented yet. Using generic implementation." severity Note;
	end generate;
end architecture;
