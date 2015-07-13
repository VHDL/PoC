------------------------------------------------------
-- trace_testbed.vhdl                               --
--                                                  --
-- Stefan Alex                                      --
-- Technische Universitaet Dresden                  --
------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

library poc;
use poc.functions.all;

use poc.trace_config.all;
use poc.trace.all;

use poc.v5temac.all;

library common;
use common.config.all;

entity trace_testbed is
  port (

    -- globals
    clk_trc  : in  std_logic;
    rst_in_n : in  std_logic;
    led      : out std_logic_vector(7 downto 0);


    CLK_FPGA_P : in std_logic;         -- TODO: required for REFCLK
    CLK_FPGA_N : in std_logic;

    -- Ethernet PHY signals (alphabetical)
    PHY_COL        : in    std_logic;
    PHY_CRS        : in    std_logic;
    PHY_INT        : in    std_logic;
    PHY_MDC        : out   std_logic;
    PHY_MDIO       : inout std_logic;
    PHY_RESET      : out   std_logic;  -- low-active
    PHY_RXCLK      : in    std_logic;
    PHY_RXCTL_RXDV : in    std_logic;
    PHY_RXD        : in    std_logic_vector(7 downto 0);
    PHY_RXER       : in    std_logic;
    PHY_TXC_GTXCLK : out   std_logic;
    PHY_TXCLK      : in    std_logic;
    PHY_TXCTL_TXEN : out   std_logic;
    PHY_TXD        : out   std_logic_vector(7 downto 0);
    PHY_TXER       : out   std_logic
  );
end trace_testbed;

architecture Behavioral of trace_testbed is

  -- Reset
  signal rst_trc     : std_logic;
  signal rst_trc_r   : std_logic_vector(1 downto 0);

  -- clockgen-signals
  signal clk_sys       : std_logic;
  signal clk_gmii_tx   : std_logic;
  signal clk_gmii_rx   : std_logic;
  signal clk_delayctrl : std_logic;
  signal async_rst     : std_logic;
  signal rst_sys       : std_logic;
  signal rst_delayctrl : std_logic;
  
  -- ethernet-signals
  signal tr_data  : std_logic_vector(7 downto 0);
  signal tr_sof_n : std_logic;
  signal tr_eof_n : std_logic;
  signal tr_vld_n : std_logic;
  signal tr_rdy_n : std_logic;
  signal re_data  : std_logic_vector(7 downto 0);
  signal re_sof_n : std_logic;
  signal re_eof_n : std_logic;
  signal re_vld_n : std_logic;
  signal re_rdy_n : std_logic;
  
  -- fifo-signals
  signal trc_got        : std_logic;
  signal trc_valid      : std_logic;
  signal trc_last       : std_logic;
  signal trc_put        : std_logic;
  signal trc_full       : std_logic;
  signal trc_din        : std_logic_vector(7 downto 0);
  signal trc_dout       : std_logic_vector(7 downto 0);
  signal trc_eth_finish : std_logic;
  signal trc_header     : std_logic;
  signal trc_eth_err    : std_logic_vector(2 downto 0);

  signal inst_values        : std_logic_vector(INST_ADR_BITS-1 downto 0);
  signal inst_stbs          : std_logic_vector(INST_STB_BITS-1 downto 0);
  signal inst_branch_values : std_logic_vector(INST_BRANCH_BITS-1 downto 0);
  signal inst_branch_stbs   : std_logic_vector(INST_BRANCH_STB_BITS-1 downto 0);
  signal mem_adr_values     : std_logic_vector(MEM_ADR_BITS-1 downto 0);
  signal mem_adr_stbs       : std_logic_vector(MEM_ADR_STB_BITS-1 downto 0);
  signal mem_data_values    : std_logic_vector(MEM_DAT_BITS-1 downto 0);
  signal mem_data_stbs      : std_logic_vector(MEM_DAT_STB_BITS-1 downto 0);
  signal mem_source_values  : std_logic_vector(MEM_SOURCE_BITS-1 downto 0);
  signal mem_source_stbs    : std_logic_vector(MEM_SOURCE_STB_BITS-1 downto 0);
  signal mem_rw_values      : std_logic_vector(MEM_RW_BITS-1 downto 0);
  signal mem_rw_stbs        : std_logic_vector(MEM_RW_STB_BITS-1 downto 0);
  signal message_values     : std_logic_vector(MESSAGE_BITS-1 downto 0);
  signal message_stbs       : std_logic_vector(MESSAGE_STB_BITS-1 downto 0);

  signal statistic_incs : std_logic_vector(STAT_BITS-1 downto 0);
  signal statistic_rsts : std_logic_vector(STAT_BITS-1 downto 0);

  signal system_stall  : std_logic;
  signal trace_running : std_logic;

  signal ice_all     : std_logic_vector(ICE_REG_BITS-1 downto 0);
  signal ice_all_nxt : std_logic_vector(ICE_REG_BITS-1 downto 0);
  signal ice_1_r     : std_logic_vector(12 downto 0) := (others => '0');
  signal ice_2_r     : std_logic_vector(7 downto 0) := (others => '0');
  signal ice_set     : std_logic_vector(1 downto 0);
  signal ice_1_nxt   : std_logic_vector(12 downto 0) := (others => '0');
  signal ice_2_nxt   : std_logic_vector(7 downto 0) := (others => '0');

