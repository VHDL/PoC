


library IEEE;
use			IEEE.std_logic_1164.all;

library PoC;
use			PoC.vectors.all;


entity eth_TEMAC_TX_FSM is
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;

		Valid							: in	std_logic;
		Data							: in	T_SLV_8;
		EOF								: in	std_logic;
		Ack								: out	std_logic;
		Commit						: out	std_logic;
		Rollback					: out	std_logic;

		UnderrunDetected	: out	std_logic;

		TEMAC_Valid				: out	std_logic;
		TEMAC_Data				: out	T_SLV_8;
		TEMAC_Ack					: in	std_logic
	);
end;


architecture rtl of eth_TEMAC_TX_FSM is

	type T_STATE is (ST_IDLE, ST_DATAFLOW, ST_INTERFRAME_PAUSE, ST_DISCARD_FRAME);

	signal State			: T_STATE			:= ST_IDLE;
	signal NextState	: T_STATE;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State		<= ST_IDLE;
			else
				State		<= NextState;
			end if;
		end if;
	end process;

	process(State, Valid, Data, TEMAC_Ack)
	begin
		NextState					<= State;

		Ack								<= '0';
		Commit						<= '0';
		Rollback					<= '0';

		TEMAC_Valid				<= '0';
		TEMAC_Data				<= Data;

		UnderrunDetected	<= '0';

		case State is
			when ST_IDLE =>
				TEMAC_Valid					<= Valid;
				Ack									<= TEMAC_Ack;

				if ((Valid and TEMAC_Ack) = '1') then
					NextState					<= ST_DATAFLOW;
				end if;

			when ST_DATAFLOW =>
				Ack									<= '1';

				if (Valid = '1') then
					if (EOF = '1') then
						NextState				<= ST_INTERFRAME_PAUSE;
					end if;
				else
					NextState					<= ST_DISCARD_FRAME;
				end if;

			when ST_INTERFRAME_PAUSE =>
				Commit							<= '1';
				NextState						<= ST_IDLE;

			when ST_DISCARD_FRAME =>
				Ack									<= '1';

				if ((Valid and EOF) = '1') then
					Rollback					<= '1';
					UnderrunDetected	<= '1';

					NextState					<= ST_IDLE;
				end if;

		end case;
	end process;
end;
