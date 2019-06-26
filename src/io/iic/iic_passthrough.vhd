
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library PoC;
use PoC.utils.all;
use PoC.physical.all;
use PoC.io.all;
use PoC.iic.all;

entity iic_passthrough is
	generic (
		CLOCK_FREQ     : FREQ    := 100 MHz;
		DEBOUNCE_TIME  : T_TIME  := 50.0e-9;
		SYNC_BITS      : natural := 3
	);
  port (
		reset   : in    std_logic;
		clock   : in    std_logic;
  	port_a  : inout T_IO_IIC_SERIAL;
		port_b  : inout T_IO_IIC_SERIAL;
		debug   : out   T_IO_IIC_SERIAL_PCB
--        stall   : out   std_logic;
--        timeout : in    std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of iic_passthrough is
	constant cycles  : natural := TimingToCycles(DEBOUNCE_TIME, CLOCK_FREQ);
	constant c_data  : natural := 0;
	constant c_clock : natural := 0;
  
  signal debug_level     : std_logic_vector(1 downto 0);

	signal a_level         : std_logic_vector(1 downto 0);
	signal b_level         : std_logic_vector(1 downto 0);
	signal a_set           : std_logic_vector(1 downto 0) := (others => '0');
	signal b_set           : std_logic_vector(1 downto 0) := (others => '0');
  

  type t_state is (IDLE, ST_A, ST_A_WAIT, ST_B, ST_B_WAIT);



begin
	--SCL
	port_a.clock.O     <= '0';
	port_a.clock.T     <= not a_set(c_clock);
	
	port_b.clock.O     <= '0';
	port_b.clock.T     <= not b_set(c_clock);
	
	debug.clock        <= debug_level(c_clock);
	
	--SDA
	port_a.data.O     <= '0';
	port_a.data.T     <= not a_set(c_data);
	
	port_b.data.O     <= '0';
	port_b.data.T     <= not b_set(c_data);
	
	debug.data        <= debug_level(c_data);

  
  sync : entity poc.sync_Bits
  generic map(
    BITS          => 4,
    INIT          => x"FFFFFFFF",
    SYNC_DEPTH    => 2
  )
  port map(
    Clock         => clock,
    Input(0)      => port_a.data.I,
    Output(0)     => a_level(c_data),
    Input(1)      => port_b.data.I,
    Output(1)     => b_level(c_data),
    Input(2)      => port_a.clock.I,
    Output(2)     => a_level(c_clock),
    Input(3)      => port_b.clock.I,
    Output(3)     => b_level(c_clock)
  );



	fsm_gen : for i in 0 to 1 generate
		  signal state : t_state := IDLE;
		  signal wait_count : integer range 0 to cycles := cycles -1;
	begin
		debug_level(i) <= '0' when state /= IDLE else '1';
		
		fsm : process(clock)
		begin
			if rising_edge(clock) then
				a_set(i) <= '0';
				b_set(i) <= '0';
				
				if reset = '1' then
					state      <= IDLE;
					wait_count <= cycles -1;
				else
					case state is
						when IDLE => 
							wait_count <= cycles -1;
							if a_level(i) = '0' then 
								state      <= ST_A;
								b_set(i)   <= '1';
							end if;
							if b_level(i) = '0' then 
								state    <= ST_B;
								a_set(i) <= '1';
							end if;
							
						when ST_A => 
							b_set(i) <= '1';
							if wait_count = 0 then 
								if a_level(i) = '1' then 
									state  <= IDLE;
								end if;
							else 
								wait_count <= wait_count -1;
							end if;

							
						when ST_B => 
							a_set(i) <= '1';
							if wait_count = 0 then 
								if b_level(i) = '1' then 
									state  <= IDLE;
								end if;
							else 
								wait_count <= wait_count -1;
							end if;

					end case;
				end if;
			end if;
		end process;
  end generate;


end architecture;
