library IEEE;
use IEEE.std_logic_1164.all;

entity inc_ovcy_xilinx is
  generic (
    N : positive                             -- Bit Width
  );
  port (
    p : in  std_logic_vector(N-1 downto 0);  -- Argument
    g : in  std_logic;                       -- Increment Guard
    v : out std_logic                        -- Overflow Output
  );
end inc_ovcy_xilinx;

library UNISIM;
use UNISIM.vcomponents.all;

architecture rtl of inc_ovcy_xilinx is
  signal c : std_logic_vector(N downto 0);  -- Carry Chain Links
begin  -- rtl

  -- Feed Chain with Guard
  c(0) <= g;

  -- Instantiate Carry Chain
  genCC: for i in 0 to N-1 generate
    m : MUXCY
      port map (
        O  => c(i+1),
        CI => c(i),
        DI => '0',
        S  => p(i)
      );
  end generate genCC;

  -- Output from final Carry
  v <= c(N);

end rtl;
