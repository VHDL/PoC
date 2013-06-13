--
-- Copyright (c) 2008
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: ocram_sdp
-- Author(s):
--      Martin Zabel <martin.zabel@tu-dresden.de>
--      Thomas B. Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Inferring / instantiating simple dual-port memory.
--
-- - dual clock, clock enable
-- - 1 read port plus 1 write port
-- 
-- Reading at write address returns unknown data. Putting the different RAM
-- behaviours (Altera, Xilinx, some ASICs) together, then the Altera M512/M4K
-- TriMatrix memory defines the minimum time after which the written data can
-- be read out again. As stated in the Stratix Handbook, Volum2, page 2-13, the
-- data is actually written with the falling (instead of the rising) edge of
-- the clock. So that data can be read out after half of the write-clock period
-- plus the write-cycle time.
--
-- To generalize this behaviour, it can be assumed, that written data is 
-- available at the read-port with the next rising write!-clock edge. Both,
-- read- and write-clock edge might be at the same time, to satisfy this rule.
-- An example would be, that write- and read-clock are the same.
--
-- If latency is an issue, then memory blocks should be directly instantiated.
--
-- Revision:    $Revision: 1.8 $
-- Last change: $Date: 2012-09-26 12:51:59 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.config.all;

entity ocram_sdp is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    rclk : in  std_logic;                             -- read clock
    rce  : in  std_logic;                             -- read clock-enable
    wclk : in  std_logic;                             -- write clock
    wce  : in  std_logic;                             -- write clock-enable
    we   : in  std_logic;                             -- write enable
    ra   : in  unsigned(A_BITS-1 downto 0);           -- read address
    wa   : in  unsigned(A_BITS-1 downto 0);           -- write address
    d    : in  std_logic_vector(D_BITS-1 downto 0);   -- data in
    q    : out std_logic_vector(D_BITS-1 downto 0));  -- data out

end ocram_sdp;

architecture rtl of ocram_sdp is

  constant DEPTH : positive := 2**A_BITS;
  
begin  -- rtl

  gInfer: if VENDOR = VENDOR_XILINX generate
    -- RAM can be infered correctly
    -- Implementation notes:
    --   WRITE_MODE is set to WRITE_FIRST, but this also means that read data
    --   is unknown on the opposite port. (As expected.)
    type ram_t is array(0 to DEPTH-1) of std_logic_vector(D_BITS-1 downto 0);
    signal ram : ram_t;
  begin
    process (wclk)
    begin
      if rising_edge(wclk) then
        if (wce and we) = '1' then
          ram(to_integer(wa)) <= d;
        end if;
      end if;
    end process;

    process (rclk)
    begin
      if rising_edge(rclk) then
        -- read data doesn't care, when reading at write address
        if rce = '1' then
          if Is_X(std_logic_vector(ra)) then
            q <= (others => 'X');
          else
            q <= ram(to_integer(ra));
          end if;
        end if;
      end if;
    end process;
  end generate gInfer;

  gAltera: if VENDOR = VENDOR_ALTERA generate
    -- Direct instantiation of altsyncram (including component
    -- declaration above) is not sufficient for ModelSim.
    -- That requires also usage of altera_mf library.
    component ocram_sdp_altera
      generic (
        A_BITS : positive;
        D_BITS : positive
      );
      port (
        rclk : in  std_logic;
        wclk : in  std_logic;
        rce  : in  std_logic;
        wce  : in  std_logic;
        we   : in  std_logic;
        ra   : in  unsigned(A_BITS-1 downto 0);
        wa   : in  unsigned(A_BITS-1 downto 0);
        d    : in  std_logic_vector(D_BITS-1 downto 0);
        q    : out std_logic_vector(D_BITS-1 downto 0)
      );
    end component;
  begin
    i: ocram_sdp_altera
      generic map (
        A_BITS => A_BITS,
        D_BITS => D_BITS)
      port map (
        rclk => rclk,
        wclk => wclk,
        rce  => rce,
        wce  => wce,
        we   => we,
        ra   => ra,
        wa   => wa,
        d    => d,
        q    => q);
    
  end generate gAltera;
  
  assert VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA
    report "Device not yet supported."
    severity failure;
end rtl;
