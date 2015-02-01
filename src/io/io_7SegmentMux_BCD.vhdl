library	IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.physical.all;
use			PoC.components.all;
use			PoC.io.all;


entity io_7SegmentMux_BCD is
	generic (
		CLOCK_FREQ			: FREQ				:= 100 MHz;
		REFRESH_RATE		: FREQ				:= 1 kHz;
		DIGITS					: POSITIVE		:= 4
	);
  port (
	  Clock						: in	STD_LOGIC;
		
		BCDDigits				: in	T_BCD_VECTOR(DIGITS - 1 downto 0);
		BCDDots					: in	STD_LOGIC_VECTOR(DIGITS - 1 downto 0);
		
		SegmentControl	: out	STD_LOGIC_VECTOR(7 downto 0);
		DigitControl		: out	STD_LOGIC_VECTOR(DIGITS - 1 downto 0)
	);
end;

architecture rtl of io_7SegmentMux_BCD is
	signal DigitCounter_rst		: STD_LOGIC;
	signal DigitCounter_en		: STD_LOGIC;
	signal DigitCounter_us		: UNSIGNED(log2ceilnz(DIGITS) - 1 downto 0)	:= (others => '0');
begin
	
	Strobe : entity PoC.misc_StrobeGenerator
		generic map (
			STROBE_PERIOD_CYCLES	=> TimingToCycles(to_time(REFRESH_RATE), CLOCK_FREQ),
			INITIAL_STROBE				=> FALSE
		)
		port map (
			Clock		=> Clock,
			O				=> DigitCounter_en
		);
	
	-- 
	DigitCounter_rst	<= counter_eq(DigitCounter_us, DIGITS - 1) and DigitCounter_en;
	DigitCounter_us		<= counter_inc(DigitCounter_us, DigitCounter_rst, DigitCounter_en) when rising_edge(Clock);
	DigitControl			<= resize(bin2onehot(std_logic_vector(DigitCounter_us)), DigitControl'length);

	process(BCDDigits, BCDDots, DigitCounter_us)
		variable BCDDigit : T_BCD;
		variable BCDDot 	: STD_LOGIC;
	begin
		BCDDigit	:= BCDDigits(to_index(DigitCounter_us, BCDDigits'length));
		BCDDot		:= BCDDots(to_index(DigitCounter_us, BCDDigits'length));
	
		if (BCDDigit < C_BCD_MINUS) then
			SegmentControl	<= io_7SegmentDisplayEncoding(BCDDigit, BCDDot);
		elsif (BCDDigit = C_BCD_MINUS) then
			SegmentControl	<= BCDDot & "1000000";
		else
			SegmentControl	<= "00000000";
		end if;
	end process;
end;
