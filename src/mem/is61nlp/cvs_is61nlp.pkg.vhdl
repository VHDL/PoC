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
-- Package: is61nlp
-- Author(s): Martin Zabel
--
-- Package for IS61NLP ZBT Synchronous SRAM.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-19 14:56:47 $
--

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

package is61nlp is
	component is61nlp_ctrl
		generic (
			A_BITS   : positive;
			D_BITS   : positive;
			CE_CNT   : positive;
			BW_CNT   : positive;
			SDIN_REG : boolean);
		port (
			rst       : in    std_logic;
			clk       : in    std_logic;
			req       : in    std_logic;
			write     : in    std_logic;
			bw        : in    std_logic_vector(BW_CNT-1 downto 0);
			addr      : in    unsigned(A_BITS-1 downto 0);
			wdata     : in    std_logic_vector(D_BITS-1 downto 0);
			rstb      : out   std_logic;
			rdata     : out   std_logic_vector(D_BITS-1 downto 0);
			sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
			sram_mode : out   std_logic;
			sram_bw_n : out   std_logic_vector(BW_CNT-1 downto 0);
			sram_addr : out   unsigned(A_BITS-1 downto 0);
			sram_we_n : out   std_logic;
			sram_adv  : out   std_logic;
			sram_oe_n : out   std_logic;
			sram_data : inout std_logic_vector(D_BITS-1 downto 0));
	end component;

	component is61nlp_ctrl_wb
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
			sram_mode : out   std_logic;
			sram_bw_n : out   std_logic_vector((2**BA_BITS)-1 downto 0);
			sram_addr : out   unsigned(WA_BITS-1 downto 0);
			sram_we_n : out   std_logic;
			sram_adv  : out   std_logic;
			sram_oe_n : out   std_logic;
			sram_data : inout std_logic_vector(D_BITS-1 downto 0));
	end component;

end package;
