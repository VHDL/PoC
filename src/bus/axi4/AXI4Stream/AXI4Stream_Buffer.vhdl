
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.axi4.all;
use			PoC.components.all;
use			PoC.vectors.all;


entity AXI4Stream_Buffer is
	generic (
		FRAMES						: positive								:= 2;
		MAX_PACKET_DEPTH  : positive								:= 8
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Port
		In_M2S            : in T_AXI4Stream_M2S := Initialize_AXI4Stream_M2S(32,8);
		In_S2M            : out T_AXI4Stream_S2M := Initialize_AXI4Stream_S2M(32,8);
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S := Initialize_AXI4Stream_M2S(32,8);
		Out_S2M           : in T_AXI4Stream_S2M := Initialize_AXI4Stream_S2M(32,8)
	);
end entity;


architecture rtl of AXI4Stream_Buffer is
  constant META_BITS					: natural						:= In_M2S.User'length;
	constant DATA_BITS					: positive					:= In_M2S.Data'length;
  
	attribute FSM_ENCODING						: string;

	type T_WRITER_STATE is (ST_IDLE, ST_FRAME);
	type T_READER_STATE is (ST_IDLE, ST_FRAME);

	signal Writer_State								: T_WRITER_STATE																			:= ST_IDLE;
	signal Writer_NextState						: T_WRITER_STATE;
	signal Reader_State								: T_READER_STATE																			:= ST_IDLE;
	signal Reader_NextState						: T_READER_STATE;

	constant Last_BIT									: natural																							:= DATA_BITS;

	signal DataFIFO_put								: std_logic;
	signal DataFIFO_DataIn						: std_logic_vector(DATA_BITS downto 0);
	signal DataFIFO_Full							: std_logic;
	signal MetaFIFO_Full							: std_logic;

	signal DataFIFO_got								: std_logic;
	signal DataFIFO_DataOut						: std_logic_vector(DataFIFO_DataIn'range);
	signal DataFIFO_Valid							: std_logic;

	signal FrameCommit								: std_logic;
  
  signal In_SOF                     : std_logic;
  signal started                    : std_logic := '0';
  
  signal Out_M2S_i                  : T_AXI4Stream_M2S(Data(DATA_BITS -1 downto 0), User(META_BITS -1 downto 0));
  
begin
  
  In_SOF      <= In_M2S.Valid and not started;
  started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.Last) or Reset), set => (In_M2S.Valid)) when rising_edge(Clock);
  
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Writer_State					<= ST_IDLE;
				Reader_State					<= ST_IDLE;
			else
				Writer_State					<= Writer_NextState;
				Reader_State					<= Reader_NextState;
			end if;
		end if;
	end process;

	process(Writer_State,
					In_M2S.Valid, In_M2S.Data, In_SOF, In_M2S.Last,
					DataFIFO_Full, MetaFIFO_Full)
	begin
		Writer_NextState									<= Writer_State;

		In_S2M.Ready											<= '0';

		DataFIFO_put											<= '0';
		DataFIFO_DataIn(In_M2S.Data'range)<= In_M2S.Data;
		DataFIFO_DataIn(Last_BIT)					<= In_M2S.Last;

		case Writer_State is
			when ST_IDLE =>
				In_S2M.Ready									<= not DataFIFO_Full and not MetaFIFO_Full;
				DataFIFO_put									<= In_M2S.Valid and not MetaFIFO_Full;

				if ((In_M2S.Valid and In_SOF and not In_M2S.Last and not MetaFIFO_Full) = '1') then

					Writer_NextState						<= ST_FRAME;
				end if;

			when ST_FRAME =>
				In_S2M.Ready									<= not DataFIFO_Full;
				DataFIFO_put									<= In_M2S.Valid;

				if ((In_M2S.Valid and In_M2S.Last and not DataFIFO_Full) = '1') then

					Writer_NextState						<= ST_IDLE;
				end if;
		end case;
	end process;


	process(Reader_State,
					Out_S2M.Ready,
					DataFIFO_Valid, DataFIFO_DataOut)
	begin
		Reader_NextState								<= Reader_State;

		Out_M2S_i.Valid									<= '0';
		Out_M2S_i.Data									<= DataFIFO_DataOut(Out_M2S_i.Data'range);
		Out_M2S_i.Last									<= DataFIFO_DataOut(Last_BIT);

		DataFIFO_got										<= '0';

		case Reader_State is
			when ST_IDLE =>
				Out_M2S_i.Valid							<= DataFIFO_Valid;
				DataFIFO_got								<= Out_S2M.Ready;

				if ((DataFIFO_Valid and not DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready) = '1') then
					Reader_NextState					<= ST_FRAME;
				end if;

			when ST_FRAME =>
				Out_M2S_i.Valid										<= DataFIFO_Valid;
				DataFIFO_got								<= Out_S2M.Ready;

				if ((DataFIFO_Valid and DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready) = '1') then
					Reader_NextState					<= ST_IDLE;
				end if;

		end case;
	end process;

	DataFIFO : entity PoC.fifo_cc_got
		generic map (
			D_BITS							=> DATA_BITS + 1,								-- Data Width
			MIN_DEPTH						=> (MAX_PACKET_DEPTH * FRAMES),	-- Minimum FIFO Depth
			DATA_REG						=> ((MAX_PACKET_DEPTH * FRAMES) <= 128),											-- Store Data Content in Registers
			STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
			OUTPUT_REG					=> FALSE,												-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,														-- Empty State Bits
			FSTATE_RD_BITS			=> 0														-- Full State Bits
		)
		port map (
			-- Global Reset and Clock
			clk									=> Clock,
			rst									=> Reset,

			-- Writing Interface
			put									=> DataFIFO_put,
			din									=> DataFIFO_DataIn,
			full								=> DataFIFO_Full,
			estate_wr						=> open,

			-- Reading Interface
			got									=> DataFIFO_got,
			dout								=> DataFIFO_DataOut,
			valid								=> DataFIFO_Valid,
			fstate_rd						=> open
		);

	FrameCommit		<= DataFIFO_Valid and DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready;
    
  Out_M2S     <= Out_M2S_i;

	genMeta : if META_BITS > 0 generate
  
    MetaFIFO : entity PoC.fifo_cc_got
      generic map (
        D_BITS							=> META_BITS,								-- Data Width
        MIN_DEPTH						=> (META_BITS * FRAMES),	-- Minimum FIFO Depth
        DATA_REG						=> ((META_BITS * FRAMES) <= 128),											-- Store Data Content in Registers
        STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
        OUTPUT_REG					=> FALSE,												-- Registered FIFO Output
        ESTATE_WR_BITS			=> 0,														-- Empty State Bits
        FSTATE_RD_BITS			=> 0														-- Full State Bits
      )
      port map (
        -- Global Reset and Clock
        clk									=> Clock,
        rst									=> Reset,

        -- Writing Interface
        put									=> In_SOF,
        din									=> In_M2S.User,
        full								=> MetaFIFO_Full,
        estate_wr						=> open,

        -- Reading Interface
        got									=> Out_M2S_i.Valid and Out_M2S_i.Last and Out_S2M.Ready,
        dout								=> Out_M2S_i.User,
        valid								=> open,
        fstate_rd						=> open
      );

	end generate;

end architecture;
