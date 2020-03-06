


library IEEE;
use			IEEE.std_logic_1164.all;

library PoC;
use			PoC.vectors.all;


entity eth_TEMAC_RX_FSM is
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;

		TEMAC_Valid				: in	std_logic;
		TEMAC_Data				: in	T_SLV_8;
		TEMAC_GoodFrame		: in	std_logic;
		TEMAC_BadFrame		: in	std_logic;

		OverflowDetected	: out	std_logic;

		Valid							: out	std_logic;
		Data							: out	T_SLV_8;
		SOF								: out	std_logic;
		EOF								: out	std_logic;
		Ack								: in	std_logic;
		Commit						: out	std_logic;
		Rollback					: out	std_logic
	);
end;


architecture rtl of eth_TEMAC_RX_FSM is

	type T_STATE is (ST_IDLE, ST_SOF, ST_DATAFLOW, ST_EOF, ST_AWAIT_CRCRESULT, ST_DISCARD_FRAME, ST_ERROR);

	signal State				: T_STATE		:= ST_IDLE;
	signal NextState		: T_STATE;

	signal DataReg_d		: T_SLV_8		:= (others => '0');

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

	process(State, TEMAC_Valid, TEMAC_GoodFrame, TEMAC_BadFrame, DataReg_d, Ack)
	begin
		NextState					<= State;

		Valid							<= '0';
		Data							<= DataReg_d;
		SOF								<= '0';
		EOF								<= '0';
		Commit						<= '0';
		Rollback					<= '0';

		OverflowDetected	<= '0';

		case State is
			when ST_IDLE =>
				if (TEMAC_Valid = '1') then
					NextState				<= ST_SOF;
				end if;

			when ST_SOF =>
				Valid							<= '1';
				SOF								<= '1';

				if (Ack = '0') then
					NextState				<= ST_DISCARD_FRAME;
				elsif (TEMAC_Valid = '1') then
					NextState				<= ST_DATAFLOW;
				else
					EOF							<= '1';
					NextState				<= ST_IDLE;
				end if;

			when ST_DATAFLOW =>
				Valid							<= '1';

				if (TEMAC_Valid = '0') then
					EOF							<= '1';
					NextState				<= ST_AWAIT_CRCRESULT;
				end if;

			when ST_AWAIT_CRCRESULT =>
				if (TEMAC_GoodFrame = '1') then
					Commit					<= '1';
					NextState				<= ST_IDLE;
				elsif (TEMAC_BadFrame = '1') then
					Rollback				<= '1';
					NextState				<= ST_IDLE;
				end if;

			when ST_DISCARD_FRAME =>
				if (TEMAC_Valid = '0') then
					OverflowDetected	<= '1';
					NextState					<= ST_IDLE;
				end if;

		end case;
	end process;

	DataReg_d		<= TEMAC_Data when rising_edge(Clock);
end;
