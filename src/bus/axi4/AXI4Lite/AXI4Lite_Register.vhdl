-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                          Jonas Schreiner
--                          Patrick Lehmann
--                          Asif Iqbal
--                          Max Kraft-Kugler
--
-- Entity:                  AXI4Lite_Register
--
-- Description:
-- -------------------------------------
-- A generic AXI4Liter-Register implementation.
-- It has support for 32-bit and 64-bit AXI4Lite data-width and up to 32-bit
-- address-witdh. To get a 64-bit register, simply connect a 64-bit bus. Two
-- 32-bit registers will be combined together to one 64-bit register.
--
-- The registers can be described with the CONFIG generic. Use the function
-- to_AXI4_Register to describe a single 32-bit register. For a description of
-- all features, see the full documentation.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.strings.all;
use     work.axi4lite.all;


entity AXI4Lite_Register is
	generic (
		CONFIG                            : T_AXI4_Register_Vector;                          -- Register configuration
		INTERRUPT_IS_STROBE               : boolean         := true;                         -- If set to true, generates a strobe for an interrupt, on false, generate level interrupt
		INTERRUPT_ENABLE_REGISTER_ADDRESS : unsigned        := (31 downto 0 => 32x"0");      -- Address of the interrupt-enable-register, ignored if no interrupt register defined in config
		INTERRUPT_MATCH_REGISTER_ADDRESS  : unsigned        := (31 downto 0 => 32x"4");      -- Address of the interrupt-match-register, ignored if no interrupt register defined in config
		INIT_ON_RESET                     : boolean         := true;                         -- If set to true, registers are initialized with INIT_VALUE of config when Reset is applied, if false, to Reset is connected. If init value is not important, this can save number of control-sets and eases routing
		IGNORE_HIGH_ADDRESS               : boolean         := true;                         -- Disables the High-Address Check. If the Base-Address of the whole register can be ignored, leave as true, otherwhise, the addresses in the config need be set with base-address
		RESPONSE_ON_ERROR                 : T_AXI4_Response := C_AXI4_RESPONSE_DECODE_ERROR; -- If not address matches then config of the AXI4Lite transaction, return this code
		DISABLE_ADDRESS_CHECK             : boolean         := false;                        -- If set to true, disable the address-check of the config structure. If the config is valid and has no overlapping addresses, can be set to false to save synthesis time for large registers
		DEBUG                             : boolean         := false                         -- Enables debug synthesis logs and sets important signals as mark_debug for simple in-hardware debugging
	);
	port (
		Clock                             : in  std_logic;
		Reset                             : in  std_logic;

		AXI4Lite_m2s                      : in  T_AXI4Lite_BUS_M2S;
		AXI4Lite_s2m                      : out T_AXI4Lite_BUS_S2M;
		AXI4Lite_IRQ                      : out std_logic := '0';

		RegisterFile_ReadPort             : out T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
		RegisterFile_ReadPort_hit         : out std_logic_vector(0 to CONFIG'Length - 1);
		RegisterFile_WritePort            : in  T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
		RegisterFile_WritePort_hit        : out std_logic_vector(0 to CONFIG'Length - 1);
		RegisterFile_WritePort_strobe     : in  std_logic_vector(0 to CONFIG'Length - 1) := get_strobeVector(CONFIG)
	);
	attribute MARK_DEBUG : string;
	attribute mark_debug of AXI4Lite_IRQ     : signal is to_string(DEBUG);
end entity;


architecture rtl of AXI4Lite_Register is
	constant Assert_prefix              : string   := "PoC.Axi4LiteRegister";
	constant ADDRESS_BITS               : positive := AXI4Lite_m2s.AWAddr'length;
	constant DATA_BITS                  : positive := AXI4Lite_m2s.WData'length;
	constant DATA_BITS_intern           : positive := 32;
	constant MODE_64bit                 : boolean  := DATA_BITS = 64;

	constant NUMBER_INTERRUPT_REGISTERS : natural  := get_Interrupt_count(CONFIG);
	constant ENABLE_INTERRUPT           : boolean  := NUMBER_INTERRUPT_REGISTERS > 0;

	constant Interrupt_EN_Reg           : T_AXI4_Register := to_AXI4_Register(
		Name         => "Interrupt_Enable_Register",
		Address      => INTERRUPT_ENABLE_REGISTER_ADDRESS,
		RegisterMode => ReadWrite,
		Init_Value   => (others => '0')
	);

	constant Interrupt_Match_Reg        : T_AXI4_Register := to_AXI4_Register(
		Name         => "Interrupt_Match_Register",
		Address      => INTERRUPT_MATCH_REGISTER_ADDRESS,
		RegisterMode => ReadOnly_NotRegistered,
		Init_Value   => (others => '0'),
		IsInterruptRegister => false
	);

	function gen_config return T_AXI4_Register_Vector is
		variable temp : T_AXI4_Register_Vector(0 to CONFIG'length + 1);
	begin
		temp(0 to Config'length - 1) := CONFIG;
		temp(Config'length)          := Interrupt_EN_Reg;
		temp(Config'length + 1)      := Interrupt_Match_Reg;
		if ENABLE_INTERRUPT then
			return temp;
		end if;
		return temp(0 to CONFIG'length - 1);
	end function;

	constant CONFIG_i                   : T_AXI4_Register_Vector := gen_config;

	constant Interrupt_range            : T_NATVEC := get_Interrupt_range(CONFIG_i);

	--Highest bit is for Reason Register
	signal   Is_Interrupt               : std_logic_vector(0 to NUMBER_INTERRUPT_REGISTERS - 1);
	signal   Is_Interrupt_d             : std_logic_vector(0 to NUMBER_INTERRUPT_REGISTERS - 1) := (others => '0');
	signal   Is_Interrupt_re            : std_logic_vector(0 to NUMBER_INTERRUPT_REGISTERS - 1);

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB           : positive := log2ceil(DATA_BITS_intern) - 3;
	constant REG_ADDRESS_BITS_f : positive := get_RegisterAddressBits(CONFIG_i);
	constant REG_ADDRESS_BITS   : positive := ite(REG_ADDRESS_BITS_f < ADDR_LSB, ADDR_LSB, REG_ADDRESS_BITS_f);

	function check_for_ADDR_conflicts return boolean is
		variable addr : unsigned(REG_ADDRESS_BITS downto ADDR_LSB);
	begin
		if not DISABLE_ADDRESS_CHECK then
			for i in CONFIG_i'low to CONFIG_i'high - 1 loop
				addr := CONFIG_i(i).Address(addr'range);
				for ii in i + 1 to CONFIG_i'high loop
					if addr = CONFIG_i(ii).Address(addr'range) then
						report "PoC.AXI4Lite_Register Error: Address conflict (0x" & to_hstring(addr) & ") between: CONFIG(" & integer'image(i) & ")=" & CONFIG_i(i).Name & " and CONFIG(" & integer'image(ii) & ")=" & CONFIG_i(ii).Name & " are equal!" severity failure;
						return false;
					end if;
				end loop;
			end loop;
		end if;
		return true;
	end function;

	function print_CONFIG return string is
	begin
		for i in CONFIG_i'range loop
			report "CONFIG(" & resize(integer'image(i), 2, ' ') & "):" & to_string(CONFIG_i(i)) severity note;
--			report to_string(CONFIG_i(i)) severity note;
		end loop;
		return "-";
	end function;

	-- AXI4LITE signals
	signal axi_awaddr    : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0) := (others => '0');
	signal axi_awready   : std_logic                                              := '0';
	signal axi_wready    : std_logic                                              := '0';
	signal axi_bresp     : std_logic_vector(1 downto 0)                           := "00";
	signal axi_bvalid    : std_logic                                              := '0';
	signal axi_araddr    : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0) := (others => '0');
	signal axi_arready   : std_logic                                              := '0';
	signal axi_rdata     : std_logic_vector(DATA_BITS - 1 downto 0)               := (others => '0');
	signal axi_rdata_mux : T_SLVV(0 to CONFIG_i'Length - 1)(DATA_BITS_intern - 1 downto 0);
	signal axi_rresp     : std_logic_vector(1 downto 0)                           := "00";
	signal axi_rvalid    : std_logic                                              := '0';


	signal hit_r        : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal hit_r_1      : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal is_high_r    : std_logic;
	signal is_address_w : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal hit_w        : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal hit_w_1      : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal is_high_w    : std_logic;

	function Register_init(CONFIG_i : T_AXI4_Register_Vector) return T_SLVV is
		variable Result : T_SLVV(0 to CONFIG_i'Length - 1)(DATA_BITS_intern - 1 downto 0);
	begin
		for i in 0 to CONFIG_i'Length - 1 loop
			Result(i) := CONFIG_i(i).init_value;
		end loop;
		return Result;
	end function;

	signal RegisterFile : T_SLVV(0 to CONFIG_i'Length - 1)(DATA_BITS_intern - 1 downto 0) := Register_init(CONFIG_i);

	signal slv_reg_rden    : std_logic;
	signal slv_reg_rden_d  : std_logic := '0';
	signal slv_reg_rden_re : std_logic;
	signal slv_reg_wren    : std_logic;

	signal latched           : std_logic_vector(0 to CONFIG_i'Length - 1) := (others => '0');
	signal clear_latch_w     : std_logic_vector(0 to CONFIG_i'Length - 1);
	signal clear_latch_r     : std_logic_vector(0 to CONFIG_i'Length - 1);

	signal outstanding_read  : std_logic := '0';

	attribute mark_debug of hit_r          : signal is to_string(DEBUG);
	attribute mark_debug of hit_w          : signal is to_string(DEBUG);
	attribute mark_debug of hit_r_1        : signal is to_string(DEBUG);
	attribute mark_debug of hit_w_1        : signal is to_string(DEBUG);
	attribute mark_debug of axi_awaddr     : signal is to_string(DEBUG);
	attribute mark_debug of axi_araddr     : signal is to_string(DEBUG);
	attribute mark_debug of Is_Interrupt   : signal is to_string(DEBUG);
begin
	assert not DEBUG report "========================== " & Assert_prefix & " ==========================" severity note;
	assert not DEBUG report "ADDR_LSB          = " & integer'image(ADDR_LSB)         severity note;
	assert not DEBUG report "ADDRESS_BITS      = " & integer'image(ADDRESS_BITS)     severity note;
	assert not DEBUG report "REG_ADDRESS_BITS  = " & integer'image(REG_ADDRESS_BITS) severity note;
	assert not DEBUG report "Number of Configs = " & integer'image(CONFIG_i'length)    severity note;
	assert not DEBUG report print_CONFIG severity note;
	assert not DEBUG report "=================== END of  & Assert_prefix &  ==========================" severity note;

	assert ADDRESS_BITS >= REG_ADDRESS_BITS report Assert_prefix & " Error:: Connected AXI4Lite Bus has not enough Address-Bits to address all Register-Spaces!" severity failure;
	assert check_for_ADDR_conflicts         report Assert_prefix & " Error:: Addressconflict in Config!" severity failure;
	assert not DISABLE_ADDRESS_CHECK        report Assert_prefix & ":: Address-Check is Disabled!" severity warning;
	assert not IGNORE_HIGH_ADDRESS          report Assert_prefix & ":: High Address Bits are Ignored! This can cause overlapping of Registers!" severity warning;

	assert DATA_BITS = 32 or DATA_BITS = 64 report Assert_prefix & ":: DATA_BITS = " & integer'image(DATA_BITS) & ", only 32 or 64 bit is supported!" severity failure;
	assert DATA_BITS /= 64                  report Assert_prefix & ":: Using experimental 64-bit Mode!" severity warning;

	AXI4Lite_s2m.AWReady <= axi_awready;
	AXI4Lite_s2m.WReady  <= axi_wready;
	AXI4Lite_s2m.BResp   <= axi_bresp;
	AXI4Lite_s2m.BValid  <= axi_bvalid;
	AXI4Lite_s2m.ARReady <= axi_arready;
	AXI4Lite_s2m.RData   <= axi_rdata;
	AXI4Lite_s2m.RResp   <= axi_rresp;
	AXI4Lite_s2m.RValid  <= axi_rvalid;

	-------- WRITE TRANSACTION DEPENDECIES --------
	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				axi_awready <= '0';
				axi_awaddr <= (others => '0');
			elsif (axi_awready = '0' and AXI4Lite_m2s.AWValid = '1' and AXI4Lite_m2s.WValid = '1') then
				axi_awready <= '1';
				-- Write Address latching
				axi_awaddr <= AXI4Lite_m2s.AWAddr(AXI4Lite_m2s.AWAddr'high downto ADDR_LSB);
			else
				axi_awready <= '0';
			end if;
		end if;
	end process;

	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				axi_wready <= '0';
			elsif (axi_wready = '0' and AXI4Lite_m2s.AWValid = '1' and AXI4Lite_m2s.WValid = '1') then
				axi_wready <= '1';
			else
				axi_wready <= '0';
			end if;
		end if;
	end process;


	----------- RegisterFile write process ----------------
	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset = '1')) then
				if INIT_ON_RESET then
					RegisterFile <= Register_init(CONFIG_i);
				end if;
				latched      <= (others => '0');
			else
				for i in CONFIG_i'range loop
					--Latch Value Funktion
					case CONFIG_i(i).RegisterMode is
						when LatchValue_ClearOnWrite   | LatchValue_ClearOnRead   =>
							--latch value on change
							if(latched(i) = '0') and (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile_WritePort(i);
								if (RegisterFile_WritePort(i) /= RegisterFile(i)) then
									latched(i)      <= '1';
								end if;
							--clear on clear latch command
							elsif (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
								latched(i)      <= '0';
								RegisterFile(i) <= CONFIG_i(i).Init_Value;
							end if;

						when LatchHighBit_ClearOnWrite | LatchHighBit_ClearOnRead =>
							--latch '1' in Register
							if (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile(i) or RegisterFile_WritePort(i);
							end if;
							--clear on clear latch command
							if (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
								if (RegisterFile_WritePort_strobe(i) = '1') then
									RegisterFile(i) <= RegisterFile_WritePort(i);
								else
									RegisterFile(i) <= (others => '0');
								end if;
							end if;


						when LatchLowBit_ClearOnWrite  | LatchLowBit_ClearOnRead  =>
							--latch '0' in Register
							if (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile(i) and RegisterFile_WritePort(i);
							end if;
							--clear on clear latch command
							if (clear_latch_w(i) = '1') or (clear_latch_r(i) = '1') then
								if (RegisterFile_WritePort_strobe(i) = '1') then
									RegisterFile(i) <= RegisterFile_WritePort(i);
								else
									RegisterFile(i) <= (others => '1');
								end if;
							end if;

						when ReadWrite =>
							if i <= CONFIG'high then
								if (slv_reg_wren = '1') and (hit_w(i) = '1') then
									for ii in AXI4Lite_m2s.WStrb(3 downto 0)'range loop
										-- Respective byte enables are asserted as per write strobes
										if (AXI4Lite_m2s.WStrb(ii) = '1' ) then
											RegisterFile(i)(ii * 8 + 7 downto ii * 8) <= AXI4Lite_m2s.WData(8 * ii + 7 downto 8 * ii);
										end if;
									end loop;
								elsif (slv_reg_wren = '1') and (hit_w_1(i) = '1') and MODE_64bit then
									for ii in AXI4Lite_m2s.WStrb(7 downto 4)'range loop
										-- Respective byte enables are asserted as per write strobes
										if (AXI4Lite_m2s.WStrb(ii) = '1' ) then
											RegisterFile(i)((ii -4) * 8 + 7 downto (ii -4) * 8) <= AXI4Lite_m2s.WData(8 * ii + 7 downto 8 * ii);
										end if;
									end loop;
								elsif (RegisterFile_WritePort_strobe(i) = '1') then
									RegisterFile(i) <= RegisterFile_WritePort(i);
								else
									RegisterFile(i) <= RegisterFile(i) and (not CONFIG_i(i).AutoClear_Mask);
								end if;

							else  --Interrupt Enable Register
								if (hit_w(i) = '1') and (slv_reg_wren = '1') then
									for ii in AXI4Lite_m2s.WStrb(3 downto 0)'range loop
										-- Respective byte enables are asserted as per write strobes
										if (AXI4Lite_m2s.WStrb(ii) = '1' ) then
											RegisterFile(i)(ii * 8 + 7 downto ii * 8) <= AXI4Lite_m2s.WData(8 * ii + 7 downto 8 * ii);
										end if;
									end loop;
								end if;
							end if;

						when ReadOnly =>
							if (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile_WritePort(i);
							end if;

						when ReadOnly_NotRegistered =>  --only dummy, ReadOnly_NotRegistered will be connected via mux
							if i <= CONFIG'high then
								if (RegisterFile_WritePort_strobe(i) = '1') then
									RegisterFile(i) <= RegisterFile_WritePort(i);
								end if;
							end if;

						when ConstantValue => --only dummy, ConstantValue will be connected via mux
							if (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile_WritePort(i);
							end if;

						when ReadWrite_NotRegistered => --only dummy, ReadWrite_NotRegistered will be connected via mux
							if (RegisterFile_WritePort_strobe(i) = '1') then
								RegisterFile(i) <= RegisterFile_WritePort(i);
							end if;

						when others =>
							--Unsupported
							assert false report "AXI4Lite_Register::: RegisterMode : "
											& T_AXI4Lite_RegisterModes'image(CONFIG_i(i).RegisterMode)
											& " of Config(" & integer'image(i) & ") is not supported!" severity failure;
					end case;
				end loop;
			end if;
		end if;
	end process;


	------------- Write Response --------------
	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				axi_bvalid  <= '0';
				axi_bresp   <= C_AXI4_RESPONSE_OKAY;
			else
				if (axi_bvalid = '0' and slv_reg_wren = '1') then
					axi_bvalid  <= '1';
					axi_bresp   <= C_AXI4_RESPONSE_OKAY when unsigned(hit_w or hit_w_1) /= 0 else RESPONSE_ON_ERROR;
				elsif (AXI4Lite_m2s.BReady = '1' and axi_bvalid = '1') then
					axi_bvalid <= '0';
				end if;
			end if;
		end if;
	end process;

	--Write Signals
	slv_reg_wren <= axi_wready and axi_awready and AXI4Lite_m2s.AWValid and AXI4Lite_m2s.WValid;
	clear_latch_w <= slv_reg_wren and (hit_w or hit_w_1);

	RedPort_gen : for i in CONFIG'range generate
		RedPort_gen_i : if CONFIG_i(i).RegisterMode = ReadOnly_NotRegistered generate
			RegisterFile_ReadPort(i)     <= RegisterFile_WritePort(i);
			RegisterFile_ReadPort_hit(i) <= clear_latch_w(i) when rising_edge(Clock);

		elsif CONFIG_i(i).RegisterMode = ReadWrite_NotRegistered and not MODE_64bit generate
			RegisterFile_ReadPort(i)     <= AXI4Lite_m2s.WData;
			RegisterFile_ReadPort_hit(i) <= clear_latch_w(i);

		elsif CONFIG_i(i).RegisterMode = ReadWrite_NotRegistered and MODE_64bit generate
			RegisterFile_ReadPort(i)     <= AXI4Lite_m2s.WData(31 downto 0) when CONFIG_i(i).Address(ADDR_LSB) = '0' else AXI4Lite_m2s.WData(63 downto 32); -- Select if this is the lower or higher 32b register
			RegisterFile_ReadPort_hit(i) <= clear_latch_w(i);

		elsif CONFIG_i(i).RegisterMode = ConstantValue generate
			RegisterFile_ReadPort(i)     <= CONFIG_i(i).Init_Value;
			RegisterFile_ReadPort_hit(i) <= clear_latch_w(i) when rising_edge(Clock);

		else generate
			RegisterFile_ReadPort(i)     <= RegisterFile(i);
			RegisterFile_ReadPort_hit(i) <= clear_latch_w(i) when rising_edge(Clock);

		end generate;
	end generate;


	-------- READ TRANSACTION DEPENDECIES --------
	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				axi_arready <= '0';
				axi_araddr  <= (others => '1');
			elsif (axi_arready = '0' and AXI4Lite_m2s.ARValid = '1' and outstanding_read = '0') then
				axi_arready <= '1';
				axi_araddr  <= AXI4Lite_m2s.ARAddr(AXI4Lite_m2s.ARAddr'high downto ADDR_LSB);
			else
				axi_arready <= '0';
			end if;
		end if;
	end process;

	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				axi_rvalid <= '0';
				axi_rresp  <= C_AXI4_RESPONSE_OKAY;
			elsif slv_reg_rden = '1' then
				axi_rvalid <= '1';
				axi_rresp  <= C_AXI4_RESPONSE_OKAY when unsigned(hit_r) /= 0 else RESPONSE_ON_ERROR;
			elsif AXI4Lite_m2s.RReady = '1' then
				axi_rvalid <= '0';
			end if;
		end if;
	end process;

	--Read Signals
	outstanding_read           <= (outstanding_read or slv_reg_rden) and not (Reset or AXI4Lite_m2s.RReady) when rising_edge(Clock);
	slv_reg_rden               <= AXI4Lite_m2s.ARValid and axi_arready and (not axi_rvalid);
	slv_reg_rden_d             <= slv_reg_rden when rising_edge(Clock);
	slv_reg_rden_re            <= slv_reg_rden and not slv_reg_rden_d;
	RegisterFile_WritePort_hit <= slv_reg_rden_re and (hit_r(CONFIG'range) or hit_r_1(CONFIG'range));

	-- Output register or memory read data
	process(Clock) is
		function first_out(slv : std_logic_vector; reg : T_SLVV) return std_logic_vector is
		begin
			for i in slv'low to slv'high loop
				if (slv(i)) = '1' then
					return reg(i);
				end if;
			end loop;
			return reg(0);
		end function;
		function lssb_idx_with_loop(slv : std_logic_vector) return integer is
		begin
			for i in slv'low to slv'high loop
				if (slv(i)) = '1' then
					return i;
				end if;
			end loop;
			return 0;
		end function;
		variable idx : integer;
	begin
		if (rising_edge (Clock)) then
			idx := lssb_idx_with_loop(hit_r);
			if  (Reset = '1')  then
				axi_rdata  <= (others => '0');
			elsif (slv_reg_rden_re = '1') then
				-- When there is a valid read address (AXI4Lite_m2s.ARValid) with
				-- acceptance of read address by the slave (axi_arready),
				-- output the read data
				-- Read address mux

--				axi_rdata <= RegisterFile(lssb_idx(hit_r));
				axi_rdata(DATA_BITS_intern -1 downto 0) <= axi_rdata_mux(idx);
--				axi_rdata <= first_out(hit_r, RegisterFile);
--				rdata_mux : for i in hit_r'high downto hit_r'low loop
--					if (hit_r(i)) = '1' then
--						axi_rdata <= RegisterFile(i);
--						exit;
--					end if;
--				end loop;
				if MODE_64bit then
					if (idx + 1 <= hit_r_1'high) and (hit_r_1(idx + 1) = '1') then
						axi_rdata(axi_rdata'high downto DATA_BITS_intern) <= axi_rdata_mux(idx +1);
					else
						axi_rdata(axi_rdata'high downto DATA_BITS_intern) <= (others => '0');
					end if;
				end if;
			end if;
		end if;
	end process;

	read_mux_gen : for i in CONFIG_i'range generate
	begin
		read_mux_gen_i : if i = CONFIG_i'high and ENABLE_INTERRUPT generate
			axi_rdata_mux(i) <= reverse(resize(Is_Interrupt, DATA_BITS_intern));
	   elsif CONFIG_i(i).RegisterMode = ReadOnly_NotRegistered generate
			axi_rdata_mux(i) <= RegisterFile_WritePort(i);
		elsif CONFIG_i(i).RegisterMode = ReadWrite_NotRegistered generate
			axi_rdata_mux(i) <= RegisterFile_WritePort(i);
		elsif CONFIG_i(i).RegisterMode = ConstantValue generate
			axi_rdata_mux(i) <= CONFIG_i(i).Init_Value;
		else generate
			axi_rdata_mux(i) <= RegisterFile(i);
		end generate;
	end generate;


	------------ Address Hit's ---------------------------
	high_addr_gen : if (REG_ADDRESS_BITS >= ADDRESS_BITS) or (IGNORE_HIGH_ADDRESS = TRUE) generate
		is_high_r <= '1';
		is_high_w <= '1';
	else generate
		is_high_r <= '1' when axi_araddr(axi_araddr'high downto REG_ADDRESS_BITS - ADDR_LSB) = (axi_araddr'high downto REG_ADDRESS_BITS - ADDR_LSB => '0') else '0';
		is_high_w <= '1' when axi_awaddr(axi_awaddr'high downto REG_ADDRESS_BITS - ADDR_LSB) = (axi_awaddr'high downto REG_ADDRESS_BITS - ADDR_LSB => '0') else '0';
	end generate;


	hit_gen_r : for i in hit_r'range generate
		signal config_addr  : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		signal is_config    : std_logic;
	begin
		config_addr  <= CONFIG_i(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		is_config    <= '1' when std_logic_vector(config_addr) = axi_araddr(REG_ADDRESS_BITS - ADDR_LSB - 1 downto 0) else '0';
		hit_r(i)     <= '1' when (is_config = '1') and (is_high_r = '1') else '0';

		clear_latch_r(i)  <= slv_reg_rden_re and (hit_r(i) or hit_r_1(i)) and to_sl(
				(CONFIG_i(i).RegisterMode = LatchValue_ClearOnRead) or
				(CONFIG_i(i).RegisterMode = LatchHighBit_ClearOnRead) or
				(CONFIG_i(i).RegisterMode = LatchLowBit_ClearOnRead)
			);
	end generate;


	hit_gen_w : for i in hit_w'range generate
		constant config_addr : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB) := CONFIG_i(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB);
		constant is_config   : std_logic := to_sl(
												(CONFIG_i(i).RegisterMode = ReadWrite)
											or (CONFIG_i(i).RegisterMode = ReadWrite_NotRegistered)
											or (CONFIG_i(i).RegisterMode = LatchValue_ClearOnWrite)
											or (CONFIG_i(i).RegisterMode = LatchHighBit_ClearOnWrite)
											or (CONFIG_i(i).RegisterMode = LatchLowBit_ClearOnWrite)
											);
		signal is_address    : std_logic;
	begin
		is_address      <= is_high_w when std_logic_vector(config_addr) = axi_awaddr(REG_ADDRESS_BITS - ADDR_LSB - 1 downto 0) else '0';
		is_address_w(i) <= is_address;
		hit_w(i)        <= '1' when (is_address = '1') and (is_config = '1') else '0';

	end generate;

	Mode_64bit_gen : if MODE_64bit generate
		hit_w_1(0) <= '0';
		hit_r_1(0) <= '0';

		hit_gen_w : for i in 1 to is_address_w'high generate
			constant config_addr  : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB) := CONFIG_i(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB) -1;
			constant is_config    : std_logic := ite( config_addr  = CONFIG_i(i - 1).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB)
														and CONFIG_i(i - 1).Address(ADDR_LSB) = '0'               --Data aligned access
--														and (CONFIG_i(i).RegisterMode = CONFIG_i(i -1).RegisterMode)
														and (  (CONFIG_i(i).RegisterMode = ReadWrite)
															or (CONFIG_i(i).RegisterMode = LatchValue_ClearOnWrite)
															or (CONFIG_i(i).RegisterMode = LatchHighBit_ClearOnWrite)
															or (CONFIG_i(i).RegisterMode = LatchLowBit_ClearOnWrite))
														, '1', '0');
		begin
			assert (is_config /= '1' or not DEBUG)
			  report Assert_prefix & ":: Creating 64bit-Write-Register for Config(" & integer'image(i) & ") and Config(" & integer'image(i - 1) & ")"
			  severity note;
			hit_w_1(i)  <= is_address_w(i -1) when (is_config = '1') else '0';
		end generate;

		hit_gen_r : for i in 1 to hit_r'high generate
			constant config_addr  : unsigned(REG_ADDRESS_BITS - 1 downto ADDR_LSB) := CONFIG_i(i).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB) -1;
			constant is_config    : std_logic := ite( config_addr  = CONFIG_i(i - 1).Address(REG_ADDRESS_BITS - 1 downto ADDR_LSB)
														and CONFIG_i(i - 1).Address(ADDR_LSB) = '0'               --Data aligned access
														, '1', '0');
		begin
			assert (is_config /= '1' or not DEBUG)
				report Assert_prefix & ":: Creating 64bit-Read-Register for Config(" & integer'image(i) & ") and Config(" & integer'image(i -1) & ")"
				severity note;
			hit_r_1(i)   <= hit_r(i - 1) when (is_config = '1') else '0';
		end generate;
	else generate
		hit_w_1 <= (others => '0');
		hit_r_1 <= (others => '0');
	end generate;

	-- WORKAROUND: for Xilinx Vivado
	--	Version:	Last tested 2018.3
	--	Issue:		Null range in generate loop not correctly handled
	--	Solution:	Add another if generate around the generate loop
	Interrupt_Count : if ENABLE_INTERRUPT generate
		Interrupt_gen : for i in Is_Interrupt'range generate
			constant num : natural := Interrupt_range(i);
		begin
			process(all)
			begin
				case CONFIG_i(num).RegisterMode is
					when LatchValue_ClearOnRead | LatchValue_ClearOnWrite =>
						Is_Interrupt(i) <= latched(num) and RegisterFile(CONFIG'high + 1)(i) and not (clear_latch_w(num) or clear_latch_r(num));

					when LatchHighBit_ClearOnRead | LatchHighBit_ClearOnWrite =>
						Is_Interrupt(i) <= slv_or(RegisterFile(num)) and RegisterFile(CONFIG'high + 1)(i) and not (clear_latch_w(num) or clear_latch_r(num));

					when LatchLowBit_ClearOnRead | LatchLowBit_ClearOnWrite =>
						Is_Interrupt(i) <= not slv_and(RegisterFile(num)) and RegisterFile(CONFIG'high + 1)(i) and not (clear_latch_w(num) or clear_latch_r(num));

					when ReadOnly =>
						Is_Interrupt(i) <= slv_or(RegisterFile(num)) and RegisterFile(CONFIG'high + 1)(i) and not (slv_reg_rden_re and (hit_r(num) or hit_r_1(num)));

					when ReadOnly_NotRegistered =>
						Is_Interrupt(i) <= slv_or(RegisterFile_WritePort(num)) and RegisterFile(CONFIG'high + 1)(i) and not (slv_reg_rden_re and (hit_r(num) or hit_r_1(num)));

					when others =>
						assert false report "AXI4Lite_Register::: Interrupt_gen : IRQ Register for type " & T_AXI4Lite_RegisterModes'image(CONFIG_i(num).RegisterMode) & " is not possible!" severity failure;

				end case;
			end process;
		end generate;

		Is_Interrupt_d  <= Is_Interrupt when rising_edge(Clock);
		Is_Interrupt_re <= Is_Interrupt and not Is_Interrupt_d;

		AXI4Lite_IRQ <= or(Is_Interrupt_re) when INTERRUPT_IS_STROBE else or(Is_Interrupt);

	else generate

		AXI4Lite_IRQ <= '0';
	end generate;

end architecture;