begin

  ice_all <= ice_2_r & ice_1_r;
  ice_1_nxt <= ice_all_nxt(12 downto 0);
  ice_2_nxt <= ice_all_nxt(20 downto 13);

  clk_proc : process(clk_trc)
  begin
    if rising_edge(clk_trc) then
      if rst_trc = '1' then
        ice_1_r   <= (others => '0');
        ice_2_r   <= (others => '0');
      else

        if ice_set(0) = '1' then
          ice_1_r <= ice_1_nxt;
        end if;

        if ice_set(1) = '1' then
          ice_2_r <= ice_2_nxt;
        end if;
      end if;

      -- reset synchronizer
      rst_trc_r(0) <= not rst_in_n;
      rst_trc_r(rst_trc_r'left downto 1) <= rst_trc_r(rst_trc_r'left-1 downto 0);
    end if;
  end process clk_proc;

  rst_trc <= rst_trc_r(rst_trc_r'left);

  trc_top_inst : trace_top
    port map (
      clk_trc            => clk_trc,
      clk_sys            => clk_sys,
      rst_trc            => rst_trc,
      rst_sys            => rst_sys,
      trace_running      => trace_running,
      inst_values        => inst_values,
      inst_stbs          => inst_stbs,
      inst_branch_values => inst_branch_values,
      inst_branch_stbs   => inst_stbs,
      mem_adr_values     => mem_adr_values,
      mem_adr_stbs       => mem_adr_stbs,
      mem_data_values    => mem_data_values,
      mem_data_stbs      => mem_data_stbs,
      mem_source_values  => mem_source_values,
      mem_source_stbs    => mem_source_stbs,
      mem_rw_values      => mem_rw_values,
      mem_rw_stbs        => mem_rw_stbs,
      message_values     => message_values,
      message_stbs       => message_stbs,
      statistic_incs     => statistic_incs,
      statistic_rsts     => statistic_rsts,
      trigger_out        => open,
      system_stall       => system_stall,
      regs_in            => ice_all,
      regs_out           => ice_all_nxt,
      store              => ice_set,
--      regs_in            => "0",
--      regs_out           => open,
--      store              => open,
      eth_full           => trc_full,
      eth_din            => trc_din,
      eth_put            => trc_put,
      eth_valid          => trc_valid,
      eth_last           => trc_last,
      eth_dout           => trc_dout,
      eth_got            => trc_got,
      header             => trc_header,
      eth_finish         => trc_eth_finish
    );

    led(7 downto 0) <= (others => '0');


  -------------------------------
  -- simulate the trace-inputs --
  -------------------------------

  inputs_blk : block

    signal test_counter_1_r   : unsigned(33 downto 0);
    signal tv1                : std_logic_vector(33 downto 0);

    signal bcode            : std_logic_vector(CORE_CNT*32-1 downto 0);
    signal bcode_stb        : std_logic_vector(CORE_CNT-1 downto 0);
    signal bcode_branch     : std_logic_vector(CORE_CNT*3-1 downto 0);
    signal mcode            : std_logic_vector(CORE_CNT*11-1 downto 0);
    signal mcode_stb        : std_logic_vector(CORE_CNT-1 downto 0);
    signal mcode_branch     : std_logic_vector(CORE_CNT*3-1 downto 0);
    signal mmcdp_ref          : std_logic_vector(CORE_CNT*REF_BITS-1 downto 0);
    signal mmcdp_ref_stb      : std_logic_vector(CORE_CNT-1 downto 0);
    signal mmcdp_offs         : std_logic_vector(CORE_CNT*OFFS_BITS-1 downto 0);
    signal mmcdp_offs_stb     : std_logic_vector(CORE_CNT-1 downto 0);
    signal mmcdp_data         : std_logic_vector(CORE_CNT*32-1 downto 0);
    signal mmcdp_data_stb     : std_logic_vector(CORE_CNT-1 downto 0);
    signal mmcdp_rw           : std_logic_vector(CORE_CNT-1 downto 0);
    signal mmcdp_rw_stb       : std_logic_vector(CORE_CNT-1 downto 0);
    signal wb_adr           : std_logic_vector(31 downto 0);
    signal wb_adr_stb       : std_logic;
    signal wb_data          : std_logic_vector(31 downto 0);
    signal wb_data_stb      : std_logic;
    signal wb_source        : std_logic_vector(log2ceilnz(CORE_CNT)-1 downto 0);
    signal wb_source_stb    : std_logic;
    signal wb_rw            : std_logic;
    signal wb_rw_stb        : std_logic;
    signal th               : std_logic_vector(CORE_CNT*REF_BITS-1 downto 0);
    signal th_stb           : std_logic_vector(CORE_CNT-1 downto 0);
    signal mmu              : std_logic_vector(31 downto 0);
    signal mmu_stb          : std_logic;
    signal mc               : std_logic_vector(CORE_CNT*32-1 downto 0);
    signal mc_stb           : std_logic_vector(CORE_CNT-1 downto 0);
    signal m                : std_logic_vector(CORE_CNT*32-1 downto 0);
    signal m_stb            : std_logic_vector(CORE_CNT-1 downto 0);
    signal gc_ref           : std_logic_vector(REF_BITS-1 downto 0);
    signal gc_ref_stb       : std_logic;
    signal ref              : std_logic_vector(REF_BITS-1 downto 0);
    signal ref_stb          : std_logic;
    signal mm_mov_1         : std_logic_vector(REF_BITS-1 downto 0);
    signal mm_mov_2         : std_logic_vector(BASE_BITS-1 downto 0);
    signal mm_mov_3         : std_logic_vector(1 downto 0);
    signal mm_mov_1_stb     : std_logic;
    signal mm_mov_2_stb     : std_logic;
    signal mm_mov_3_stb     : std_logic;

  begin

    -- generate test-vectors

    tv1 <= std_logic_vector(test_counter_1_r);

    -- clk-process

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        if rst_trc = '1' then
          test_counter_1_r <= (others => '0');
        else
          if trace_running = '1' then
            test_counter_1_r <= test_counter_1_r + 1;
          end if;
        end if;
      end if;
    end process clk_proc;

    -- bytecode/microcode-trace
    bcode_gen : for i in 0 to CORE_CNT-1 generate
      signal addr : std_logic_vector(31 downto 0);
      signal branch : std_logic;
    begin
      -- A new bytecode every 4 clock cycles.
      addr         <= tv1(33 downto 2);
      bcode_stb(i) <= '1' when tv1(1 downto 0) = "11" else '0';
      
      bcode((i+1)*32-1 downto (i*32))    <= addr;

      -- possible branch address
      branch <= '1' when addr(4 downto 0) = "10000" else '0';
      -- branch encoding: [2..0] = (indirect, direct, branch taken)
      bcode_branch(i*3+2) <= addr(9) and not addr(8) and branch;
      bcode_branch(i*3+1) <= not addr(9) and addr(8) and branch;
      bcode_branch(i*3  ) <= (addr(9) xor addr(8)) and branch and addr(5);

      -- microcode-trace uses the same instTracer as bytecode-trace
      -- so just increase required data bandwidth
      -- A new microcode every clock cycle.
      mcode_stb(i) <= '1';
      mcode        <= tv1(10 downto 0);

      -- always indirect branch when executing next bytecode
      mcode_branch(i*3+2) <= bcode_stb(i);
      mcode_branch(i*3+1) <= '0';
      mcode_branch(i*3  ) <= bcode_stb(i);
    end generate bcode_gen;

    -- memman-core-data-port trace
    mmcdp_gen : for i in 0 to CORE_CNT-1 generate
    begin
      mmcdp_ref((i+1)*REF_BITS-1 downto i*REF_BITS)    <= tv1(REF_BITS+16-1 downto 16);
      mmcdp_offs((i+1)*OFFS_BITS-1 downto i*OFFS_BITS) <= tv1(OFFS_BITS+8-1 downto 8);
      mmcdp_data((i+1)*32-1 downto i*32)               <= tv1(32 downto 1);
      mmcdp_ref_stb(i)                                 <= '1' when tv1(8) = '0' and tv1(7) = '0' and tv1(6) = '1'
                                                             and tv1(5 downto 0) = (5 downto 0 => '1') else '0';
      mmcdp_offs_stb(i)                                <= '1' when tv1(7) = '1' and tv1(6) = '0'
                                                             and tv1(5 downto 0) = (5 downto 0 => '1') else '0';
      mmcdp_data_stb(i)                                <= '1' when tv1(8) = '1' and tv1(6) = '0'
                                                             and tv1(5 downto 0) = (5 downto 0 => '1') else '0';
      mmcdp_rw(i)                                      <= tv1(0);
      mmcdp_rw_stb(i)                                  <= mmcdp_offs_stb(i);
    end generate mmcdp_gen;

    -- wishbone-trace
    wb_adr        <= tv1(31 downto 0);
    wb_data       <= tv1(31 downto 0);
    wb_adr_stb    <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(6);
    wb_data_stb   <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(7);
    wb_source     <= tv1(log2ceilnz(CORE_CNT)+8-1 downto 8);
    wb_source_stb <= wb_adr_stb;
    wb_rw         <= tv1(9);
    wb_rw_stb     <= wb_adr_stb or wb_data_stb;

    -- thread-trace
    th_gen : for i in 0 to CORE_CNT-1 generate
    begin
      th((i+1)*REF_BITS-1 downto i*REF_BITS) <= tv1(REF_BITS-1 downto 0);
      th_stb(i)                              <= '1' when tv1(9 downto 0) = (9 downto 0 => '1') and tv1(10+i) = '1' and tv1(13) = '1' and tv1(14) = '1' else '0';
    end generate th_gen;

    -- mmu-trace
    mmu     <= tv1(31 downto 0);
    mmu_stb <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4);

    -- mc-trace
    mc_gen : for i in 0 to CORE_CNT-1 generate
    begin
      mc((i+1)*32-1 downto i*32) <= tv1(31 downto 0);
      mc_stb(i)                  <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(6+i);
    end generate mc_gen;

    -- method-trace
    m_gen : for i in 0 to CORE_CNT-1 generate
    begin
      m((i+1)*32-1 downto i*32) <= tv1(31 downto 0);
      m_stb(i)                  <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(6) and tv1(12)and tv1(13);

    end generate m_gen;

    -- gc-ref-trace
    gc_ref     <= tv1(REF_BITS-1 downto 0);
    gc_ref_stb <= tv1(10) and tv1(11) and tv1(20) and tv1(21) and tv1(22);

    -- mm_mov-trace
    mm_mov_1     <= tv1(REF_BITS-1 downto 0);
    mm_mov_2     <= tv1(BASE_BITS-1 downto 0);
    mm_mov_3     <= tv1(1 downto 0);
    mm_mov_1_stb <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(7) and tv1(8) and tv1(9);
    mm_mov_2_stb <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(7) and tv1(8) and tv1(9);
    mm_mov_3_stb <= tv1(0) and tv1(1) and tv1(2) and tv1(3) and tv1(4) and tv1(5) and tv1(7) and tv1(8) and tv1(9);

    ---------------------------------------------------------------------------
    -- assign values to tracer-inputs
    ---------------------------------------------------------------------------

    b1: block
      constant VI  : natural := getPortValueIndex(INST_PORTS, BYTECODE_PORT.ID);
      constant SI  : natural := getPortStbIndex  (INST_PORTS, BYTECODE_PORT.ID);
      constant VIB : natural := getPortValueIndex(INST_BRANCH_PORTS, BYTECODE_BRANCH_PORT.ID);
    begin
      inst_values       (VI +CORE_CNT*32-1 downto VI ) <= bcode;
      inst_stbs         (SI +CORE_CNT   -1 downto SI ) <= bcode_stb;
      inst_branch_values(VIB+CORE_CNT*3 -1 downto VIB) <= bcode_branch;
    end block b1;

    b2: block
      constant VI  : natural := getPortValueIndex(INST_PORTS, MICROCODE_PORT.ID);
      constant SI  : natural := getPortStbIndex  (INST_PORTS, MICROCODE_PORT.ID);
      constant VIB : natural := getPortValueIndex(INST_BRANCH_PORTS, MICROCODE_BRANCH_PORT.ID);
    begin
      inst_values       (VI +CORE_CNT*11-1 downto VI ) <= mcode;
      inst_stbs         (SI +CORE_CNT   -1 downto SI ) <= mcode_stb;
      inst_branch_values(VIB+CORE_CNT*3 -1 downto VIB) <= mcode_branch;
    end block b2;

    b3 : block
      constant VI : natural := getPortValueIndex(MEM_ADR_PORTS, MMCDP_ADR_1_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_ADR_PORTS, MMCDP_ADR_1_PORT.ID);
    begin
      mem_adr_stbs  (SI+CORE_CNT         -1 downto SI) <= mmcdp_ref_stb;
      mem_adr_values(VI+CORE_CNT*REF_BITS-1 downto VI) <= mmcdp_ref;
    end block b3;

    b4 : block
      constant VI : natural := getPortValueIndex(MEM_ADR_PORTS, MMCDP_ADR_2_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_ADR_PORTS, MMCDP_ADR_2_PORT.ID);
    begin
      mem_adr_stbs  (SI+CORE_CNT          -1 downto SI) <= mmcdp_offs_stb;
      mem_adr_values(VI+CORE_CNT*OFFS_BITS-1 downto VI) <= mmcdp_offs;
    end block b4;

    b5 : block
      constant VI : natural := getPortValueIndex(MEM_DATA_PORTS, MMCDP_DATA_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_DATA_PORTS, MMCDP_DATA_PORT.ID);
    begin
      mem_data_stbs  (SI+CORE_CNT   -1 downto SI) <= mmcdp_data_stb;
      mem_data_values(VI+CORE_CNT*32-1 downto VI) <= mmcdp_data;
    end block b5;

    b6 : block
      constant VI : natural := getPortValueIndex(MEM_RW_PORTS, MMCDP_RW_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_RW_PORTS, MMCDP_RW_PORT.ID);
    begin
      mem_rw_stbs  (SI+CORE_CNT-1 downto SI) <= mmcdp_rw_stb;
      mem_rw_values(VI+CORE_CNT-1 downto VI) <= mmcdp_rw;
    end block b6;

    b7 : block
      constant VI : natural := getPortValueIndex(MEM_ADR_PORTS, WISHBONE_ADR_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_ADR_PORTS, WISHBONE_ADR_PORT.ID);
    begin
      mem_adr_stbs  (SI)                <= wb_adr_stb;
      mem_adr_values(VI+32-1 downto VI) <= wb_adr;
    end block b7;

    b8 : block
      constant VI : natural := getPortValueIndex(MEM_DATA_PORTS, WISHBONE_DATA_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_DATA_PORTS, WISHBONE_DATA_PORT.ID);
    begin
      mem_data_stbs (SI)                 <= wb_data_stb;
      mem_data_values(VI+32-1 downto VI) <= wb_data;
    end block b8;

    b9 : block
      constant VI : natural := getPortValueIndex(MEM_RW_PORTS, WISHBONE_RW_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_RW_PORTS, WISHBONE_RW_PORT.ID);
    begin
      mem_rw_stbs  (SI) <= wb_rw_stb;
      mem_rw_values(VI) <= wb_rw;
    end block b9;

    b10 : block
      constant VI : natural := getPortValueIndex(MEM_SOURCE_PORTS, WISHBONE_SOURCE_PORT.ID);
      constant SI : natural := getPortStbIndex  (MEM_SOURCE_PORTS, WISHBONE_SOURCE_PORT.ID);
    begin
      mem_source_stbs  (SI)                                  <= wb_source_stb;
      mem_source_values(VI+log2ceilnz(CORE_CNT)-1 downto VI) <= wb_source;
    end block b10;

    b11 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, THREAD_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, THREAD_PORT.ID);
    begin
      message_stbs  (SI+CORE_CNT-1          downto SI) <= th_stb;
      message_values(VI+CORE_CNT*REF_BITS-1 downto VI) <= th;
    end block b11;

    b12 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, MMU_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, MMU_PORT.ID);
    begin
      message_stbs  (SI)                <= mmu_stb;
      message_values(VI+32-1 downto VI) <= mmu;
    end block b12;

    b13 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, MC_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, MC_PORT.ID);
    begin
      message_stbs  (SI+CORE_CNT-1    downto SI) <= mc_stb;
      message_values(VI+CORE_CNT*32-1 downto VI) <= mc;
    end block b13;

    b14 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, METHOD_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, METHOD_PORT.ID);
    begin
      message_stbs  (SI+CORE_CNT-1    downto SI) <= m_stb;
      message_values(VI+CORE_CNT*32-1 downto VI) <= m;
    end block b14;

    b15 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, GC_REF_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, GC_REF_PORT.ID);
    begin
      message_stbs  (SI)                      <= gc_ref_stb;
      message_values(VI+REF_BITS-1 downto VI) <= gc_ref;
    end block b15;

    b16 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, MM_MOV_REF_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, MM_MOV_REF_PORT.ID);
    begin
      message_stbs  (SI)                      <= mm_mov_1_stb;
      message_values(VI+REF_BITS-1 downto VI) <= mm_mov_1;
    end block b16;

    b17 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, MM_MOV_BASE_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, MM_MOV_BASE_PORT.ID);
    begin
      message_stbs  (SI)                       <= mm_mov_2_stb;
      message_values(VI+BASE_BITS-1 downto VI) <= mm_mov_2;
    end block b17;

    b18 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, MM_MOV_CMD_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, MM_MOV_CMD_PORT.ID);
    begin
      message_stbs  (SI)               <= mm_mov_3_stb;
      message_values(VI+2-1 downto VI) <= mm_mov_3;
    end block b18;

    b19 : block
      constant VI : natural := getPortValueIndex(MESSAGE_PORTS, ENABLE_PORT.ID);
      constant SI : natural := getPortStbIndex  (MESSAGE_PORTS, ENABLE_PORT.ID);
    begin
      message_stbs  (SI) <= '1';
      message_values(VI) <= '1';
    end block b19;

    -- statistics, bytecode length
    statistic_incs(CORE_CNT-1 downto 0) <= (others => '1');
    statistic_rsts(CORE_CNT-1 downto 0) <= bcode_stb;

    -- statistics, method-cache metric
    statistic_incs(CORE_CNT*2-1 downto CORE_CNT) <= mc_stb;
    statistic_rsts(CORE_CNT*2-1 downto CORE_CNT) <= (others => '0');

  end block inputs_blk;

  --------------
  -- Ethernet --
  --------------

  trace_eth_inst : trace_eth
    generic map(
      BOARD_MAC        => x"0240f20cea90",
      HOST_MAC         => x"e840f20cea90"
    )
    port map(
      clk_eth       => clk_sys,
      rst_eth       => rst_sys,
      tr_finish     => trc_eth_finish,
      tr_data       => tr_data,
      tr_sof_n      => tr_sof_n,
      tr_eof_n      => tr_eof_n,
      tr_vld_n      => tr_vld_n,
      tr_rdy_N      => tr_rdy_n,
      re_data       => re_data,
      re_sof_n      => re_sof_n,
      re_eof_n      => re_eof_n,
      re_vld_n      => re_vld_n,
      re_rdy_n      => re_rdy_n,
      tr_fifo_got   => trc_got,
      tr_fifo_valid => trc_valid,
      tr_fifo_last  => trc_last,
      tr_fifo_din   => trc_dout,
      tr_header     => trc_header,
      re_fifo_put   => trc_put,
      re_fifo_full  => trc_full,
      re_fifo_dout  => trc_din
   );

  ethclockgen : eth_clockgen_ml505
    port map (
      CLK_FPGA_P       => CLK_FPGA_P,
      CLK_FPGA_N       => CLK_FPGA_N,
      PHY_RXCLK        => PHY_RXCLK,
      FPGA_CPU_RESET_B => rst_in_n,
      clk_eth          => clk_sys,
      clk_gmii_tx      => clk_gmii_tx,
      clk_gmii_rx      => clk_gmii_rx,
      clk_delayctrl    => clk_delayctrl,
      async_rst        => async_rst,
      rst_eth          => rst_sys,
      rst_delayctrl    => rst_delayctrl,
      locked           => open);
   PHY_RESET <= not async_rst;

  -- Instantiate IDELAYCTRL for the IDELAY in Fixed Tap Delay Mode
  -- Two controller are required:
  -- one for PHY_RXCLK (gmii_rxc0_delay)
  -- one for PHY_RXD   (see gmii_if module)
  dlyctrl0 : IDELAYCTRL port map (
    RDY    => open,
    REFCLK => clk_delayctrl,
    RST    => rst_delayctrl);
  dlyctrl1 : IDELAYCTRL port map (
    RDY    => open,
    REFCLK => clk_delayctrl,
    RST    => rst_delayctrl);

  ------------------------------------------------------------------------
  -- Instantiate the EMAC Wrapper with LL FIFO
  -- (ethmac_locallink.v)
  ------------------------------------------------------------------------
  v5_emac_ll : v5temac_gmii_locallink
    port map (
      -- EMAC0 Clocking
      -- TX Clock output from EMAC
      TX_CLK_OUT                      => open,
      -- EMAC0 TX Clock input from BUFG
      TX_CLK_0                        => clk_gmii_tx,
      -- Local link Receiver Interface - EMAC0
      RX_LL_CLOCK_0                   => clk_sys,
      RX_LL_RESET_0                   => rst_sys,
      RX_LL_DATA_0                    => re_data,
      RX_LL_SOF_N_0                   => re_sof_n,
      RX_LL_EOF_N_0                   => re_eof_n,
      RX_LL_SRC_RDY_N_0               => re_vld_n,
      RX_LL_DST_RDY_N_0               => re_rdy_n,
      RX_LL_FIFO_STATUS_0             => open,

      -- Unused Receiver signals - EMAC0
      EMAC0CLIENTRXDVLD               => open,
      EMAC0CLIENTRXFRAMEDROP          => open,
      EMAC0CLIENTRXSTATS              => open,
      EMAC0CLIENTRXSTATSVLD           => open,
      EMAC0CLIENTRXSTATSBYTEVLD       => open,

      -- Local link Transmitter Interface - EMAC0
      TX_LL_CLOCK_0                   => clk_sys,
      TX_LL_RESET_0                   => rst_sys,
      TX_LL_DATA_0                    => tr_data,
      TX_LL_SOF_N_0                   => tr_sof_n,
      TX_LL_EOF_N_0                   => tr_eof_n,
      TX_LL_SRC_RDY_N_0               => tr_vld_n,
      TX_LL_DST_RDY_N_0               => tr_rdy_n,

      -- Unused Transmitter signals - EMAC0
      CLIENTEMAC0TXIFGDELAY           => (others => '0'),
      EMAC0CLIENTTXSTATS              => open,
      EMAC0CLIENTTXSTATSVLD           => open,
      EMAC0CLIENTTXSTATSBYTEVLD       => open,

      -- MAC Control Interface - EMAC0
      CLIENTEMAC0PAUSEREQ             => '0',
      CLIENTEMAC0PAUSEVAL             => (others => '0'),

      -- Clock Signals - EMAC0
      GTX_CLK_0                       => '0',
      -- GMII Interface - EMAC0
      GMII_TXD_0                      => PHY_TXD,
      GMII_TX_EN_0                    => PHY_TXCTL_TXEN,
      GMII_TX_ER_0                    => PHY_TXER,
      GMII_TX_CLK_0                   => PHY_TXC_GTXCLK,
      GMII_RXD_0                      => PHY_RXD,
      GMII_RX_DV_0                    => PHY_RXCTL_RXDV,
      GMII_RX_ER_0                    => PHY_RXER,
      GMII_RX_CLK_0                   => clk_gmii_rx,

      -- Asynchronous Reset
      RESET                           => async_rst
    );

  ---------------------------------------------------------------------------
  -- MDIO
  ---------------------------------------------------------------------------
  PHY_MDIO <= 'Z';
  PHY_MDC  <= '0';

end Behavioral;
