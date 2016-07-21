
--
-- Entity: comm_bitwidth_converter
-- Author(s): Patrick Lehmann
--						Max Koehler
--
-- Summary:
-- ========
--  This module convertes std_logic_vectors with different bit widths.
--	Up and down scaling is supported.
--
-- Description:
-- ============
--	Input "I" is of clock domain "Clock1"; output "O" is of clock domain "Clock2"
--	Optional output registers can be added by enabling (REGISTERED = TRUE).
--	In case of up scaling, input "Align" is required to mark byte 0 in the word.
--
-- Assertions:
-- ===========
--	- Clock periods of Clock1 and Clock2 MUST be multiples of each other.
--	- Clock1 and Clock2 MUST be phase aligned (related) to each other.


library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;


entity misc_BitwidthConverter is
  generic (
	  REGISTERED					: boolean			:= FALSE;												-- add output register @Clock2
		BITS1								: positive		:= 32;													-- input bit width
		BITS2								: positive		:= 16														-- output bit width
	);
  port (
	  Clock1							: in	std_logic;															-- input clock domain
		Clock2							: in	std_logic;															-- output clock domain
		Align								: in	std_logic;															-- align word (one cycle high impulse)
		I										: in	std_logic_vector(BITS1 - 1 downto 0);			-- input word
		O										: out std_logic_vector(BITS2 - 1 downto 0)			-- output word
	);
end entity;

architecture rtl of misc_BitwidthConverter is
	constant BITS_1				: positive	:= BITS1;
	constant BITS_2				: positive	:= BITS2;

	constant BITS_RATIO		: REAL			:= real(BITS1) / real(BITS2);
	constant SMALLER			: boolean		:= BITS_RATIO > 1.0;

	constant COUNTER_BITS : positive	:= log2ceil(integer(ite(SMALLER, BITS_RATIO, (1.0 / BITS_RATIO))));

begin
	-- word to byte splitter
	gen1 : if (SMALLER = TRUE) generate
		type SLV_mux is array (natural range <>) of std_logic_vector(BITS2 - 1 downto 0);

		signal WordBoundary			: std_logic;
		signal WordBoundary_d		: std_logic;
		signal Align_i					: std_logic;

		signal I_d							: std_logic_vector(BITS1 - 1 downto 0);
		signal MuxInput					: SLV_mux(2**COUNTER_BITS - 1 downto 0);
		signal MuxOutput				: std_logic_vector(BITS2 - 1 downto 0);
		signal MuxCounter_us		: unsigned(COUNTER_BITS - 1 downto 0)					:= (others => '0');
		signal MuxSelect_us			: unsigned(COUNTER_BITS - 1 downto 0);

	begin
		-- input register @Clock1
		process(Clock1)
		begin
			if rising_edge(Clock1) then
				I_d	<= I;
			end if;
		end process;

		-- selection multiplexer
		gen11 : for j in 2**COUNTER_BITS - 1 downto 0 generate
			MuxInput(J)	<= I_d(((J + 1) * BITS_2) - 1 downto (J * BITS_2));
		end generate;

		-- multiplexer
		MuxOutput <= MuxInput(to_integer(MuxSelect_us));

		-- word boundary T-FF @Clock1 and D-FF @Clock2
		WordBoundary		<= not WordBoundary when rising_edge(Clock1) else WordBoundary;
		WordBoundary_d	<= WordBoundary			when rising_edge(Clock2) else WordBoundary_d;

		-- generate Align_i signal
		Align_i <= WordBoundary xor WordBoundary_d;

		-- multiplexer control @Clock2
		process(Clock2)
		begin
			if rising_edge(Clock2) then
				if (Align_i = '1') then
					MuxCounter_us		<= to_unsigned(1, MuxCounter_us'length);
				else
					MuxCounter_us		<= MuxCounter_us + 1;
				end if;
			end if;
		end process;

		MuxSelect_us <= (others => '0') when (Align_i = '1') else MuxCounter_us;

		-- add output register @Clock2
		gen121 : if (REGISTERED = TRUE) generate
			process(Clock2)
			begin
				if rising_edge(Clock2) then
					O <= MuxOutput;
				end if;
			end process;
		end generate;
		gen122 : if (REGISTERED = FALSE) generate
			O <= MuxOutput;
		end generate;
	end generate;


	-- byte to word collection
	gen2 : if (SMALLER = FALSE) generate
		signal I_Counter_us					: unsigned(COUNTER_BITS - 1 downto 0)						:= (others => '0');
		signal I_Select_us					: unsigned(COUNTER_BITS - 1 downto 0);
		signal I_d									:	std_logic_vector(BITS2 - BITS1 - 1 downto 0);
		signal Collected						: std_logic_vector(BITS2 - 1 downto 0);
		signal Collected_d					: std_logic_vector(BITS2 - 1 downto 0);

	begin
		-- byte alignment counter @Clock1
		process(Clock1)
		begin
			if rising_edge(Clock1) then
				if (Align = '1') then
					I_Counter_us		<= to_unsigned(1, I_Counter_us'length);
				else
					I_Counter_us		<= I_Counter_us + 1;
				end if;
			end if;
		end process;

		I_Select_us <= (others => '0') when (Align = '1') else I_Counter_us;

		-- delay registers @Clock1
		process(Clock1)
		begin
			if rising_edge(Clock1) then
				for j in 2**COUNTER_BITS - 2 downto 0 loop
					if J = to_integer(I_Select_us) then					-- d-FF enable
						for k in BITS1 - 1 downto 0 loop
							I_d((J * BITS1) + K) <= I(K);
						end loop;
					end if;
				end loop;
			end if;
		end process;

		-- collect signals
		Collected <= I & I_d;

		-- register collected signals again @Clock1
		process(Clock1)
		begin
			if rising_edge(Clock1) then
				if (to_integer(I_Select_us) = (2**COUNTER_BITS - 1)) then
					Collected_d <= Collected;
				end if;
			end if;
		end process;

		-- add output register @Clock2
		gen211 : if (REGISTERED = TRUE) generate
			process(Clock2)
			begin
				if rising_edge(Clock2) then
					O <= Collected_d;
				end if;
			end process;
		end generate;
		gen212 : if (REGISTERED = FALSE) generate
			O <= Collected_d;
		end generate;
	end generate;
end;
