
library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	poc;
use			poc.config.all;
use			poc.utils.all;
use			poc.ocram.ocram_sdp;


entity fifo_cc_got_commit is
  generic (
    D_BITS         : positive;          -- Data Width
    NUM_FRAMES     : positive;          -- Number of Frames in FIFO
    MIN_DEPTH      : positive;          -- Minimum FIFO Depth
    DATA_REG       : boolean  := false;  -- Store Data Content in Registers
    STATE_REG      : boolean  := false;  -- Registered Full/Empty Indicators
    OUTPUT_REG     : boolean  := false;  -- Registered FIFO Output
    ESTATE_WR_BITS : positive := 1;      -- Empty State Bits
    FSTATE_RD_BITS : positive := 1       -- Full State Bits
  );
  port (
    -- Global Reset and Clock
    rst, clk     : in  std_logic;

    -- Writing Interface
    put          : in  std_logic;                            -- Write Request
    din          : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
    full         : out std_logic;
    estate_wr    : out std_logic_vector(ESTATE_WR_BITS-1 downto 0);

    save         : in  std_logic;
    drop         : in  std_logic;

    -- Reading Interface
    got          : in  std_logic;                            -- Read Completed
    dout         : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
    valid        : out std_logic;
    last         : out std_logic;
    fstate_rd    : out std_logic_vector(FSTATE_RD_BITS-1 downto 0);

    commit       : in  std_logic;
    rollback     : in  std_logic
  );
end entity;


