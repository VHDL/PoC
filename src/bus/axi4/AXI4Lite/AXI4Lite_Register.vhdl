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
		DEBUG                         : boolean := false;
		IGNORE_HIGH_ADDR              : boolean := true;
	 	CONFIG                        : T_AXI4_Register_Description_Vector
	);
	port (
		S_AXI_ACLK                    : in  std_logic;
		S_AXI_ARESETN                 : in  std_logic;
		
		S_AXI_m2s                     : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m                     : out T_AXI4Lite_BUS_S2M;
		
		RegisterFile_ReadPort         : out T_SLVV(0 to CONFIG'Length - 1);
		RegisterFile_ReadPort_hit     : out std_logic_vector(0 to CONFIG'Length - 1);
		RegisterFile_WritePort        : in  T_SLVV(0 to CONFIG'Length - 1);
		RegisterFile_WritePort_hit    : out std_logic_vector(0 to CONFIG'Length - 1);
		RegisterFile_WritePort_strobe : in  std_logic_vector(0 to CONFIG'Length - 1) := get_strobeVector(CONFIG)
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
	
	constant REG_ADDRESS_BITS : positive := ite(get_RegisterAddressBits(CONFIG) < ADDR_LSB, ADDR_LSB, get_RegisterAddressBits(CONFIG));
	
	function check_for_ADDR_conflicts return boolean is
		variable addr : unsigned(REG_ADDRESS_BITS downto ADDR_LSB);
	begin
		for i in CONFIG'low to CONFIG'high -1 loop
			addr := CONFIG(i).address(addr'range);
			for ii in i +1 to CONFIG'high loop
				if addr = CONFIG(ii).address(addr'range) then
					report "AXI4Lite_Register Error: Addressconflict in Config: CONFIG(" & integer'image(i) & ") and CONFIG(" & integer'image(ii) & ") are equal!" severity failure;
					return false;
				end if;
			end loop;
		end loop;
		return true;
	end function;
	
	function print_CONFIG return string is
	begin
		for i in CONFIG'range loop
			report "CONFIG(" & integer'image(i) & "):" & to_string(CONFIG(i)) severity note;
--			report to_string(CONFIG(i)) severity note;
		end loop;
		return "-";
	end function;
	
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
	
	
	signal hit_r        : std_logic_vector(CONFIG'Length - 1 downto 0);
	signal hit_w        : std_logic_vector(CONFIG'Length - 1 downto 0);

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

	signal latched           : std_logic_vector(Config'Length-1 downto 0) := (others => '0');
	signal clear_latch_w     : std_logic_vector(Config'Length-1 downto 0);
	signal clear_latch_r     : std_logic_vector(Config'Length-1 downto 0);
	
	signal outstanding_read  : std_logic := '0';
	
begin
	assert ADDRESS_BITS >= REG_ADDRESS_BITS report "AXI4Lite_Register Error: Connected AXI4Lite Bus has not enough Address-Bits to address all Register-Spaces!" severity failure;
	assert check_for_ADDR_conflicts report "AXI4Lite_Register Error: Addressconflict in Config!" severity failure;
	assert not DEBUG report "========================== PoC.Axi4LiteRegister ==========================" severity note;
	assert not DEBUG report "ADDR_LSB          = " & integer'image(ADDR_LSB)         severity note;
	assert not DEBUG report "ADDRESS_BITS      = " & integer'image(ADDRESS_BITS)     severity note;
	assert not DEBUG report "REG_ADDRESS_BITS  = " & integer'image(REG_ADDRESS_BITS) severity note;
	assert not DEBUG report "Number of Configs = " & integer'image(Config'length)    severity note;
	assert not DEBUG report print_CONFIG severity note;
	assert not DEBUG report "=================== END of PoC.Axi4LiteRegister ==========================" severity note;

	
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
	
	
	----------- RegisterFile write process ----------------
	process(S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then
			if ((S_AXI_ARESETN = '0')) then
				RegisterFile <= Register_init(CONFIG);
				latched      <= (others => '0');
			else
				for i in CONFIG'range loop
					--Latch Value Funktion
					if ((CONFIG(i).rw_config = latchValue_clearOnWrite) or (CONFIG(i).rw_config = latchValue_clearOnRead)) then
						--latch value on change
						if(latched(i) = '0') and (RegisterFile_WritePort_strobe(i) = '1') then
							RegisterFile(i) <= RegisterFile_WritePort(i);
							if (RegisterFile_WritePort(i) /= RegisterFile(i)) then
								latched(i)      <= '1';
							end if;
						--clear on clear latch command
						elsif (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
							latched(i)      <= '0';
							RegisterFile(i) <= RegisterFile_WritePort(i);
						end if;
						
					--Latch High Bit Funktion
					elsif ((CONFIG(i).rw_config = latchHighBit_clearOnWrite) or (CONFIG(i).rw_config = latchHighBit_clearOnRead)) then
						--latch '1' in Register
						if (RegisterFile_WritePort_strobe(i) = '1') then
							RegisterFile(i) <= RegisterFile(i) or RegisterFile_WritePort(i);
						end if;
						--clear on clear latch command
						if (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
							RegisterFile(i) <= RegisterFile_WritePort(i);
						end if;
						
					--Latch Low Bit Funktion
					elsif ((CONFIG(i).rw_config = latchLowBit_clearOnWrite) or (CONFIG(i).rw_config = latchLowBit_clearOnRead)) then
						--latch '0' in Register
						if (RegisterFile_WritePort_strobe(i) = '1') then
							RegisterFile(i) <= RegisterFile(i) and RegisterFile_WritePort(i);
						end if;
						--clear on clear latch command
						if (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
							RegisterFile(i) <= RegisterFile_WritePort(i);
						end if;
						
					--Read-Write Register
					elsif (CONFIG(i).rw_config = readWriteable) then
						if (hit_w(i) = '1') and (slv_reg_wren = '1') then 
							for ii in S_AXI_m2s.WStrb'reverse_range loop
								-- Respective byte enables are asserted as per write strobes
								if (S_AXI_m2s.WStrb(ii) = '1' ) then
									RegisterFile(i)(ii * 8 + 7 downto ii * 8) <= S_AXI_m2s.WData(8 * ii + 7 downto 8 * ii);
								end if;
							end loop;
						elsif (RegisterFile_WritePort_strobe(i) = '1') then
							RegisterFile(i) <= RegisterFile_WritePort(i);
						else
							RegisterFile(i) <= RegisterFile(i) and (not CONFIG(i).Auto_Clear_Mask);
						end if;
						
					--Read-Only Register
					elsif (CONFIG(i).rw_config = readable) then --last else is read_only port
						if (RegisterFile_WritePort_strobe(i) = '1') then
							RegisterFile(i) <= RegisterFile_WritePort(i);
						end if;
						
					--Unsupported
					else
						assert false report "AXI4Lite_Register::: rw_config : " & T_ReadWrite_Config'image(CONFIG(i).rw_config) & " of Config(" & integer'image(i) & ") is not supported!" severity failure;
					end if;
				end loop;
			end if;
		end if;
	end process;
	
	
	------------- Write Response --------------
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_bvalid  <= '0';
				axi_bresp   <= C_AXI4_RESPONSE_OKAY;
			else
				if (axi_bvalid = '0' and slv_reg_wren = '1') then
					axi_bvalid  <= '1';
					axi_bresp   <= C_AXI4_RESPONSE_OKAY when unsigned(hit_w) /= 0 else C_AXI4_RESPONSE_DECODE_ERROR;
				elsif (S_AXI_m2s.BReady = '1' and axi_bvalid = '1') then
					axi_bvalid <= '0';
				end if;
			end if;
		end if;
	end process;
	
	--Write Signals
	slv_reg_wren <= axi_wready and axi_awready and S_AXI_m2s.AWValid and S_AXI_m2s.WValid;
	clear_latch_w <= slv_reg_wren and hit_w;
	RegisterFile_ReadPort     <= RegisterFile;
	
	
	-------- READ TRANSACTION DEPENDECIES --------
	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then 
			if (S_AXI_ARESETN = '0') then
				axi_arready <= '0';
				axi_araddr  <= (others => '1');
			elsif (axi_arready = '0' and S_AXI_m2s.ARValid = '1' and outstanding_read = '0') then
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
			elsif slv_reg_rden = '1' then
				axi_rvalid <= '1';
				axi_rresp  <= C_AXI4_RESPONSE_OKAY when unsigned(hit_r) /= 0 else C_AXI4_RESPONSE_DECODE_ERROR;
			elsif S_AXI_m2s.RReady = '1' then
				axi_rvalid <= '0';
			end if;
		end if;
	end process;
	
	--Read Signals
	outstanding_read <= (outstanding_read or slv_reg_rden) and not (not S_AXI_ARESETN or S_AXI_m2s.RReady) when rising_edge(S_AXI_ACLK);
	slv_reg_rden <=  S_AXI_m2s.ARValid and axi_arready and (not axi_rvalid);   
	RegisterFile_WritePort_hit <= slv_reg_rden and hit_r;
	clear_latch_r              <= slv_reg_rden and hit_r;

	blockReadMux: block
		signal mux : T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
	begin
		--only wire out register if read only
		genMux: for i in CONFIG'range generate
--			genPort: if (CONFIG(i).rw_config = readable) generate 
--				mux(i)              <= RegisterFile_WritePort(i);
--			elsif (CONFIG(i).rw_config = latchValue_clearOnRead) generate
--				mux(i)              <= RegisterFile(i);
--			else generate
				mux(i)              <= RegisterFile(i);
--			end generate;
		end generate;

		process(mux, hit_r)
			variable trunc_addr : std_logic_vector(CONFIG(0).address'range);
		begin
			reg_data_out  <= (others => '0');
			if unsigned(hit_r) /= 0 then
				reg_data_out <= mux(lssb_idx(hit_r));
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
	
	
	------------ Address Hit's ---------------------------
	hit_gen_r : for i in hit_r'range generate
		signal config_addr : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
	begin
		config_addr <= CONFIG(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		hit_r(i)    <= '1' when (std_logic_vector(config_addr) = axi_araddr(REG_ADDRESS_BITS - ADDR_LSB -1 downto 0))
												and ((unsigned(axi_araddr(axi_araddr'high downto REG_ADDRESS_BITS - ADDR_LSB)) = 0) or IGNORE_HIGH_ADDR)
												else '0';
	end generate;
		
	hit_gen_w : for i in hit_w'range generate
		signal config_addr : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		signal RegisterFile_ReadPort_hit_i : std_logic_vector(RegisterFile_ReadPort_hit'range):= (others => '0');
	begin
		RegisterFile_ReadPort_hit_i(i) <= slv_reg_wren when hit_w(i) = '1' and CONFIG(i).rw_config = readWriteable else '0';
		RegisterFile_ReadPort_hit(i)   <= RegisterFile_ReadPort_hit_i(i) when rising_edge(S_AXI_ACLK);
		config_addr <= CONFIG(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		hit_w(i)    <= '1' when (std_logic_vector(config_addr) = axi_awaddr(REG_ADDRESS_BITS - ADDR_LSB -1 downto 0))
												and ((unsigned(axi_awaddr(axi_awaddr'high downto REG_ADDRESS_BITS - ADDR_LSB)) = 0) or IGNORE_HIGH_ADDR)
												and ((CONFIG(i).rw_config = readWriteable) or (CONFIG(i).rw_config = latchValue_clearOnWrite) 
															or (CONFIG(i).rw_config = latchHighBit_clearOnWrite) or (CONFIG(i).rw_config = latchLowBit_clearOnWrite))
												else '0';
	end generate;
	
end architecture;
