LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;


ENTITY IICSwitch_PCA9548A IS
	GENERIC (
		CHIPSCOPE_KEEP		: BOOLEAN						:= TRUE;
		SWITCH_ADDRESS		: T_SLV_8						:= x"00";
		ADD_BYPASS_PORT		: BOOLEAN						:= FALSE
	);
	PORT (
		Clock							: IN	STD_LOGIC;
		Reset							: IN	STD_LOGIC;
		
		-- IICSwitch interface ports
		Request						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Grant							: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Abort							: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Valid					: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Data						: IN	T_SLVV_8(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Last						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Ack						: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Valid					: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Data						: OUT	T_SLVV_8(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Last						: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Ack						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		
		-- IICController master interface
		IICC_Request			: OUT	STD_LOGIC;
		IICC_Grant				: IN	STD_LOGIC;
		IICC_Abort				: OUT	STD_LOGIC;
		IICC_WP_Valid			: OUT	STD_LOGIC;
		IICC_WP_Data			: OUT	T_SLV_8;
		IICC_WP_Last			: OUT	STD_LOGIC;
		IICC_WP_Ack				: IN	STD_LOGIC;
		IICC_RP_Valid			: IN	STD_LOGIC;
		IICC_RP_Data			: IN	T_SLV_8;
		IICC_RP_Last			: IN	STD_LOGIC;
		IICC_RP_Ack				: OUT	STD_LOGIC;
		
		IICSwitch_Reset		: OUT	STD_LOGIC
	);
END ENTITY;


ARCHITECTURE rtl OF IICSwitch_PCA9548A IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	ATTRIBUTE ENUM_ENCODING						: STRING;
	
	CONSTANT PORTS										: POSITIVE						:= ite(ADD_BYPASS_PORT, 9, 8);
	CONSTANT ALLOW_MEALY_FSM_EDGE			: BOOLEAN							:= TRUE;
	
	FUNCTION iic_Write(Address : T_SLV_8) RETURN T_SLV_8 IS
	BEGIN
		RETURN Address(7 DOWNTO 1) & '1';
	END FUNCTION;

	FUNCTION iic_Read(Address : T_SLV_8) RETURN T_SLV_8 IS
	BEGIN
		RETURN Address(7 DOWNTO 1) & '0';
	END FUNCTION;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_REQUEST,
		ST_WRITE_SWITCH_PHYADDRESS, ST_WRITE_SWITCH_REGISTER, ST_WRITE_WAIT,
		ST_TRANSACTION,
		ST_ERROR
	);
	
	SIGNAL State												: T_STATE						:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL Request_or							: STD_LOGIC;
	SIGNAL FSM_Arbitrate					: STD_LOGIC;
	
	SIGNAL Arb_Arbitrated					: STD_LOGIC;
	SIGNAL Arb_Grant							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Arb_Grant_bin					: STD_LOGIC_VECTOR(log2ceilnz(PORTS) - 1 DOWNTO 0);
	
BEGIN

	Request_or		<= slv_or(Request);
	
	Arb : ENTITY L_Global.Arbiter
		GENERIC MAP (
			STRATEGY									=> "RR",			-- RR, LOT
			PORTS											=> PORTS,
			WEIGHTS										=> (0 TO PORTS - 1 => 1),
			OUTPUT_REG								=> FALSE
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Arbitrate									=> FSM_Arbitrate,
			Request_Vector						=> Request,
			
			Arbitrated								=> OPEN,	--Arb_Arbitrated,
			Grant_Vector							=> Arb_Grant,
			Grant_Index								=> Arb_Grant_bin
		);
	

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

	PROCESS(State,
		Request_or, Arb_Grant,
		IICC_Grant, IICC_WP_Ack)
	BEGIN
		NextState									<= State;

		IICC_Request							<= '0';
		
		FSM_Arbitrate							<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				IF (Request_or = '1') THEN
					FSM_Arbitrate				<= '1';
					NextState						<= ST_REQUEST;
					
					IF ALLOW_MEALY_FSM_EDGE THEN
						IICC_Request			<= '1';
						
						IF (IICC_Grant = '1') THEN
							IF (ADD_BYPASS_PORT AND (Arb_Grant(Arb_Grant'high) = '1')) THEN
								NextState			<= ST_TRANSACTION;
							ELSE
								NextState			<= ST_WRITE_SWITCH_PHYADDRESS;
							END IF;
						END IF;
					END IF;
				END IF;
			
			WHEN ST_REQUEST =>
				IICC_Request					<= '1';
				
				IF (IICC_Grant = '1') THEN
					IF (ADD_BYPASS_PORT AND (Arb_Grant(Arb_Grant'high) = '1')) THEN
						NextState					<= ST_TRANSACTION;
					ELSE
						NextState					<= ST_WRITE_SWITCH_PHYADDRESS;
					END IF;
				END IF;
	
			WHEN ST_WRITE_SWITCH_PHYADDRESS =>
				IICC_Request					<= '1';
			
				IICC_WP_Valid					<= '1';
				IICC_WP_Data					<= iic_Write(SWITCH_ADDRESS);
				
				IF (IICC_WP_Ack = '1') THEN
					NextState						<= ST_WRITE_SWITCH_REGISTER;
				END IF;
				
			WHEN ST_WRITE_SWITCH_REGISTER =>
				IICC_Request					<= '1';
			
				IICC_WP_Valid					<= '1';
				IICC_WP_Data					<= Arb_Grant(IICC_WP_Data'range);
				
				IF (IICC_WP_Ack = '1') THEN
					NextState						<= ST_WRITE_WAIT;
				END IF;
	
			WHEN ST_WRITE_WAIT =>	
	
			WHEN ST_ERROR =>
--				Status_i										<= IO_IIC_STATUS_ERROR;
--				Error												<= IO_IIC_ERROR_FSM;
				NextState										<= ST_IDLE;
			
		END CASE;
	END PROCESS;

END;