architecture rtl of fifo_cc_got_commit is

  -- Address Width
  constant A_BITS : natural := log2ceil(MIN_DEPTH);
  constant C_BITS : natural := log2ceil(NUM_FRAMES);

  -- Force Carry-Chain Use for Pointer Increments on Xilinx Architectures
  constant FORCE_XILCY : boolean := (not SIMULATION) and (VENDOR = VENDOR_XILINX) and STATE_REG and (A_BITS > 4);

  -----------------------------------------------------------------------------
  -- Memory Pointers
  subtype T_Pointer is unsigned(A_BITS-1 downto 0);
  type    T_Pointer_vec is array (natural range <>) of T_Pointer;

  -- Actual Input and Output Pointers
  signal IP0 : T_Pointer := (others => '0');
  signal OP0 : T_Pointer := (others => '0');

  -- Incremented Input and Output Pointers
  signal IP1 : T_Pointer;
  signal OP1 : T_Pointer;

  -- Committed Pointer (Commit Marker)
  signal CP : T_Pointer_vec(0 to NUM_FRAMES -1) := (others => (others => '0'));  
  signal NumC : unsigned(C_BITS-1 downto 0):= (others => '0');
  
  function drop_Commit(CP : T_Pointer_vec(0 to NUM_FRAMES -1)) return T_Pointer_vec is
   variable temp : T_Pointer_vec(0 to NUM_FRAMES -1) := (others => (others => '0'));
  begin
    for i in 1 to NUM_FRAMES -1 loop
      temp(i -1) := CP(i);
    end loop;
    return temp;
  end function;  
  
  function drop_Commit(NumC : unsigned(C_BITS-1 downto 0)) return unsigned is
  	variable temp : unsigned(C_BITS-1 downto 0) := ite(to_integer(NumC) = 0, (C_BITS-1 downto 0 => '0'), NumC -1);
  begin
    return temp;
  end function;


  -----------------------------------------------------------------------------
  -- Backing Memory Connectivity

  -- Write Port
  signal wa : unsigned(A_BITS-1 downto 0);
  signal we : std_logic;

  -- Read Port
  signal ra : unsigned(A_BITS-1 downto 0);
  signal re : std_logic;

  -- Internal full and empty indicators
  signal fulli : std_logic;
  signal empti : std_logic;
  signal emptc : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Pointer Logic
	blkPointer : block
		signal IP0_slv		: std_logic_vector(IP0'range);
		signal IP1_slv		: std_logic_vector(IP0'range);
		signal OP0_slv		: std_logic_vector(IP0'range);
		signal OP1_slv		: std_logic_vector(IP0'range);
	begin
		IP0_slv	<= std_logic_vector(IP0);
		OP0_slv	<= std_logic_vector(OP0);

		incIP : entity PoC.arith_carrychain_inc
			generic map (
				BITS		=> A_BITS
			)
			port map (
				X				=> IP0_slv,
				Y				=> IP1_slv
			);

		incOP : entity PoC.arith_carrychain_inc
			generic map (
				BITS		=> A_BITS
			)
			port map (
				X				=> OP0_slv,
				Y				=> OP1_slv
			);

		IP1			<= unsigned(IP1_slv);
		OP1			<= unsigned(OP1_slv);
	end block;


  process(clk)
    variable CP_tmp    : T_Pointer_vec(0 to NUM_FRAMES -1);
    variable NumC_tmp  : unsigned(C_BITS-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        IP0  <= (others => '0');
        OP0  <= (others => '0');
        CP   <= (others => (others => '0'));   
        NumC <= (others => '0');  
      else
        CP_tmp   := CP;
        NumC_tmp := NumC;
        
        -- Update Input Pointer upon Write
        if drop = '1' then
          IP0 <= CP(to_integer(NumC));
        elsif we = '1' then
          IP0 <= IP1;
        end if;
   
        -- Update Output Pointer upon Read or Rollback     
        if rollback = '1' then
          OP0 <= CP(0);
        elsif re = '1' then
          OP0 <= OP1;
        end if;

        -- Update Commit Marker
        if save = '1' and IP0 /= CP(to_integer(NumC)) then
          NumC_tmp := NumC_tmp +1;
          if we = '1' then
            CP_tmp(to_integer(NumC_tmp)) := IP1;
          else
            CP_tmp(to_integer(NumC_tmp)) := IP0;
          end if;
        end if;
        
        if commit = '1' and to_integer(NumC) > 0 then
          CP_tmp   := drop_Commit(CP_tmp);
          NumC_tmp := drop_Commit(NumC_tmp);
        end if;
        
        CP   <= CP_tmp;
        NumC <= NumC_tmp;
      end if;
    end if;
  end process;
  
  wa <= IP0;
  ra <= OP0;

  -- Fill State Computation (soft indicators)
  process(fulli, IP0, OP0, CP, NumC)
    variable  d : std_logic_vector(A_BITS-1 downto 0);
  begin

    -- Available Space
    if ESTATE_WR_BITS > 0 then
      -- Compute Pointer Difference
      if fulli = '1' then
        d := (others => '1');              -- true number minus one when full
      else
        d := std_logic_vector(IP0 - CP(0));  -- true number of valid entries
      end if;
      estate_wr <= not d(d'left downto d'left-ESTATE_WR_BITS+1);
    else
      estate_wr <= (others => 'X');
    end if;

    -- Available Content
    if FSTATE_RD_BITS > 0 then
      -- Compute Pointer Difference
      if fulli = '1' then
        d := (others => '1');              -- true number minus one when full
      else
        d := std_logic_vector(CP(to_integer(NumC)) - OP0);  -- true number of valid entries
      end if;
      fstate_rd <= d(d'left downto d'left-FSTATE_RD_BITS+1);
    else
      fstate_rd <= (others => 'X');
    end if;

  end process;

  -----------------------------------------------------------------------------
  -- Computation of full and empty indications.
  --
  -- The STATE_REG generic is ignored as two different comparators are
  -- needed to compare OP with IPm (empty) and IP with OP (full) anyways.
  -- So the register implementation is always used.
  blkState: block
    signal Ful     : std_logic := '0';
    signal Avl     : std_logic := '0';
    signal fullc   : std_logic;
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          Ful     <= '0';
          Avl     <= '0';
        else
          Ful <= '0';
          Avl <= '0';

          -- Update Full Indicator
          if IP1 = CP(0) or fullc = '1' then
            Ful <= '1';
          end if;

          -- Update Empty Indicator
          if NumC > 0 and OP1 /= CP(to_integer(NumC)) then
            Avl <= '1';
          end if;

        end if;
      end if;
    end process;
    fulli <= Ful and fullc;
    empti <= not Avl;
    fullc <= '1' when NumC = NUM_FRAMES -1 else '0';
  end block;


  -----------------------------------------------------------------------------
  -- Memory Access

  -- Write Interface => Input
  full <= fulli;
  we   <= put and not fulli;

  -- Backing Memory and Read Interface => Output
  genLarge: if not DATA_REG generate
    signal do : std_logic_vector(D_BITS-1 downto 0);
  begin

    -- Backing Memory
    ram : entity PoC.ocram_sdp
      generic map (
        A_BITS => A_BITS,
        D_BITS => D_BITS
      )
      port map (
        wclk   => clk,
        rclk   => clk,
        wce    => '1',

        wa     => wa,
        we     => we,
        d      => din,

        ra     => ra,
        rce    => re,
        q      => do
      );

    -- Read Interface => Output
    genOutputCmb : if not OUTPUT_REG generate
      signal Vld : std_logic := '0';      -- valid output of RAM module
    begin
      process(clk)
      begin
        if rising_edge(clk) then
          if rst = '1' then
            Vld <= '0';
          else
            Vld <= (Vld and not got) or not empti;
          end if;
        end if;
      end process;
      re    <= (not Vld or got) and not empti;
      dout  <= do;
      valid <= Vld;
      
      process(OP0, CP, NumC)
      begin
        last <= '0';
        for i in 0 to to_integer(NumC) loop
          if CP(i) = OP0 then
            last <= '1';
          end if;
        end loop;
      end process;
    end generate genOutputCmb;

    genOutputReg: if OUTPUT_REG generate
      -- Extra Buffer Register for Output Data
      signal Buf : std_logic_vector(D_BITS-1 downto 0) := (others => '-');
      signal Vld : std_logic_vector(0 to 1)            := (others => '0');
      -- Vld(0)   -- valid output of RAM module
      -- Vld(1)   -- valid word in Buf
    begin
      process(clk)
      begin
        if rising_edge(clk) then
          if rst = '1' then
            Buf <= (others => '-');
            Vld <= (others => '0');
          else
            Vld(0) <= (Vld(0) and Vld(1) and not got) or not empti;
            Vld(1) <= (Vld(1) and not got) or Vld(0);
            if Vld(1) = '0' or got = '1' then
              Buf <= do;
            end if;
            
            last <= '0';
            for i in 0 to to_integer(NumC) loop
              if CP(i) = OP0 then
                last <= '1';
              end if;
            end loop;
          end if;
        end if;
      end process;
      re    <= (not Vld(0) or not Vld(1) or got) and not empti;
      dout  <= Buf;
      valid <= Vld(1);
    end generate genOutputReg;

  end generate genLarge;

  genSmall: if DATA_REG generate

    -- Memory modelled as Array
    type regfile_t is array(0 to 2**A_BITS-1) of std_logic_vector(D_BITS-1 downto 0);
    signal regfile : regfile_t;
    attribute ram_style            : string;  -- XST specific
    attribute ram_style of regfile : signal is "distributed";

    -- Altera Quartus II: Allow automatic RAM type selection.
    -- For small RAMs, registers are used on Cyclone devices and the M512 type
    -- is used on Stratix devices. Pass-through logic is automatically added
    -- if required. (Warning can be ignored.)

  begin

    -- Memory State
    process(clk)
    begin
      if rising_edge(clk) then
        --synthesis translate_off
        if SIMULATION and (rst = '1') then
          regfile <= (others => (others => '-'));
        else
        --synthesis translate_on
          if we = '1' then
            regfile(to_integer(wa)) <= din;
          end if;
        --synthesis translate_off
        end if;
        --synthesis translate_on
      end if;
    end process;

    -- Memory Output
    re    <= got and not empti;
    dout  <= (others => 'X') when Is_X(std_logic_vector(ra)) else
             regfile(to_integer(ra));
    valid <= not empti;
    
    process(OP0, CP, NumC)
    begin
      last <= '0';
      for i in 0 to to_integer(NumC) loop
        if CP(i) = OP0 then
          last <= '1';
        end if;
      end loop;
    end process;

  end generate genSmall;

end architecture;
