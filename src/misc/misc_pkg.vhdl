


	-- This module convertes std_logic_vectors with different bit widths.
--	component comm_bitwidth_converter is
--		generic (
--			REGISTERED : boolean := false;		-- add output register @Clock2
--			BW1				: positive;						-- input bit width
--			BW2				: positive						 -- output bit width
--		);
--		port (
--			Clock1 : in	std_logic;					 -- input clock domain
--			Clock2 : in	std_logic;					 -- output clock domain
--			Align	: in	std_logic;					 -- align word (one cycle high impulse)
--			I			: in	std_logic_vector(BW1-1 downto 0);	-- input word
--			O			: out std_logic_vector(BW2-1 downto 0)	 -- output word
--		);
--	end component;