--
-- Copyright (c) 2008
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair of VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Package: is61lv
-- Author(s): Martin Zabel
--
-- Package for IS61LV Asynchronous SRAM
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-19 14:23:19 $
--

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

package is61lv is
	component is61lv_ctrl
		generic (
			A_BITS   : positive;
			D_BITS   : positive;
			CE_CNT   : positive;
			BE_CNT   : positive;
			SDIN_REG : boolean);
		port (
			clk       : in    std_logic;
			rst       : in    std_logic;
			req       : in    std_logic;
			write     : in    std_logic;
			be        : in    std_logic_vector(BE_CNT-1 downto 0);
			addr      : in    unsigned(A_BITS-1 downto 0);
			wdata     : in    std_logic_vector(D_BITS-1 downto 0);
			rdy       : out   std_logic;
			rstb      : out   std_logic;
			rdata     : out   std_logic_vector(D_BITS-1 downto 0);
			sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
			sram_be_n : out   std_logic_vector(BE_CNT-1 downto 0);
			sram_oe_n : out   std_logic;
			sram_we_n : out   std_logic;
			sram_addr : out   unsigned(A_BITS-1 downto 0);
			sram_data : inout std_logic_vector(D_BITS-1 downto 0));
	end component;

	component is61lv_ctrl_wb
		generic (
			WA_BITS  : positive;
			BA_BITS  : positive;
			D_BITS   : positive;
			CE_CNT   : positive;
			SDIN_REG : boolean);
		port (
			clk       : in    std_logic;
			rst       : in    std_logic;
			wb_cyc_i  : in    std_logic;
			wb_stb_i  : in    std_logic;
			wb_sel_i  : in    std_logic_vector((2**BA_BITS)-1 downto 0);
			wb_we_i   : in    std_logic;
			wb_adr_i  : in    std_logic_vector((WA_BITS+BA_BITS)-1 downto BA_BITS);
			wb_dat_i  : in    std_logic_vector(D_BITS-1 downto 0);
			wb_ack_o  : out   std_logic;
			wb_dat_o  : out   std_logic_vector(D_BITS-1 downto 0);
			sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
			sram_be_n : out   std_logic_vector((2**BA_BITS)-1 downto 0);
			sram_oe_n : out   std_logic;
			sram_we_n : out   std_logic;
			sram_addr : out   unsigned(WA_BITS-1 downto 0);
			sram_data : inout std_logic_vector(D_BITS-1 downto 0));
	end component;

end package;
