library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library L_SATAController;
use 	L_SATAController.SATATypes.ALL;

entity sata_oob_rx is port (
		clk		: in std_logic;
		rx_signaldetect	: in std_logic;
		rx_oob_status	: out T_SATA_OOB
	);
end sata_oob_rx;

architecture rtl of sata_oob_rx is
		
	signal sig_count	: unsigned (3 downto 0) := (others => '0');
	signal wake_count	: unsigned (3 downto 0) := (others => '0');
	signal reset_count	: unsigned (3 downto 0) := (others => '0');
	signal ui_counter	: unsigned (5 downto 0) := (others => '0');

	signal rx_signal_async	: std_logic;
	signal rx_signal	: std_logic_vector(1 downto 0);
	
begin
	-- input is at rx clock domain, so sample it first
	rx_signal_async <= rx_signaldetect when rising_edge(clk);
	rx_signal <= rx_signal(0) & rx_signal_async when rising_edge(clk);

	-- four counters to detect oob sequences
	process(clk) begin
		-- detect oob-signals
		if rising_edge(clk) then
			-- signal detection
			if rx_signal = "10" then
				-- end of signal / start of idle
				if ui_counter >= to_unsigned(6,6) and ui_counter <= to_unsigned(24,6) then -- 60ns ... 160ns
					sig_count <= sig_count + 1;
				end if;
			elsif rx_signal = "01" then
				-- start of signal / end of idle
				if ui_counter >= to_unsigned(6,6) and ui_counter <= to_unsigned(24,6) then -- 60ns ... 160ns
					wake_count <= wake_count + 1;
				end if;
				if ui_counter >= to_unsigned(36,6) and ui_counter <= to_unsigned(56,6) then -- 240ns ... 370ns
					reset_count <= reset_count + 1;
				end if;
			else
				-- signal length counter is beyond all limits -> reset
				if ui_counter > to_unsigned(56,6) then 
					sig_count <= (others => '0');
					wake_count <= (others => '0');
					reset_count <= (others => '0');
				end if;	
			end if;
			-- signal length counter control
			if rx_signal(1) /= rx_signal(0) then
				-- reset signal length counter
				ui_counter <= (others => '0');
			else
				-- signal length counter saturation check
				if ui_counter < to_unsigned(63,6) then
					ui_counter <= ui_counter + 1;
				end if;
			end if;
		end if;
	end process;

	-- oob output status register
	process(clk) begin
		if rising_edge(clk) then
			if sig_count > to_unsigned(3,4) then
				if sig_count = reset_count then
					rx_oob_status <= SATA_OOB_COMRESET;
				elsif sig_count = wake_count then
					rx_oob_status <= SATA_OOB_COMWAKE;
				end if;
			else
				if rx_signal(0) = '1' then
					rx_oob_status <= SATA_OOB_NONE;
				else
					rx_oob_status <= SATA_OOB_READY;
				end if;
			end if;
		end if;
	end process;
	
end;
