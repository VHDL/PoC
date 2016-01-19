

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

library PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.fifo.all;
use			PoC.io.all;


entity Dummy is
	port (
		clk		: in	STD_LOGIC;
		rst		: in	STD_LOGIC;
		
		led		: out	STD_LOGIC
	);
end entity;

architecture rtl of Dummy is
	signal clk1		: STD_LOGIC;
	signal rst1		: STD_LOGIC;
	signal clk2		: STD_LOGIC;
	signal rst2		: STD_LOGIC;
	
	signal shiftchain_in		: STD_LOGIC_VECTOR(7 downto 0)	:= (others => '0');
	signal shiftchain_out		: STD_LOGIC_VECTOR(6 downto 0);
	
begin
	clk1	<= clk;
	clk2	<= not clk;
	rst1	<= rst when rising_edge(clk1);
	rst2	<= rst when rising_edge(clk2);

	process(clk1)
	begin
		if rising_edge(clk1) then
			shiftchain_in		<= (shiftchain_in(6 downto 0) xor shiftchain_out) & '1';
		end if;
	end process;
	
	led							<= shiftchain_in(7);

	blkFIFO : block
		signal chain_in		: STD_LOGIC_VECTOR(63 downto 0)		:= (others => '0');
		signal chain_out	: STD_LOGIC_VECTOR(62 downto 0);
	begin
		shiftchain_out(0)	<= chain_in(chain_in'high);
		
		process(clk1)
		begin
			if rising_edge(clk1) then
				chain_in		<= (chain_in(62 downto 0) xor chain_out) & shiftchain_in(0);
			end if;
		end process;
		
		fifo1 : entity PoC.fifo_glue
			generic map (
				D_BITS => 8
			)
			port map (
				-- Control
				clk			=> clk1,
				rst			=> rst1,
				-- Input
				put			=> chain_in(1),
				di			=> chain_in(9 downto 2),
				ful			=> chain_out(0),
				-- Output
				vld			=> chain_out(1),
				do			=> chain_out(9 downto 2),
				got			=> chain_in(10)
			);

		fifo2 : entity PoC.fifo_shift
			generic map (
				D_BITS    => 8,
				MIN_DEPTH => 32
			)
			port map (
				-- Control
				clk			=> clk1,
				rst			=> rst1,
				-- Input
				put			=> chain_in(11),
				din			=> chain_in(19 downto 12),
				ful			=> chain_out(10),
				-- Output
				vld			=> chain_out(11),
				dout		=> chain_out(19 downto 12),
				got			=> chain_in(20)
			);

		fifo3 : entity PoC.fifo_cc_got
			generic map (
				D_BITS					=> 8,
				MIN_DEPTH				=> 32,
				DATA_REG				=> TRUE,
				STATE_REG				=> TRUE,
				OUTPUT_REG			=> TRUE,
				ESTATE_WR_BITS	=> 2,
				FSTATE_RD_BITS	=> 2
			)
			port map (
				clk				=> clk1,
				rst				=> rst1,
				-- Writing Interface
				put			=> chain_in(21),
				din			=> chain_in(29 downto 22),
				full		=> chain_out(20),
				estate_wr	=> open,
				-- Reading Interface
				valid		=> chain_out(21),
				dout		=> chain_out(29 downto 22),
				got			=> chain_in(30),
				fstate_rd	=> open
			);


  --fifo4 : entity PoC.fifo_dc_got_sm
    --generic (
      --D_BITS    : positive;
      --MIN_DEPTH : positive);
    --port (
      --clk_wr : in  std_logic;
      --rst_wr : in  std_logic;
      --put    : in  std_logic;
      --din    : in  std_logic_vector(D_BITS - 1 downto 0);
      --full   : out std_logic;
      --clk_rd : in  std_logic;
      --rst_rd : in  std_logic;
      --got    : in  std_logic;
      --valid  : out std_logic;
      --dout   : out std_logic_vector(D_BITS - 1 downto 0));
  --end component;
  
		fifo5 : entity PoC.fifo_ic_got
			generic map (
				D_BITS					=> 8,
				MIN_DEPTH				=> 32,
				DATA_REG				=> TRUE,
				--STATE_REG				=> TRUE,
				OUTPUT_REG			=> TRUE,
				ESTATE_WR_BITS	=> 2,
				FSTATE_RD_BITS	=> 2
			)
			port map (
				-- Writing Interface
				clk_wr		=> clk1,
				rst_wr		=> rst1,
				put				=> chain_in(31),
				din				=> chain_in(39 downto 32),
				full			=> chain_out(30),
				estate_wr	=> open,
				-- Reading Interface
				clk_rd		=> clk2,
				rst_rd		=> rst2,
				valid			=> chain_out(31),
				dout			=> chain_out(39 downto 32),
				got				=> chain_in(40),
				fstate_rd	=> open
			);

		fifo6 : entity PoC.fifo_cc_got_tempput
			generic map (
				D_BITS					=> 8,
				MIN_DEPTH				=> 32,
				DATA_REG				=> TRUE,
				STATE_REG				=> TRUE,
				OUTPUT_REG			=> TRUE,
				ESTATE_WR_BITS	=> 2,
				FSTATE_RD_BITS	=> 2
			)
			port map (
				-- Writing Interface
				clk				=> clk1,
				rst				=> rst1,
				put				=> chain_in(41),
				din				=> chain_in(49 downto 42),
				full			=> chain_out(40),
				estate_wr	=> open,
				commit		=> '1',
				rollback	=> '0',
				-- Reading Interface
				valid			=> chain_out(41),
				dout			=> chain_out(49 downto 42),
				got				=> chain_in(50),
				fstate_rd	=> open
			);

		fifo7 : entity PoC.fifo_cc_got_tempgot
			generic map (
				D_BITS					=> 8,
				MIN_DEPTH				=> 32,
				DATA_REG				=> TRUE,
				STATE_REG				=> TRUE,
				OUTPUT_REG			=> TRUE,
				ESTATE_WR_BITS	=> 2,
				FSTATE_RD_BITS	=> 2
			)
			port map (
				-- Writing Interface
				clk				=> clk1,
				rst				=> rst1,
				put				=> chain_in(51),
				din				=> chain_in(59 downto 52),
				full			=> chain_out(50),
				estate_wr	=> open,
				-- Reading Interface
				valid			=> chain_out(51),
				dout			=> chain_out(59 downto 52),
				got				=> chain_in(60),
				fstate_rd	=> open,
				commit		=> '1',
				rollback	=> '0'
			);
	
	end block;

	blkIO : block
	
		signal chain_in		: STD_LOGIC_VECTOR(63 downto 0);
		signal chain_out	: STD_LOGIC_VECTOR(62 downto 0);
	begin
		shiftchain_out(1)	<= chain_in(chain_in'high);
		
		process(clk1)
		begin
			if rising_edge(clk1) then
				chain_in		<= (chain_in(62 downto 0) xor chain_out) & shiftchain_in(1);
			end if;
		end process;
		
		io1 : entity PoC.io_7SegmentMux_BCD
			generic map (
				CLOCK_FREQ			=> 100 MHz,
				REFRESH_RATE		=> 1 kHz,
				DIGITS					=> 4
			)
			port map (
				Clock						=> clk1,
				
				BCDDigits				=> (3 => T_BCD(chain_in(15 downto 12)),
														2 => T_BCD(chain_in(11 downto 8)),
														1 => T_BCD(chain_in(7 downto 4)),
														0 => T_BCD(chain_in(3 downto 0))),
				BCDDots					=> chain_in(19 downto 16),
				
				SegmentControl	=> chain_out(7 downto 0),
				DigitControl		=> chain_out(11 downto 8)
			);
			
		io2 : entity PoC.io_7SegmentMux_HEX
			generic map (
				CLOCK_FREQ			=> 100 MHz,
				REFRESH_RATE		=> 1 kHz,
				DIGITS					=> 4
			)
			port map (
				Clock						=> clk1,
				
				HEXDigits				=> (3 => chain_in(35 downto 32),
														2 => chain_in(31 downto 28),
														1 => chain_in(27 downto 24),
														0 => chain_in(23 downto 20)),
				HEXDots					=> chain_in(39 downto 36),
				
				SegmentControl	=> chain_out(19 downto 12),
				DigitControl		=> chain_out(23 downto 20)
			);
	
		blkUART : block
		
		begin
			uart : entity PoC.uart_fifo
				generic map (
					-- Communication Parameters
					CLOCK_FREQ		=> 100 MHz,
					BAUDRATE			=> 921.600 kBd
				)
				port map (
					Clock					=> clk1,
					Reset					=> rst1,

					-- FIFO interface
					TX_put				=> chain_in(40),
					TX_Data				=> chain_in(48 downto 41),
					TX_Full				=> chain_out(24),
					TX_EmptyState	=> open,
					
					RX_Valid			=> chain_out(25),
					RX_Data				=> chain_out(33 downto 26),
					RX_got				=> chain_in(49),
					RX_FullState	=> open,
					RX_Overflow		=> chain_out(34),
					
					-- External pins
					UART_TX				=> chain_out(35),
					UART_RX				=> chain_in(50),
					UART_RTS			=> open,
					UART_CTS			=> '1'
				);
		end block;
	end block;
	
	blkMisc : block
	
		signal chain_in		: STD_LOGIC_VECTOR(63 downto 0);
		signal chain_out	: STD_LOGIC_VECTOR(62 downto 0);
	begin
		shiftchain_out(2)	<= chain_in(chain_in'high);
		
		process(clk1)
		begin
			if rising_edge(clk1) then
				chain_in		<= (chain_in(62 downto 0) xor chain_out) & shiftchain_in(2);
			end if;
		end process;
		
		misc1 : entity PoC.misc_Delay
			generic map (
				BITS			=> 8,
				TAPS			=> (3, 5, 7, 12)
			)
			port map (
				Clock			=> clk1,
				Reset			=> rst1,
				Enable		=> chain_in(0),
				DataIn		=> chain_in(8 downto 1),
				DataOut		=> open		-- chain_out(7 downto 0)
			);
		
		misc3 : entity PoC.misc_PulseTrain
			generic map (
				PULSE_TRAIN				=> "101000101010"
			)
			port map (
				Clock							=> clk1,
				StartSequence			=> rst1,
				SequenceCompleted	=> chain_out(8),
				Output						=> chain_out(9)
			);
		
		misc4 : entity PoC.WordAligner
			generic map (
				REGISTERED		=> TRUE,
				INPUT_BITS		=> 32,
				WORD_BITS			=> 8
			)
			port map (
				Clock					=> clk1,
				Align					=> "0010",
				I							=> chain_in(40 downto 9),
				O							=> chain_out(41 downto 10),
				Valid					=> chain_out(42)
			);
	
		blkSync : block
		
		begin
			sync1 : entity PoC.sync_Vector
				generic map (
					MASTER_BITS		=> 4,
					SLAVE_BITS		=> 0
				)
				port map (
					Clock1				=> clk1,
					Clock2				=> clk2,
					Input					=> x"E",
					Output				=> open,
					Busy					=> open,
					Changed				=> open
				);
			
			sync2 : entity PoC.sync_Command
				generic map (
					BITS					=> 8
				)
				port map (
					Clock1				=> clk1,
					Clock2				=> clk2,
					Input					=> x"34",
					Output				=> open,
					Busy					=> open,
					Changed				=> open
				);
		end block;
	
	end block;
end architecture;


