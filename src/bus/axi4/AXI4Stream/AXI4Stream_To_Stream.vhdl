
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.components.all;
use			PoC.utils.all;


entity AXI4Stream_To_Stream is
	generic (
		DATA_BITS					: positive																								:= 8
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Port
		In_tValid					: in	std_logic;
		In_tData					: in	std_logic_vector(DATA_BITS - 1 downto 0);
		In_tLast					: in	std_logic;
		In_tReady					: out	std_logic;
		-- OUT Port
		Out_Valid					: out	std_logic;
		Out_Data					: out	std_logic_vector(DATA_BITS - 1 downto 0);
		Out_SOF						: out	std_logic;
		Out_EOF						: out	std_logic;
		Out_Ack						: in	std_logic
	);
end entity;


architecture rtl of AXI4Stream_To_Stream is

  signal started : std_logic := '0';

begin

  started     <= ffrs(q => started, rst => ((In_tValid and In_tLast) or Reset), set => (In_tValid)) when rising_edge(Clock);
  
  Out_Valid   <= In_tValid;
  Out_Data    <= In_tData;
  Out_SOF     <= In_tValid and not started;
  Out_EOF     <= In_tLast;
  In_tReady   <= Out_Ack;
	
end architecture;
