-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Generic AXI4-Lite register
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use	    IEEE.std_logic_1164.all;
use	    IEEE.numeric_std.all;

use	    work.utils.all;
use	    work.vectors.all;
use	    work.axi4lite.all;


entity AXI4Lite_Register is
	generic (
	 	CONFIG        : T_AXI4_Register_Description_Vector
	);
	port (
		S_AXI_ACLK              : in  std_logic;
		S_AXI_ARESETN           : in  std_logic;
		
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M;
		
		RegisterFile_ReadPort   : out T_SLVV(0 to CONFIG'Length - 1);
		RegisterFile_WritePort  : in  T_SLVV(0 to CONFIG'Length - 1)
	);
end entity;


architecture rtl of AXI4Lite_Register is
	constant ADDRESS_BITS  : positive := S_AXI_m2s.AWAddr'length;
	constant DATA_BITS     : positive := S_AXI_m2s.WData'length;
	
	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB   : positive  := log2ceil(DATA_BITS) - 3;
	
	-- AXI4LITE signals
	signal axi_awaddr   : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0)  := (others => '0');
	signal axi_awready  : std_logic := '0';
	signal axi_wready   : std_logic := '0';
	signal axi_bresp    : std_logic_vector(1 downto 0)  := "00";
	signal axi_bvalid   : std_logic := '0';
	signal axi_araddr   : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0) := (others => '0');
	signal axi_arready  : std_logic := '0';
	signal axi_rdata    : std_logic_vector(DATA_BITS - 1 downto 0)               := (others => '0');
	signal axi_rresp    : std_logic_vector(1 downto 0)  := "00";
	signal axi_rvalid   : std_logic := '0';

	function Register_init(Config : T_AXI4_Register_Description_Vector) return T_SLVV is
		variable Result : T_SLVV(0 to Config'Length - 1)(DATA_BITS - 1 downto 0);
	begin
		for i in 0 to Config'Length - 1 loop
			Result(i) := Config(i).init_value;
		end loop;
		return Result;
	end function;

	signal RegisterFile : T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0) := Register_init(CONFIG);
	
	signal slv_reg_rden : std_logic;
	signal slv_reg_wren : std_logic;
	signal reg_data_out : std_logic_vector(DATA_BITS - 1 downto 0);
	
