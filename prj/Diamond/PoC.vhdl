

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
		rst		: in	STD_LOGIC
	);
end entity;

architecture rtl of Dummy is
	signal clk1		: STD_LOGIC;
	signal rst1		: STD_LOGIC;
	signal clk2		: STD_LOGIC;
	signal rst2		: STD_LOGIC;
begin
	blkFIFO : block
	begin
		fifo1 : entity PoC.fifo_glue
			generic map (
				D_BITS => 8
			)
			port map (
				-- Control
				clk			=> clk1,
				rst			=> rst1,
				-- Input
				put			=> '1',
				di			=> x"01",
				ful			=> open,
				-- Output
				vld			=> open,
				do			=> open,
				got			=> '1'
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
				put			=> '1',
				din			=> x"01",
				ful			=> open,
				-- Output
				vld			=> open,
				dout		=> open,
				got			=> '1'
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
				put				=> '1',
				din				=> x"02",
				full			=> open,
				estate_wr	=> open,
				-- Reading Interface
				got				=> '1',
				dout			=> open,
				valid			=> open,
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
				put				=> '1',
				din				=> x"02",
				full			=> open,
				estate_wr	=> open,
				-- Reading Interface
				clk_rd		=> clk2,
				rst_rd		=> rst2,
				got				=> '1',
				dout			=> open,
				valid			=> open,
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
				put				=> '1',
				din				=> x"02",
				full			=> open,
				estate_wr	=> open,
				commit		=> '1',
				rollback	=> '0',
				-- Reading Interface
				got				=> '1',
				dout			=> open,
				valid			=> open,
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
				put				=> '1',
				din				=> x"02",
				full			=> open,
				estate_wr	=> open,
				-- Reading Interface
				got				=> '1',
				dout			=> open,
				valid			=> open,
				fstate_rd	=> open,
				commit		=> '1',
				rollback	=> '0'
			);
	
	end block;

	blkIO : block
	
	begin
		io1 : entity PoC.io_7SegmentMux_BCD
			generic map (
				CLOCK_FREQ			=> 100 MHz,
				REFRESH_RATE		=> 1 kHz,
				DIGITS					=> 4
			)
			port map (
				Clock						=> clk1,
				
				BCDDigits				=> (others => (others => '0')),
				BCDDots					=> (others => '1'),
				
				SegmentControl	=> open,
				DigitControl		=> open
			);
			
		io2 : entity PoC.io_7SegmentMux_HEX
			generic map (
				CLOCK_FREQ			=> 100 MHz,
				REFRESH_RATE		=> 1 kHz,
				DIGITS					=> 4
			)
			port map (
				Clock						=> clk1,
				
				HEXDigits				=> (others => (others => '0')),
				HEXDots					=> (others => '1'),
				
				SegmentControl	=> open,
				DigitControl		=> open
			);
	
	end block;
	
	blkMisc : block
	
	begin
		misc1 : entity PoC.misc_Delay
			generic map (
				BITS			=> 8,
				TAPS			=> (3, 5, 7, 12)
			)
			port map (
				Clock			=> clk1,
				Reset			=> rst1,
				Enable		=> '1',
				DataIn		=> x"A6",
				DataOut		=> open
			);
		
		misc3 : entity PoC.misc_PulseTrain
			generic map (
				PULSE_TRAIN				=> "101000101010"
			)
			port map (
				Clock							=> clk1,
				StartSequence			=> rst1,
				SequenceCompleted	=> open,
				Output						=> open
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
				I							=> x"458529A4",
				O							=> open,
				Valid					=> open
			);
	
		blkSync : block
		
		begin
			sync1 : entity PoC.sync_Vector
				generic map (
					MASTER_BITS		=> 6,
					SLAVE_BITS		=> 2
				)
				port map (
					Clock1				=> clk1,
					Clock2				=> clk2,
					Input					=> x"34",
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


