LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.xilinx.ALL;

--LIBRARY L_Global;
--USE			L_Global.GlobalTypes.ALL;


ENTITY xil_Reconfigurator IS
	GENERIC (
		DEBUG										: BOOLEAN											:= FALSE;																				-- 
		CLOCK_FREQ_MHZ					: REAL												:= 0.0;																					-- 
		CONFIG_ROM							: IN	T_XIL_DRP_CONFIG_ROM		:= (0 DOWNTO 0 => C_XIL_DRP_CONFIG_SET_EMPTY)		-- 
	);
	PORT (
		Clock										: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;
		
		Reconfig								: IN	STD_LOGIC;																				--
		ReconfigDone						: OUT	STD_LOGIC;																				--
		ConfigSelect						: IN	STD_LOGIC_VECTOR;																	-- 
		
		DRP_en									: OUT	STD_LOGIC;																				-- 
		DRP_Address							: OUT	T_XIL_DRP_ADDRESS;																-- 
		DRP_we									: OUT	STD_LOGIC;																				-- 
		DRP_DataIn							: IN	T_XIL_DRP_DATA;																		-- 
		DRP_DataOut							: OUT	T_XIL_DRP_DATA;																		-- 
		DRP_Ready								: IN	STD_LOGIC																					-- 
	);
END;


ARCHITECTURE rtl OF xil_Reconfigurator IS
	ATTRIBUTE KEEP								: BOOLEAN;
	ATTRIBUTE FSM_ENCODING				: STRING;
	ATTRIBUTE SIGNAL_ENCODING			: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_READ_BEGIN,	ST_READ_WAIT,
		ST_WRITE_BEGIN,	ST_WRITE_WAIT,
		ST_DONE
	);
	
	-- DualConfiguration - Statemachine
	SIGNAL State											: T_STATE																:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State	: SIGNAL IS ite(DEBUG, "gray", "speed1");
	
	SIGNAL DataBuffer_en							: STD_LOGIC;
	SIGNAL DataBuffer_d								: T_XIL_DRP_DATA													:= (OTHERS => '0');

	SIGNAL ROM_Entry									: T_XIL_DRP_CONFIG;
	SIGNAL ROM_LastConfigWord					: STD_LOGIC;

	CONSTANT CONFIGINDEX_BW						: POSITIVE															:= log2ceilnz(C_XIL_DRP_MAX_CONFIG_COUNT);
	SIGNAL ConfigIndex_rst						: STD_LOGIC;
	SIGNAL ConfigIndex_en							: STD_LOGIC;
	SIGNAL ConfigIndex_us							: UNSIGNED(CONFIGINDEX_BW - 1 DOWNTO 0);
	
	ATTRIBUTE KEEP OF ROM_LastConfigWord	: SIGNAL IS DEBUG;
BEGIN

--	ASSERT XilDRP_Assert(CLOCK_FREQ_MHZ) REPORT "DRP clock frequency not supported by device" SEVERITY FAILURE;

	-- configuration ROM
	blkCONFIG_ROM : BLOCK
		SIGNAL SetIndex 		: INTEGER;
		SIGNAL RowIndex 		: INTEGER;
		
--		ATTRIBUTE SIGNAL_ENCODING OF SetIndex		: SIGNAL IS "user";
--		ATTRIBUTE SIGNAL_ENCODING OF RowIndex		: SIGNAL IS "user";
		
		ATTRIBUTE KEEP OF SetIndex							: SIGNAL IS DEBUG;
		ATTRIBUTE KEEP OF RowIndex							: SIGNAL IS DEBUG;
	BEGIN
		SetIndex							<= to_integer(unsigned(ConfigSelect));
		RowIndex							<= to_integer(ConfigIndex_us);
		ROM_Entry							<= CONFIG_ROM(SetIndex).Configs(RowIndex);
		ROM_LastConfigWord		<= to_sl(RowIndex = CONFIG_ROM(SetIndex).LastIndex);
	END BLOCK;
	
	-- configuration index counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset = '1') OR (ConfigIndex_rst = '1')) THEN
				ConfigIndex_us			<= (OTHERS => '0');
			ELSE
				IF (ConfigIndex_en = '1') THEN
					ConfigIndex_us		<= ConfigIndex_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	-- data buffer for DRP configuration words
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				DataBuffer_d		<= (OTHERS => '0');
			ELSE
				IF (DataBuffer_en = '1') THEN
					DataBuffer_d	<= ((DRP_DataIn			AND NOT ROM_Entry.Mask) OR
														(ROM_Entry.Data	AND			ROM_Entry.Mask));
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	-- assign DRP signals
	DRP_Address						<= ROM_Entry.Address;
	DRP_DataOut						<= DataBuffer_d;

	-- DRP read-modify-write statemachine
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Reconfig, ROM_LastConfigWord, DRP_Ready)
	BEGIN
		NextState								<= State;

		ReconfigDone						<= '0';
		
		-- Dynamic Reconfiguration Port
		DRP_en									<= '0';
		DRP_we									<= '0';
		
		-- internal modules
		ConfigIndex_rst					<= '0';
		ConfigIndex_en					<= '0';
		DataBuffer_en						<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				IF (Reconfig = '1') THEN
					ConfigIndex_rst				<= '1';
				
					NextState							<= ST_READ_BEGIN;
				END IF;

			WHEN ST_READ_BEGIN =>
				DRP_en										<= '1';
				DRP_we										<= '0';
					
				NextState									<= ST_READ_WAIT;
			
			WHEN ST_READ_WAIT =>
				IF (DRP_Ready = '1') THEN
					DataBuffer_en						<= '1';
				
					NextState								<= ST_WRITE_BEGIN;
				END IF;
			
			WHEN ST_WRITE_BEGIN =>
				DRP_en										<= '1';
				DRP_we										<= '1';

				NextState									<= ST_WRITE_WAIT;
			
			WHEN ST_WRITE_WAIT =>
				IF (DRP_Ready = '1') THEN
					IF (ROM_LastConfigWord = '1') THEN
						NextState							<= ST_DONE;
					ELSE
						ConfigIndex_en				<= '1';
						NextState							<= ST_READ_BEGIN;
					END IF;
				END IF;
			
			WHEN ST_DONE =>
				ReconfigDone							<= '1';
				NextState									<= ST_IDLE;
			
		END CASE;
	END PROCESS;
END;