begin
	S_AXI_s2m.AWReady <= axi_awready;
	S_AXI_s2m.WReady  <= axi_wready; 
	S_AXI_s2m.BResp   <= axi_bresp;  
	S_AXI_s2m.BValid  <= axi_bvalid; 
	S_AXI_s2m.ARReady <= axi_arready;
	S_AXI_s2m.RData   <= axi_rdata;  
	S_AXI_s2m.RResp   <= axi_rresp;  
	S_AXI_s2m.RValid  <= axi_rvalid; 
   
	-------- WRITE TRANSACTION DEPENDECIES --------
	
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_awready <= '0';
				axi_awaddr <= (others => '0');
			elsif (axi_awready = '0' and S_AXI_m2s.AWValid = '1' and S_AXI_m2s.WValid = '1') then
				axi_awready <= '1';
				-- Write Address latching
				axi_awaddr <= S_AXI_m2s.AWAddr(S_AXI_m2s.AWAddr'high downto ADDR_LSB);
			else
				axi_awready <= '0';
			end if;
		end if;
	end process;

	
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_wready <= '0';
			elsif (axi_wready = '0' and S_AXI_m2s.AWValid = '1' and S_AXI_m2s.WValid = '1') then
				axi_wready <= '1';
			else
				axi_wready <= '0';
			end if;
		end if;
	end process;
	
	process(S_AXI_ACLK)
		variable trunc_addr : std_logic_vector(CONFIG(0).address'range);
	begin
		if rising_edge(S_AXI_ACLK) then
			if ((S_AXI_ARESETN = '0')) then
				-- RegisterFile <= Register_init(CONFIG);
			else
				if (slv_reg_wren = '1') then
					for i in CONFIG'range loop
							trunc_addr := std_logic_vector(CONFIG(i).address);
						if ((axi_awaddr = trunc_addr(CONFIG(i).address'length - 1 downto ADDR_LSB)) and (CONFIG(i).writeable)) then -- found fitting register and it is writable
							for ii in S_AXI_m2s.WStrb'reverse_range loop
								-- Respective byte enables are asserted as per write strobes
								if (S_AXI_m2s.WStrb(ii) = '1' ) then
									RegisterFile(i)(ii * 8 + 7 downto ii * 8) <= S_AXI_m2s.WData(8 * ii + 7 downto 8 * ii);
								end if;
							end loop;
						end if;
					end loop;
				else
					--clear where needed, otherwise latch
					for i in CONFIG'range loop
						RegisterFile(i) <= RegisterFile(i) and (not CONFIG(i).Auto_Clear_Mask);  
					end loop;
				end if;
			end if;
		end if;
	end process;
	
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_bvalid  <= '0';
				axi_bresp   <= C_AXI4_RESPONSE_OKAY;
			else
				if (axi_bvalid = '0' and axi_awready = '1' and axi_wready = '1' and S_AXI_m2s.WValid = '1' and S_AXI_m2s.AWValid = '1') then
					axi_bvalid  <= '1';
					axi_bresp   <= C_AXI4_RESPONSE_OKAY;
				elsif (S_AXI_m2s.BReady = '1' and axi_bvalid = '1') then
					axi_bvalid <= '0';
				end if;
			end if;
		end if;
	end process;
	
	slv_reg_wren <= axi_wready and axi_awready and S_AXI_m2s.AWValid and S_AXI_m2s.WValid;
	
	RegisterFile_ReadPort <= RegisterFile;
	
	-------- READ TRANSACTION DEPENDECIES --------
	
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_arready <= '0';
				axi_araddr  <= (others => '1');
			elsif (axi_arready = '0' and S_AXI_m2s.ARValid = '1') then
				axi_arready <= '1';
				axi_araddr  <= S_AXI_m2s.ARAddr(S_AXI_m2s.ARAddr'high downto ADDR_LSB);
			else
				axi_arready <= '0';
			end if;
		end if;
	end process;
	
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_rvalid <= '0';
				axi_rresp  <= C_AXI4_RESPONSE_OKAY;
			elsif (axi_rvalid = '0' and S_AXI_m2s.ARValid = '1' and axi_arready = '1') then
				axi_rvalid <= '1';
				axi_rresp  <= C_AXI4_RESPONSE_OKAY;
			else
				axi_rvalid <= '0';
			end if;
		end if;
	end process;
	
	slv_reg_rden <=  S_AXI_m2s.ARValid and axi_arready and (not axi_rvalid);   


	blockReadMux: block
		signal mux : T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
		signal hit : std_logic_vector(CONFIG'Length - 1 downto 0);
	begin
		--only wire out register if read only
		genMux: for i in CONFIG'range generate
			genPort: if (not(CONFIG(i).writeable)) generate 
				mux(i) <= RegisterFile_WritePort(i);
			else generate
				mux(i) <= RegisterFile(i);
			end generate;
		end generate;

		hit_gen : for i in hit'range generate
			signal config_addr : unsigned(axi_araddr'range);
		begin
			config_addr <= CONFIG(i).address(config_addr'high + ADDR_LSB downto ADDR_LSB);
			hit(i) <= '1' when std_logic_vector(config_addr) = axi_araddr else '0';
		end generate;

		process(mux, hit)
			variable trunc_addr : std_logic_vector(CONFIG(0).address'range);
		begin
			reg_data_out  <= (others => '0');
			if unsigned(hit) /= 0 then
				reg_data_out <= mux(lssb_idx(hit));
			end if;
		end process;
		
	end block;

		-- Output register or memory read data
	process(S_AXI_ACLK) is
	begin
		if (rising_edge (S_AXI_ACLK)) then
			if  (S_AXI_ARESETN = '0')  then
				axi_rdata  <= (others => '0');
			elsif (slv_reg_rden = '1') then
				-- When there is a valid read address (S_AXI_m2s.ARValid) with 
				-- acceptance of read address by the slave (axi_arready), 
				-- output the read data 
				-- Read address mux

				axi_rdata <= reg_data_out;  -- register read data
			end if;
		end if;
	end process;  
	
end architecture;
