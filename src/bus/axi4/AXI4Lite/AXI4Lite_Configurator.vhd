library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4Lite_Configurator is
    Generic (
      MAX_CONFIG  : natural         := 4;
      ADDRESS_BITS  : natural                 := 32;
      DATA_BITS     : natural                 := 32;
--      CONFIG        : T_AXI4_Register_Set_VECTOR  := (0 => to_AXI4_Register_Set((0 => Initialize_AXI4_register(32, 32, '0'))))
      CONFIG        : T_AXI4_Register_Set_VECTOR  := (
        0 => to_AXI4_Register_Set((
            0 => to_AXI4_Register(Address => to_unsigned(2,ADDRESS_BITS), Data => x"ABCDEF01", Mask => x"FFFF0000"),
            1 => to_AXI4_Register(Address => to_unsigned(1,ADDRESS_BITS), Data => x"BCDEF012", Mask => x"FFFFFF00"),
            2 => to_AXI4_Register(Address => to_unsigned(0,ADDRESS_BITS), Data => x"CDEF0123", Mask => x"00000000"),
            3 => to_AXI4_Register(Address => to_unsigned(5,ADDRESS_BITS), Data => x"F0123456", Mask => x"00FFFF00")
          ), MAX_CONFIG),
        1 => to_AXI4_Register_Set((
            0 => to_AXI4_Register(Address => to_unsigned(2,ADDRESS_BITS), Data => x"12345678", Mask => x"00FFFF00"),
            1 => to_AXI4_Register(Address => to_unsigned(1,ADDRESS_BITS), Data => x"3456789A", Mask => x"FFF000F0"),
            2 => to_AXI4_Register(Address => to_unsigned(0,ADDRESS_BITS), Data => x"56789ABC", Mask => x"F000000F")
          ), MAX_CONFIG)
      )
    );
    Port ( 
      Clock         : in STD_LOGIC;
      Reset         : in STD_LOGIC;
      
      Reconfig      : in STD_LOGIC;
      ReconfigDone  : out STD_LOGIC;
      Error         : out std_logic;
      ConfigSelect  : in unsigned(log2ceilnz(CONFIG'length) - 1 downto 0);
      
      AXI4Lite_M2S  : out T_AXI4Lite_Bus_M2S  ;--:= Initialize_AXI4Lite_Bus_M2S(ADDRESS_BITS, DATA_BITS);
      AXI4Lite_S2M  : in  T_AXI4Lite_Bus_S2M  --:= Initialize_AXI4Lite_Bus_S2M(ADDRESS_BITS, DATA_BITS)
    );
end entity;

architecture rtl of AXI4Lite_Configurator is
  subtype MAX_CONFIG_RANGE is integer range 0 to MAX_CONFIG -1;

  type T_STATE is (
		ST_IDLE, ST_CHECK, ST_PRECHECK,
		ST_READ_BEGIN,	ST_READ_WAIT,
		ST_WRITE_BEGIN,	ST_WRITE_WAIT,
		ST_DONE
	);

	-- DualConfiguration - Statemachine
	signal State											: T_STATE																:= ST_IDLE;
	signal NextState									: T_STATE;

	signal DataBuffer_en_write				: std_logic;
	signal DataBuffer_en_read  				: std_logic;
	
	signal ROM_Entry									: T_AXI4_Register;
--	signal ROM_Entry									: T_AXI4_Register(
--	                                     Address(CONFIG(CONFIG'left).AXI4_Register(CONFIG(CONFIG'left).AXI4_Register'left).Address'range), 
--	                                     Data(CONFIG(CONFIG'left).AXI4_Register(CONFIG(CONFIG'left).AXI4_Register'left).Data'range), 
--	                                     Mask(CONFIG(CONFIG'left).AXI4_Register(CONFIG(CONFIG'left).AXI4_Register'left).Mask'range));

	signal ROM_LastConfigWord					: std_logic;
--	signal ROM_EmptyConfig     				: std_logic;

	signal ConfigSelect_d 						: unsigned(ConfigSelect'range);

	constant CONFIGINDEX_BITS					: positive															:= log2ceilnz(MAX_CONFIG);
	signal ConfigIndex_rst						: std_logic;
	signal ConfigIndex_en							: std_logic;
	signal ConfigIndex_us							: unsigned(CONFIGINDEX_BITS - 1 downto 0);
	
  signal Reader_Strobe        : STD_LOGIC;
  signal Reader_Address       : unsigned(ADDRESS_BITS -1 downto 0);
  signal Reader_Ready         : std_logic;
  signal Reader_Data          : std_logic_vector(DATA_BITS -1 downto 0);
  signal Reader_Done          : STD_LOGIC;
  signal Reader_Error         : STD_LOGIC;	
  signal Writer_Strobe        : STD_LOGIC;
  signal Writer_Address       : unsigned(ADDRESS_BITS -1 downto 0);
  signal Writer_Ready         : std_logic;
  signal Writer_Data          : std_logic_vector(DATA_BITS -1 downto 0)	:= (others => '0');
  signal Writer_Done          : STD_LOGIC;
  signal Writer_Error         : STD_LOGIC;


begin

-- configuration ROM
	blkCONFIG_ROM : block
		signal SetIndex 						: integer range 0 to CONFIG'high;
		signal RowIndex 						: MAX_CONFIG_RANGE;
	begin
		SetIndex							<= to_index(ConfigSelect_d, CONFIG'high);
		RowIndex							<= to_index(ConfigIndex_us, MAX_CONFIG_RANGE'high);
		ROM_Entry							<= CONFIG(SetIndex).AXI4_Register(RowIndex);
		ROM_LastConfigWord		<= to_sl(RowIndex = CONFIG(SetIndex).Last_Index);
--		ROM_EmptyConfig       <= to_sl(CONFIG(SetIndex).Number_Register = 0);
	end block;
	
	Reader_Address <= ROM_Entry.Address;
	Writer_Address <= ROM_Entry.Address;

	-- configuration index counter
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (ConfigIndex_rst = '1') then
				ConfigIndex_us		<= (others => '0');
				ConfigSelect_d		<= ConfigSelect;
			elsif (ConfigIndex_en = '1') then
				ConfigIndex_us		<= ConfigIndex_us + 1;
			end if;
		end if;
	end process;

	-- data buffer for Axi4Lite configuration words
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Writer_Data	<= (others => '0');
			elsif (DataBuffer_en_read = '1') then
				Writer_Data	<= ((Reader_Data			and not ROM_Entry.Mask) or
													(ROM_Entry.Data	and			ROM_Entry.Mask));
			elsif (DataBuffer_en_write = '1') then
				Writer_Data	<= ROM_Entry.Data;
			end if;
		end if;
	end process;  
	

	-- Axi4Lite read-modify-write statemachine
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;


	process(State, Reconfig, ROM_LastConfigWord, ROM_Entry, Reader_Ready, Writer_Ready, Reader_Done, Reader_Error, Writer_Done, Writer_Error)
	begin
		NextState								<= State;

		ReconfigDone						<= '0';
		Error                   <= '0';
		
		--AXI
		Reader_Strobe           <= '0';
		Writer_Strobe           <= '0';

		-- internal modules
		ConfigIndex_rst					<= '0';
		ConfigIndex_en					<= '0';
		DataBuffer_en_write	    <= '1';
		DataBuffer_en_read      <= '1';

		case State is
			when ST_IDLE =>
				if (Reconfig = '1') then
				  ConfigIndex_rst		<= '1';
					NextState					<= ST_PRECHECK;
				end if;
      
      when ST_PRECHECK =>
        if Reader_Ready = '1' and Writer_Ready = '1' then
					NextState					<= ST_CHECK;
        end if;
      
      when ST_CHECK =>
        if unsigned(not ROM_Entry.Mask) = 0 then
          DataBuffer_en_write	<= '1';
          NextState					  <= ST_WRITE_BEGIN;
        elsif unsigned(ROM_Entry.Mask) = 0 then
          if ROM_LastConfigWord = '1' then
						NextState				<= ST_DONE;
					else
						ConfigIndex_en	<= '1';
						NextState				<= ST_PRECHECK;
					end if;
        else
          NextState					  <= ST_READ_BEGIN;
        end if;

			when ST_READ_BEGIN =>
        Reader_Strobe       <= '1';
				NextState						<= ST_READ_WAIT;

			when ST_READ_WAIT =>
				if Reader_Done = '1' then
					DataBuffer_en_read <= '1';
					NextState					 <= ST_WRITE_BEGIN;
        elsif Reader_Error = '1' then
          Error             <= '1';
          NextState					<= ST_PRECHECK;
				end if;

			when ST_WRITE_BEGIN =>
			  Writer_Strobe       <= '1';
				NextState						<= ST_WRITE_WAIT;

			when ST_WRITE_WAIT =>
				if Writer_Done = '1' then
					if ROM_LastConfigWord = '1' then
						NextState				<= ST_DONE;
					else
						ConfigIndex_en	<= '1';
						NextState				<= ST_PRECHECK;
					end if;
        elsif Writer_Error = '1' then
          Error             <= '1';
          NextState					<= ST_PRECHECK;
        end if;

			when ST_DONE =>
			  if Reader_Ready = '1' and Writer_Ready = '1' then
          ReconfigDone				<= '1';
          NextState						<= ST_IDLE;
        end if;

		end case;
	end process;

	
	Reader : entity PoC.AXI4Lite_Reader
    Port map( 
      Clock         => Clock,
      Reset         => Reset,
      
      Strobe        => Reader_Strobe ,
      Address       => Reader_Address,
      Ready         => Reader_Ready  ,
                                     
      Data          => Reader_Data   ,
      Done          => Reader_Done   ,
      Error         => Reader_Error  ,
      
      ARValid       => AXI4Lite_M2S.ARValid,
      ARReady       => AXI4Lite_S2M.ARReady,
      std_logic_vector(ARAddr)        => AXI4Lite_M2S.ARAddr,
      ARCache       => AXI4Lite_M2S.ARCache,
      ARProt        => AXI4Lite_M2S.ARProt,
      
      RValid        => AXI4Lite_S2M.RValid,
      RReady        => AXI4Lite_M2S.RReady,
      RData         => AXI4Lite_S2M.RData,
      RResp         => AXI4Lite_S2M.RResp
    );
    
  Writer : entity PoC.AXI4Lite_Writer
    Port map( 
      Clock       => Clock,
      Reset       => Reset,
      
      Strobe      => Writer_Strobe ,
      Address     => Writer_Address,
      Data        => Writer_Data   ,
      Ready       => Writer_Ready  ,
      Done        => Writer_Done   ,
      Error       => Writer_Error  ,
      
      AWValid     => AXI4Lite_M2S.AWValid,
      AWReady     => AXI4Lite_S2M.AWReady,
      std_logic_vector(AWAddr)      => AXI4Lite_M2S.AWAddr,
      AWCache     => AXI4Lite_M2S.AWCache,
      AWProt      => AXI4Lite_M2S.AWProt,
       
      WValid      => AXI4Lite_M2S.WValid,
      WReady      => AXI4Lite_S2M.WReady,
      WData       => AXI4Lite_M2S.WData,
      WStrb       => AXI4Lite_M2S.WStrb,
     
      BValid      => AXI4Lite_S2M.BValid,
      BReady      => AXI4Lite_M2S.BReady,
      BResp       => AXI4Lite_S2M.BResp
      
    );

end architecture;
