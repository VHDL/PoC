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
		CHIPSCOPE_KEEP								: BOOLEAN												:= TRUE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		-- IICSwitch interface

		In_Data												: IN	T_SLVV_8;
		
		Out_Data											: OUT	T_SLV_8
	);
END ENTITY;

-- TODOs
--	

ARCHITECTURE rtl OF IICSwitch_PCA9548A IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	ATTRIBUTE ENUM_ENCODING						: STRING;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_SEND_START,							ST_SEND_START_WAIT,
		-- address operation for random access => dummy write to internal SFP address register
			ST_SEND_PHYSICAL_ADDRESS0,	ST_SEND_PHYSICAL_ADDRESS0_WAIT,
			ST_SEND_READWRITE0,					ST_SEND_READWRITE0_WAIT,
			ST_RECEIVE_ACK0,						ST_RECEIVE_ACK0_WAIT,
			ST_SEND_REGISTER_ADDRESS,		ST_SEND_REGISTER_ADDRESS_WAIT,
			ST_RECEIVE_ACK1,						ST_RECEIVE_ACK1_WAIT,
		-- write operation => continue with data bytes
			ST_SEND_DATA,								ST_SEND_DATA_WAIT,
			ST_RECEIVE_ACK2,						ST_RECEIVE_ACK2_WAIT,
			ST_REGISTER_NEXT_BYTE,
		-- read operation => restart bus, resend physical address, read data bytes
		ST_SEND_RESTART,						ST_SEND_RESTART_WAIT,
			ST_SEND_PHYSICAL_ADDRESS1,	ST_SEND_PHYSICAL_ADDRESS1_WAIT,
			ST_SEND_READWRITE1,					ST_SEND_READWRITE1_WAIT,
			ST_RECEIVE_ACK3,						ST_RECEIVE_ACK3_WAIT,
			ST_RECEIVE_DATA,						ST_RECEIVE_DATA_WAIT,
			ST_SEND_ACK,								ST_SEND_ACK_WAIT,
			ST_SEND_NACK,								ST_SEND_NACK_WAIT,
		ST_SEND_STOP,								ST_SEND_STOP_WAIT,
		ST_COMPLETE,
		ST_ERROR,
			ST_ADDRESS_ERROR,
			ST_ACK_ERROR,
			ST_BUS_ERROR
	);
	
	SIGNAL State												: T_STATE													:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	


BEGIN

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

	PROCESS(State)
	
	BEGIN
		NextState									<= State;

		Status_i									<= IO_IIC_STATUS_IDLE;
		Error											<= IO_IIC_ERROR_NONE;
		
		CASE State IS
			WHEN ST_IDLE =>
				CASE Command IS
					WHEN IO_IIC_CMD_NONE =>
						NULL;
					
	
			WHEN ST_ADDRESS_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Error												<= IO_IIC_ERROR_ADDRESS_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Error												<= IO_IIC_ERROR_FSM;
				NextState										<= ST_IDLE;
			
		END CASE;
	END PROCESS;

END;
