
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.components.all;
use			PoC.vectors.all;


entity Stream_To_AXI4Stream is
	generic (
		DATA_BITS					: positive	:= 8
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Port
		In_Valid					: in	std_logic;
		In_Data						: in	std_logic_vector(DATA_BITS - 1 downto 0);
		In_SOF						: in	std_logic;
		In_EOF						: in	std_logic;
		In_Ack						: out	std_logic;
		-- OUT Port
		Out_tValid				: out	std_logic;
		Out_tData					: out	std_logic_vector(DATA_BITS - 1 downto 0);
		Out_tLast					: out	std_logic;
		Out_tReady				: in	std_logic
	);
end entity;


architecture rtl of Stream_To_AXI4Stream is

  signal started : std_logic := '0';

begin

  started     <= ffrs(q => started, rst => ((In_Valid and In_EOF) or Reset), set => (In_Valid and In_SOF)) when rising_edge(Clock);
  
	Out_tValid <= In_Valid and (started or In_SOF);
  Out_tData  <= In_Data;
  Out_tLast  <= In_EOF;
  In_Ack     <= Out_tReady;

end architecture;
