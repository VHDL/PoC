library IEEE;
use     IEEE.std_logic_1164.all;


package led is
	type T_IO_LED_COLORED_RGB is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
	end record;
	type T_IO_LED_COLORED_RGB_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGB;
	
	type T_IO_LED_COLORED_RGBW is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
		W : std_logic;
	end record;
	type T_IO_LED_COLORED_RGBW_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGBW;
	
	type T_IO_LED_COLORED_RGBWW is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
		WW : std_logic; --Warm White
		CW : std_logic; --Cold White
	end record;
	type T_IO_LED_COLORED_RGBWW_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGBWW;
end package;
