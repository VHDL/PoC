LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;
USE			L_Global.GlobalSimulation.ALL;


ENTITY Stream_Source IS
	GENERIC (
		TESTCASES												: T_SIM_STREAM_FRAMEGROUP_VECTOR_8
	);
	PORT (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;
		-- Control interface
		Enable													: IN	STD_LOGIC;
		-- OUT Port
		Out_Valid												: OUT	STD_LOGIC;
		Out_Data												: OUT	T_SLV_8;
		Out_SOF													: OUT	STD_LOGIC;
		Out_EOF													: OUT	STD_LOGIC;
		Out_Ready												: IN	STD_LOGIC
	);
END ENTITY;


ARCHITECTURE rtl OF Stream_Source IS
	CONSTANT MAX_CYCLES											: NATURAL																			:= 10 * 1000;
	CONSTANT MAX_ERRORS											: NATURAL																			:=				50;

	-- dummy signals for iSIM
	SIGNAL FrameGroupNumber_us		: UNSIGNED(log2ceilnz(TESTCASES'length) - 1 DOWNTO 0)		:= (OTHERS => '0');
BEGIN

	PROCESS
		VARIABLE Cycles							: NATURAL			:= 0;
		VARIABLE Errors							: NATURAL			:= 0;
		
		VARIABLE FrameGroupNumber		: NATURAL			:= 0;
		
		VARIABLE WordIndex					: NATURAL			:= 0;
		VARIABLE CurFG							: T_SIM_STREAM_FRAMEGROUP_8;
	
	BEGIN
		-- set interface to default values
		Out_Valid					<= '0';
		Out_Data					<= U8;
		Out_SOF						<= '0';
		Out_EOF						<= '0';

		-- wait for global enable signal
		WAIT UNTIL (Enable = '1');
		
		-- synchronize to clock
		WAIT UNTIL rising_edge(Clock);

		-- for each testcase in list
		FOR TestcaseIndex IN 0 TO TESTCASES'length - 1 LOOP
			-- initialize per loop
			Cycles	:= 0;
			Errors	:= 0;
			CurFG		:= TESTCASES(TestcaseIndex);
		
			-- continue with next frame if current is disabled
			ASSERT FALSE REPORT "active=" & to_string(CurFG.Active) SEVERITY WARNING;
			NEXT WHEN CurFG.Active = FALSE;
			
			-- write dummy signals for iSIM
			FrameGroupNumber			:= TestcaseIndex;
			FrameGroupNumber_us		<= to_unsigned(FrameGroupNumber, FrameGroupNumber_us'length);

			-- PrePause
			FOR I IN 1 TO CurFG.PrePause LOOP
				WAIT UNTIL rising_edge(Clock);
			END LOOP;
			
			WordIndex							:= 0;
			
			-- infinite loop
			LOOP
				-- check for to many simulation cycles
				ASSERT (Cycles < MAX_CYCLES) REPORT "MAX_CYCLES reached:  framegroup=" & INTEGER'image(to_integer(FrameGroupNumber_us)) SEVERITY FAILURE;
--				ASSERT (Errors < MAX_ERRORS) REPORT "MAX_ERRORS reached" SEVERITY FAILURE;
				Cycles := Cycles + 1;
				
				WAIT UNTIL rising_edge(Clock);
				-- write frame data to interface
				Out_Valid					<= CurFG.Data(WordIndex).Valid;
				Out_Data						<= CurFG.Data(WordIndex).Data;
				Out_SOF						<= CurFG.Data(WordIndex).SOF;
				Out_EOF						<= CurFG.Data(WordIndex).EOF;
				
				WAIT UNTIL falling_edge(Clock);
				-- go to next word if interface counterpart has accepted the current word
				IF (Out_Ready = '1') THEN
					WordIndex := WordIndex + 1;
				END IF;
			
				-- check if framegroup end is reached => exit LOOP
				ASSERT FALSE REPORT "WordIndex=" & INTEGER'image(WordIndex) SEVERITY WARNING;
				EXIT WHEN ((WordIndex /= 0) AND (CurFG.Data(WordIndex - 1).EOFG = TRUE));
			END LOOP;
			
			-- PostPause
			FOR I IN 1 TO CurFG.PostPause LOOP
				WAIT UNTIL rising_edge(Clock);
			END LOOP;
			
			ASSERT FALSE REPORT "new round" SEVERITY WARNING;
		END LOOP;

		-- set interface to default values
		WAIT UNTIL rising_edge(Clock);
		Out_Valid					<= '0';
		Out_Data						<= U8;
		Out_SOF						<= '0';
		Out_EOF						<= '0';
	
	END PROCESS;
END ARCHITECTURE;
