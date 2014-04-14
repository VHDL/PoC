--
-- Entity: v5temac_client_rx_client_fifo_8
-- Author(s): File created by Coregen from Xilinx (see below).
--
-- Added rd_valid_pipe to process sensitivity list
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-07-17 16:54:47 $
--

-------------------------------------------------------------------------------
-- Title      : 8-bit Client to Local-link Receiver FIFO
-- Project    : Virtex-5 Ethernet MAC Wrappers
-------------------------------------------------------------------------------
-- File       : rx_client_fifo_8.vhd
-- Author     : Xilinx
-------------------------------------------------------------------------------
-- Copyright (c) 2004-2008 by Xilinx, Inc. All rights reserved.
-- This text/file contains proprietary, confidential
-- information of Xilinx, Inc., is distributed under license
-- from Xilinx, Inc., and may be used, copied and/or
-- disclosed only pursuant to the terms of a valid license
-- agreement with Xilinx, Inc. Xilinx hereby grants you
-- a license to use this text/file solely for design, simulation,
-- implementation and creation of design files limited
-- to Xilinx devices or technologies. Use with non-Xilinx
-- devices or technologies is expressly prohibited and
-- immediately terminates your license unless covered by
-- a separate agreement.
--
-- Xilinx is providing this design, code, or information
-- "as is" solely for use in developing programs and
-- solutions for Xilinx devices. By providing this design,
-- code, or information as one possible implementation of
-- this feature, application or standard, Xilinx is making no
-- representation that this implementation is free from any
-- claims of infringement. You are responsible for
-- obtaining any rights you may require for your implementation.
-- Xilinx expressly disclaims any warranty whatsoever with
-- respect to the adequacy of the implementation, including
-- but not limited to any warranties or representations that this
-- implementation is free from claims of infringement, implied
-- warranties of merchantability or fitness for a particular
-- purpose.
--
-- Xilinx products are not intended for use in life support
-- appliances, devices, or systems. Use in such applications are
-- expressly prohibited.
--
-- This copyright and support notice must be retained as part
-- of this text at all times. (c) Copyright 2004-2008 Xilinx, Inc.
-- All rights reserved.
-------------------------------------------------------------------------------
-- Description: This is the receiver side local link fifo for the design example
--              of the Virtex-5 Ethernet MAC Wrapper core.
--
--              The FIFO is created from 2 Block RAMs of size 2048
--              words of 8-bits per word, giving a total frame memory capacity
--              of 4096 bytes.
--
--              Frame data received from the MAC receiver is written into the
--              FIFO on the wr_clk.  An End Of Frame marker is written to the
--              BRAM parity bit on the last byte of data stored for a frame.
--              This acts as frame deliniation.
--
--              The rx_good_frame and rx_bad_frame signals are used to
--              qualify the frame.  A frame for which rx_bad_frame was
--              asserted will cause the FIFO write address pointer to be
--              reset to the base address of that frame.  In this way
--              the bad frame will be overwritten with the next received
--              frame and is therefore dropped from the FIFO.
--
--              Frames will also be dropped from the FIFO if an overflow occurs. 
--              If there is not enough memory capacity in the FIFO to store the 
--              whole of an incoming frame, the write address pointer will be
--              reset and the overflow signal asserted.
--
--              When there is at least one complete frame in the FIFO,
--              the 8 bit Local-link read interface will be enabled allowing
--              data to be read from the fifo.
--
--              The FIFO has been designed to operate with different clocks
--              on the write and read sides.  The read clock (locallink clock)
--              should always operate at an equal or faster frequency
--              than the write clock (client clock).
--
--              The FIFO is designed to work with a minimum frame length of 8 bytes.
--
--              The FIFO memory size can be increased by expanding the rd_addr
--              and wr_addr signal widths, to address further BRAMs.
--
--              Requirements :
--              * Minimum frame size of 8 bytes
--              * Spacing between good/bad frame flags is at least 64 clock cycles
--              * Wr clock is 125MHz downto 1.25MHz
--              * Rd clock is downto 20MHz
---------------------------------------------------------------------------------

library unisim;

use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity Eth_TEMAC_Virtex5_RX_FIFO is
  port (
        -- Local-link Interface
        rd_clk         : in  std_logic;
        rd_sreset      : in  std_logic;
        rd_data_out    : out std_logic_vector(7 downto 0);
        rd_sof_n       : out std_logic;
        rd_eof_n       : out std_logic;
        rd_src_rdy_n   : out std_logic;
        rd_dst_rdy_n   : in std_logic;

        -- Client Interface
        wr_sreset      : in  std_logic;
        wr_clk         : in  std_logic;
        wr_enable      : in  std_logic;
        rx_data        : in  std_logic_vector(7 downto 0);
        rx_data_valid  : in std_logic;
        rx_good_frame  : in std_logic;
        rx_bad_frame   : in std_logic;
        rx_fifo_status : out std_logic_vector(3 downto 0);
        overflow       : out std_logic
        );
end;


architecture RTL of Eth_TEMAC_Virtex5_RX_FIFO is

  signal GND                 : std_logic;
  signal VCC                 : std_logic;
  signal GND_BUS             : std_logic_vector(7 downto 0);

  -- Encode rd state machine  
  type rd_state_typ is (WAIT_s, QUEUE1_s, QUEUE2_s, QUEUE3_s, QUEUE_SOF_s, SOF_s, DATA_s, EOF_s);
  signal rd_state            : rd_state_typ;
  signal rd_nxt_state        : rd_state_typ;
 
  -- Encode wr state machine
  type wr_state_typ is (IDLE_s, FRAME_s, END_s, GF_s, BF_s, OVFLOW_s);
  signal wr_state            : wr_state_typ;
  signal wr_nxt_state        : wr_state_typ;
  
  type data_pipe is array (0 to 1) of std_logic_vector(7 downto 0);
  type cntl_pipe is array(0 to 1) of std_logic;
  
  signal wr_en               : std_logic;
  signal wr_en_u             : std_logic;
  signal wr_en_l             : std_logic;
  signal wr_addr             : unsigned(11 downto 0);
  signal wr_addr_inc         : std_logic;
  signal wr_start_addr_load  : std_logic;
  signal wr_addr_reload      : std_logic;
  signal wr_start_addr       : unsigned(11 downto 0);
  signal wr_data_bram        : std_logic_vector(7 downto 0);
  signal wr_data_pipe        : data_pipe;
  signal wr_eof_bram         : std_logic_vector(0 downto 0);
  signal wr_dv_pipe          : cntl_pipe;
  signal wr_gf_pipe          : cntl_pipe;
  signal wr_bf_pipe          : cntl_pipe;
  signal frame_in_fifo       : std_logic;

  signal rd_addr             : unsigned(11 downto 0);
  signal rd_addr_inc         : std_logic;
  signal rd_addr_reload      : std_logic;
  signal rd_data_bram_u      : std_logic_vector(7 downto 0);
  signal rd_data_bram_l      : std_logic_vector(7 downto 0);
  signal rd_data_pipe_u      : std_logic_vector(7 downto 0);
  signal rd_data_pipe_l      : std_logic_vector(7 downto 0);
  signal rd_data_pipe        : std_logic_vector(7 downto 0);
  signal rd_eof_bram_u       : std_logic_vector(0 downto 0);
  signal rd_eof_bram_l       : std_logic_vector(0 downto 0);
  signal rd_en               : std_logic;
  signal rd_bram_u           : std_logic;
  signal rd_bram_u_reg       : std_logic;
  signal rd_pull_frame       : std_logic;
  signal rd_eof              : std_logic;
  
  signal wr_store_frame_tog   : std_logic;
  signal rd_store_frame_tog   : std_logic;
  signal rd_store_frame_sync  : std_logic;
  signal rd_store_frame_delay : std_logic;
  signal rd_store_frame       : std_logic;
  signal rd_frames            : std_logic_vector(8 downto 0);        
  signal wr_fifo_full         : std_logic;

  signal rd_addr_gray         : unsigned(11 downto 0);
  signal wr_rd_addr_gray_sync : unsigned(11 downto 0);
  signal wr_rd_addr_gray      : unsigned(11 downto 0);
  signal wr_rd_addr           : unsigned(11 downto 0);
  signal wr_addr_diff         : unsigned(11 downto 0);

  signal wr_fifo_status       : unsigned(3 downto 0);

  signal rd_eof_n_int         : std_logic;

  signal rd_valid_pipe        : std_logic_vector(2 downto 0);

  -----------------------------------------------------------------------------
  -- Attributes for FIFO simulation and synthesis
  -----------------------------------------------------------------------------
  -- ASYNC_REG attributes added to simulate actual behaviour under
  -- asynchronous operating conditions.
  attribute ASYNC_REG                         : string;
  attribute ASYNC_REG of rd_store_frame_tog   : signal is "TRUE";
  attribute ASYNC_REG of wr_rd_addr_gray_sync : signal is "TRUE";

  -- WRITE_MODE attributes added to Block RAM to mitigate port contention
  attribute WRITE_MODE_A                    : string;
  attribute WRITE_MODE_B                    : string;
  attribute WRITE_MODE_A of ramgen_u        : label is "READ_FIRST";
  attribute WRITE_MODE_B of ramgen_u        : label is "READ_FIRST";
  attribute WRITE_MODE_A of ramgen_l        : label is "READ_FIRST";
  attribute WRITE_MODE_B of ramgen_l        : label is "READ_FIRST";

  -----------------------------------------------------------------------------
  -- Functions for gray code conversion
  -----------------------------------------------------------------------------   
   function gray_to_bin (
      gray : std_logic_vector)
      return std_logic_vector is
      variable binary : std_logic_vector(gray'range);
     
   begin
      for i in gray'high downto gray'low loop
         if i = gray'high then
            binary(i) := gray(i);
         else
            binary(i) := binary(i+1) xor gray(i);
         end if;
      end loop;  -- i
      return binary;
   end gray_to_bin;

   function bin_to_gray (
      bin : std_logic_vector)
      return std_logic_vector is
      variable gray : std_logic_vector(bin'range);
      
   begin
      for i in bin'range loop
         if i = bin'left then
            gray(i) := bin(i);
         else
            gray(i) := bin(i+1) xor bin(i);
         end if;
      end loop;  -- i
      return gray;
   end bin_to_gray;


-----------------------------------------------------------------------------
-- Begin FIFO architecture
-----------------------------------------------------------------------------
  
begin

  GND     <= '0';
  VCC     <= '1';
  GND_BUS <= (others => '0');


  -----------------------------------------------------------------------------
  -- Read State machines and control
  -----------------------------------------------------------------------------  
  -- local link state machine
  -- states are WAIT, QUEUE1, QUEUE2, QUEUE3, SOF, DATA, EOF
  -- clock state to next state
  clock_rds_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_state <= WAIT_s;
        else
           rd_state <= rd_nxt_state;
        end if;
     end if;
  end process clock_rds_p;

  rd_eof_n <= rd_eof_n_int;
      
  -- decode next state, combinatorial
  next_rds_p : process(rd_state, frame_in_fifo, rd_eof, rd_eof_n_int, rd_dst_rdy_n, rd_valid_pipe)
  begin
     case rd_state is
        when WAIT_s =>
           -- wait till there is a full frame in the fifo
           -- then start to load the pipeline
           if frame_in_fifo = '1' and rd_eof_n_int = '1' then
              rd_nxt_state <= QUEUE1_s;
           else
              rd_nxt_state <= WAIT_s;
           end if;
        when QUEUE1_s =>
           -- load the output pipeline
           -- this takes three clocks
           rd_nxt_state <= QUEUE2_s;
        when QUEUE2_s =>
           rd_nxt_state <= QUEUE3_s;
        when QUEUE3_s =>
           rd_nxt_state <= QUEUE_SOF_s;
        when QUEUE_SOF_s =>
           -- used to mark sof at end of queue
              rd_nxt_state <= DATA_s;  -- move straight to frame.
        when SOF_s =>
           -- used to mark sof when following straight from eof
           if rd_dst_rdy_n = '0' then
              rd_nxt_state <= DATA_s;
           else
              rd_nxt_state <= SOF_s;
           end if;
        when DATA_s =>
           -- When the eof marker is detected from the BRAM output
           -- move to EOF state
           if rd_dst_rdy_n = '0' and rd_eof = '1' then
              rd_nxt_state <= EOF_s;
           else
              rd_nxt_state <= DATA_s;
           end if;
        when EOF_s =>
           -- hold in this state until dst rdy is low
           -- and eof bit is accepted on interface
           -- If there is a frame in the fifo, then the next frame
           -- will already be queued into the pipe line so move straight
           -- to sof state.
           if rd_dst_rdy_n = '0' then
              if rd_valid_pipe(1) = '1' then
                 rd_nxt_state <= SOF_s;
              else
                 rd_nxt_state <= WAIT_s;
              end if;
           else
              rd_nxt_state <= EOF_s;
           end if;
        when others =>
           rd_nxt_state <= WAIT_s;
        end case;
  end process next_rds_p;

  -- detect if frame in fifo was high 3 reads ago
  -- this is used to ensure we only treat data in the pipeline as valid if
  -- frame in fifo goes high at or before the eof of the current frame
  -- It may be that there is valid data (i.e a partial packet has been written)
  -- but until the end of that packet we do not know if it is a good packet
  rd_valid_pipe_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
         if (rd_dst_rdy_n = '0') then
            rd_valid_pipe <= rd_valid_pipe(1) & 
                             rd_valid_pipe(0) & 
                             frame_in_fifo;
         end if;
     end if;
  end process rd_valid_pipe_p;
  
  -- decode the output signals depending on current state.
  -- decode sof signal.
  rd_ll_sof_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_sof_n <= '1';   
        else
           case rd_state is
              when QUEUE_SOF_s =>
                 -- no need to wait for dst rdy to be low, as there is valid data
                 rd_sof_n <= '0';
              when SOF_s =>
                 -- needed to wait till rd_dst_rdy is low to ensure eof signal has
                 -- been accepted onto the interface before asserting sof.
                 if rd_dst_rdy_n = '0' then
                    rd_sof_n <= '0';
                 end if;
              when others =>
                 -- needed to wait till rd_dst_rdy is low to ensure sof signal has
                 -- been accepted onto the interface.
                 if rd_dst_rdy_n = '0' then
                    rd_sof_n <= '1';
                 end if;
           end case;
        end if;
     end if;
  end process rd_ll_sof_p;

  -- decode eof signal
  -- check init value of this reg is 1.
  rd_ll_decode_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_eof_n_int <= '1';
        elsif rd_dst_rdy_n = '0' then
           -- needed to wait till rd_dst_rdy is low to ensure penultimate byte of frame has
           -- been accepted onto the interface before asserting eof and that
           -- eof is accepted before moving on
           case rd_state is
              when EOF_s =>
                 rd_eof_n_int <= '0';
              when others =>
                 rd_eof_n_int <= '1';
           end case;
        end if;
     end if;
  end process rd_ll_decode_p;
  
  -- decode data output
  rd_ll_data_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_en = '1' then
           rd_data_out <= rd_data_pipe;
        end if;
     end if;
  end process rd_ll_data_p;
  
  -- decode the output scr_rdy signal
  -- want to remove the dependancy of src_rdy from dst rdy
  -- check init value of this reg is '1'
  rd_ll_src_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_src_rdy_n <= '1';
        else
           case rd_state is
              when QUEUE_SOF_s =>
                 rd_src_rdy_n <= '0';
              when SOF_s =>
                 rd_src_rdy_n <= '0';
              when DATA_s =>
                 rd_src_rdy_n <= '0';
              when EOF_s =>
                 rd_src_rdy_n <= '0';
              when others =>
                 if rd_dst_rdy_n = '0' then
                    rd_src_rdy_n <= '1';
                 end if;
            end case;
         end if;
     end if;
  end process rd_ll_src_p;


  -- decode internal control signals
  -- rd_en is used to enable the BRAM read and load the output pipe  
  rd_en_p : process(rd_state, rd_dst_rdy_n)
  begin
     case rd_state is 
        when WAIT_s =>
           rd_en <= '0';
        when QUEUE1_s =>
           rd_en <= '1';
        when QUEUE2_s =>
           rd_en <= '1';
        when QUEUE3_s =>
           rd_en <= '1';
        when QUEUE_SOF_s =>
           rd_en <= '1';
        when others =>
           rd_en <= not rd_dst_rdy_n;
     end case;
  end process rd_en_p;

  -- rd_addr_inc is used to enable the BRAM read address to increment
  rd_addr_inc <= rd_en;


  -- When the current frame is output, if there is no frame in the fifo, then
  -- the fifo must wait until a new frame is written in.  This requires the read
  -- address to be moved back to where the new frame will be written.  The pipe
  -- is then reloaded using the QUEUE states
  rd_addr_reload <= '1' when rd_state = EOF_s and rd_nxt_state = WAIT_s else '0';
  
  -- frame in fifo signal is required on the rd side, need to convert wr
  -- address to rd clock domain.
  -- Data is available if there is at least one frame stored in the FIFO.
  p_rd_avail : process (rd_clk)
  begin 
    if rd_clk'event and rd_clk = '1' then 
      if rd_sreset = '1' then
        frame_in_fifo <= '0';
      else
        if rd_frames /= (rd_frames'range => '0') then
          frame_in_fifo <= '1';
        else
          frame_in_fifo <= '0';
        end if;
      end if;
    end if;
  end process p_rd_avail; 

  -- when a frame has been stored need to convert to rd clock domain for frame
  -- count store.
  p_sync_rd_store : process (rd_clk)
  begin 
    if rd_clk'event and rd_clk = '1' then 
      if rd_sreset = '1' then
        rd_store_frame_tog  <= '0';
        rd_store_frame_sync <= '0';
        rd_store_frame_delay <= '0';
        rd_store_frame      <= '0';
      else
        rd_store_frame_tog  <= wr_store_frame_tog;
        rd_store_frame_sync <= rd_store_frame_tog;
        rd_store_frame_delay <= rd_store_frame_sync;
        -- edge detector
        if (rd_store_frame_delay xor rd_store_frame_sync) = '1' then
          rd_store_frame    <= '1';
        else
          rd_store_frame    <= '0';
        end if;
      end if;
    end if;
  end process p_sync_rd_store;

  rd_pull_frame <= '1' when rd_state = SOF_s and rd_nxt_state /= SOF_s else
                   '1' when rd_state = QUEUE_SOF_s and rd_nxt_state /= QUEUE_SOF_s else
                   '0';
  
  -- Up/Down counter to monitor the number of frames stored within the
  -- the FIFO. Note:  
  --    * decrements at the beginning of a frame read cycle
  --    * increments at the end of a frame write cycle
  p_rd_frames : process (rd_clk)
  begin 
    if rd_clk'event and rd_clk = '1' then 
      if rd_sreset = '1' then
        rd_frames <= (others => '0');
      else
        -- A frame is written to the fifo in this cycle, and no frame is being
        -- read out on the same cycle
        if rd_store_frame = '1' and rd_pull_frame = '0' then
            rd_frames <= rd_frames + 1;
        -- A frame is being read out on this cycle and no frame is being
        -- written on the same cycle
        elsif rd_store_frame = '0' and rd_pull_frame = '1' then
             rd_frames <= rd_frames - 1;
        end if;
      end if;
    end if;
  end process p_rd_frames;


  -----------------------------------------------------------------------------
  -- Write State machines and control
  -----------------------------------------------------------------------------
  -- write state machine
  -- states are IDLE, FRAME, EOF, GF, BF, OVFLOW
  -- clock state to next state
  clock_wrs_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_sreset = '1' then
           wr_state <= IDLE_s;
        elsif wr_enable = '1' then
           wr_state <= wr_nxt_state;
        end if;
     end if;
  end process clock_wrs_p;
        
  -- decode next state, combinatorial
  next_wrs_p : process(wr_state, wr_dv_pipe(1), wr_gf_pipe(1), wr_bf_pipe(1), wr_eof_bram(0), wr_fifo_full)
  begin
  case wr_state is
           when IDLE_s =>
              -- there is data in the incoming pipeline when dv_pipe(1) goes high
              if wr_dv_pipe(1) = '1' then
                 wr_nxt_state <= FRAME_s;
              else
                 wr_nxt_state <= IDLE_s;
              end if;
           when FRAME_s =>
              -- if fifo is full then go to overflow state.
              -- if the good or bad flag is detected the end
              -- of the frame has been reached!
              -- this transistion occurs when the gb flag
              -- is on the clock edge immediately following
              -- the end of the frame.
              -- if the eof_bram signal is detected then data valid has
              -- fallen low and the end of frame has been detected.
              if wr_fifo_full = '1' then
                 wr_nxt_state <= OVFLOW_s;
              elsif wr_gf_pipe(1) = '1' then
                 wr_nxt_state <= GF_s;
              elsif wr_bf_pipe(1) = '1' then
                 wr_nxt_state <= BF_s;
              elsif wr_eof_bram(0) = '1' then
                 wr_nxt_state <= END_s;
              else
                 wr_nxt_state <= FRAME_s;
              end if;
           when END_s =>
              -- wait until the good or bad flag has been received.
              if wr_gf_pipe(1) = '1' then
                 wr_nxt_state <= GF_s;
              elsif wr_bf_pipe(1) = '1' then
                 wr_nxt_state <= BF_s;
              else
                 wr_nxt_state <= END_s;
              end if;
           when GF_s =>
              -- wait for next frame
              wr_nxt_state <= IDLE_s;
           when BF_s =>
              -- wait for next frame
              wr_nxt_state <= IDLE_s;
           when OVFLOW_s =>
              -- wait until the good or bad flag received.
              if wr_gf_pipe(1) = '1' or wr_bf_pipe(1) = '1' then
                 wr_nxt_state <= IDLE_s;
              else
                 wr_nxt_state <= OVFLOW_s;
              end if;
           when others =>
              wr_nxt_state <= IDLE_s;
        end case;
  end process next_wrs_p;

  
  -- decode control signals
  -- wr_en is used to enable the BRAM write and loading of the input pipeline
  wr_en <= '1' when wr_state = FRAME_s else '0';

  -- the upper and lower signals are used to distinguish between the upper and
  -- lower BRAM
  wr_en_l <= wr_en and not(wr_addr(11));
  wr_en_u <= wr_en and wr_addr(11);

  -- increment the write address when we are receiving a frame
  wr_addr_inc <= '1' when wr_state = FRAME_s else '0';

  -- if the fifo overflows or a frame is to be dropped, we need to move the
  -- write address back to the start of the frame.  This allows the data to be
  -- overwritten.
  wr_addr_reload <= '1' when wr_state = BF_s or wr_state = OVFLOW_s else '0';
  
  -- the start address is saved when in the WAIT state
  wr_start_addr_load <= '1' when wr_state = IDLE_s else '0';

  -- we need to know when a frame is stored, in order to increment the count of
  -- frames stored in the fifo.
  p_wr_store_tog : process (wr_clk)
  begin  -- process
     if wr_clk'event and wr_clk = '1' then
        if wr_sreset = '1' then
           wr_store_frame_tog <= '0';
        elsif wr_enable = '1' then
           if wr_state = GF_s then
              wr_store_frame_tog <= not wr_store_frame_tog;
           end if;
        end if;
     end if;
  end process;


  -----------------------------------------------------------------------------
  -- Address counters
  -----------------------------------------------------------------------------
  -- write address is incremented when write enable signal has been asserted
  wr_addr_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_sreset = '1' then
           wr_addr <= (others => '0');
        elsif wr_enable = '1' then
           if wr_addr_reload = '1' then
              wr_addr <= wr_start_addr;
           elsif wr_addr_inc = '1' then
              wr_addr <= wr_addr + 1;
           end if;
        end if;
     end if;
  end process wr_addr_p;

  -- store the start address
  wr_staddr_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_sreset = '1' then
           wr_start_addr <= (others => '0');
        elsif wr_enable = '1' then
           if wr_start_addr_load = '1' then
              wr_start_addr <= wr_addr;
           end if;
        end if;
     end if;
  end process wr_staddr_p;
  
  -- read address is incremented when read enable signal has been asserted
  rd_addr_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_addr <= (others => '0');
        else
           if rd_addr_reload = '1' then
              rd_addr <= rd_addr - 2;
           elsif rd_addr_inc = '1' then
              rd_addr <= rd_addr + 1;
           end if;
        end if;
     end if;
  end process rd_addr_p;

  -- which BRAM is read from is dependant on the upper bit of the address
  -- space.  this needs to be registered to give the correct timing.
  rd_bram_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_sreset = '1' then
           rd_bram_u <= '0';
           rd_bram_u_reg <= '0';
        elsif rd_addr_inc = '1' then
           rd_bram_u <= rd_addr(11);
           rd_bram_u_reg <= rd_bram_u;
        end if;
     end if;
  end process rd_bram_p;

  -----------------------------------------------------------------------------
  -- Data Pipelines
  -----------------------------------------------------------------------------
  -- register data inputs to bram
  -- no reset to allow srl16 target
  reg_din_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_enable = '1' then
           wr_data_pipe(0) <= rx_data;
           wr_data_pipe(1) <= wr_data_pipe(0);
           wr_data_bram    <= wr_data_pipe(1);
        end if;
     end if;
  end process reg_din_p;

 -- no reset to allow srl16 target
 reg_eof_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_enable = '1' then
           wr_dv_pipe(0) <= rx_data_valid;
           wr_dv_pipe(1) <= wr_dv_pipe(0);
           wr_eof_bram(0) <= wr_dv_pipe(1) and not wr_dv_pipe(0);
        end if;
     end if;
  end process reg_eof_p;

   -- no reset to allow srl16 target
  reg_gf_p : process(wr_clk)
  begin
     if (wr_clk'event and wr_clk = '1') then
        if wr_enable = '1' then      
           wr_gf_pipe(0) <= rx_good_frame;
           wr_gf_pipe(1) <= wr_gf_pipe(0);
           wr_bf_pipe(0) <= rx_bad_frame;
           wr_bf_pipe(1) <= wr_bf_pipe(0);
        end if;
     end if;
  end process reg_gf_p;

  -- register data outputs from bram
  -- no reset to allow srl16 target
  reg_dout_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_en = '1' then
           rd_data_pipe_u <= rd_data_bram_u;
           rd_data_pipe_l <= rd_data_bram_l;
           if rd_bram_u_reg = '1' then
              rd_data_pipe <= rd_data_pipe_u;
           else
              rd_data_pipe <= rd_data_pipe_l;
           end if;
        end if;
     end if;
  end process reg_dout_p;

  -- register data outputs from bram
  reg_eofout_p : process(rd_clk)
  begin
     if (rd_clk'event and rd_clk = '1') then
        if rd_en = '1' then
           if rd_bram_u = '1' then
              rd_eof <= rd_eof_bram_u(0);
           else
              rd_eof <= rd_eof_bram_l(0);
           end if;
        end if;
     end if;
  end process reg_eofout_p;

  -----------------------------------------------------------------------------
  -- Overflow functionality
  -----------------------------------------------------------------------------
  -- Take the Read Address Pointer and convert it into a gray code 
  p_reg_rd_addr_gray : process (rd_clk)
  begin
     if rd_clk'event and rd_clk = '1' then
        if rd_sreset = '1' then
           rd_addr_gray <= (others => '0');
        else
           rd_addr_gray <= unsigned(bin_to_gray(std_logic_vector(rd_addr)));
        end if;
     end if;
  end process p_reg_rd_addr_gray;  

  -- Resync the Read Address Pointer gray code onto the write clock
  -- NOTE: rd_addr_gray signal crosses clock domains
  p_sync_rd_addr : process (wr_clk)
  begin 
     if wr_clk'event and wr_clk = '1' then 
        if wr_sreset = '1' then
          wr_rd_addr_gray_sync <= (others => '0');
          wr_rd_addr_gray <= (others => '0');
        elsif wr_enable = '1' then
          wr_rd_addr_gray_sync <= rd_addr_gray;
          wr_rd_addr_gray <= wr_rd_addr_gray_sync;
        end if;
     end if;
  end process p_sync_rd_addr;

  -- Convert the resync'd Read Address Pointer grey code back to binary
  wr_rd_addr <= unsigned(gray_to_bin(std_logic_vector(wr_rd_addr_gray)));

  -- Obtain the difference between write and read pointers
  p_addr_diff : process (wr_clk)
  begin
     if wr_clk'event and wr_clk = '1' then
        if wr_sreset = '1' then
           wr_addr_diff <= (others => '0');
        elsif wr_enable = '1' then
           wr_addr_diff <= wr_rd_addr - wr_addr;
        end if;
     end if;
  end process p_addr_diff;

  -- Detect when the FIFO is full
  -- The FIFO is considered to be full if the write address
  -- pointer is within 4 to 15 of the read address pointer.
  p_wr_full : process (wr_clk)
  begin 
     if wr_clk'event and wr_clk = '1' then
       if wr_sreset = '1' then
         wr_fifo_full <= '0';
       elsif wr_enable = '1' then
         if wr_addr_diff(11 downto 4) = 0 and wr_addr_diff(3 downto 2) /= "00" then
           wr_fifo_full <= '1';
         else
            wr_fifo_full <= '0';
         end if;
       end if;
     end if;
  end process p_wr_full;

  overflow <= '1' when wr_state = OVFLOW_s else '0';
  
  ----------------------------------------------------------------------
  -- FIFO Status Signals
  ----------------------------------------------------------------------

  -- The FIFO status signal is four bits which represents the occupancy
  -- of the FIFO in 16'ths.  To generate this signal we therefore only
  -- need to compare the 4 most significant bits of the write address
  -- pointer with the 4 most significant bits of the read address 
  -- pointer.

  -- already have fifo status on write side through wr_addr_diff.
  -- calculate fifo status here and output on the wr clock domain.


  p_wr_fifo_status : process (wr_clk)
  begin 
     if wr_clk'event and wr_clk = '1' then
        if wr_sreset = '1' then
           wr_fifo_status <= "0000";
        elsif wr_enable = '1' then
           if wr_addr_diff = (wr_addr_diff'range => '0') then
              wr_fifo_status <= "0000";
           else
              wr_fifo_status(3) <= not wr_addr_diff(11);
              wr_fifo_status(2) <= not wr_addr_diff(10);
              wr_fifo_status(1) <= not wr_addr_diff(9);
              wr_fifo_status(0) <= not wr_addr_diff(8);
           end if;
        end if;
     end if;
  end process p_wr_fifo_status;
 
  rx_fifo_status <= std_logic_vector(wr_fifo_status);
 

  -----------------------------------------------------------------------------
  -- Memory
  -----------------------------------------------------------------------------
  -- Block Ram for lower address space (rx_addr(11) = '0')
  ramgen_l : RAMB16_S9_S9
    generic map (
      WRITE_MODE_A => "READ_FIRST",
      WRITE_MODE_B => "READ_FIRST")
    port map (
      WEA   => wr_en_l,
      ENA   => VCC,
      SSRA  => wr_sreset,
      CLKA  => wr_clk,
      ADDRA => std_logic_vector(wr_addr(10 downto 0)),
      DIA   => wr_data_bram,
      DIPA  => wr_eof_bram,
      WEB   => GND,
      ENB   => rd_en,
      SSRB  => rd_sreset,
      CLKB  => rd_clk,
      ADDRB => std_logic_vector(rd_addr(10 downto 0)),
      DIB   => GND_BUS(7 downto 0),
      DIPB  => GND_BUS(0 downto 0),
      DOA   => open,
      DOPA  => open,
      DOB   => rd_data_bram_l,
      DOPB  => rd_eof_bram_l);

  -- Block Ram for lower address space (rx_addr(11) = '0')
  ramgen_u : RAMB16_S9_S9
    generic map (
      WRITE_MODE_A => "READ_FIRST",
      WRITE_MODE_B => "READ_FIRST")
    port map (
      WEA   => wr_en_u,
      ENA   => VCC,
      SSRA  => wr_sreset,
      CLKA  => wr_clk,
      ADDRA => std_logic_vector(wr_addr(10 downto 0)),
      DIA   => wr_data_bram,
      DIPA  => wr_eof_bram,
      WEB   => GND,
      ENB   => rd_en,
      SSRB  => rd_sreset,
      CLKB  => rd_clk,
      ADDRB => std_logic_vector(rd_addr(10 downto 0)),
      DIB   => GND_BUS(7 downto 0),
      DIPB  => GND_BUS(0 downto 0),
      DOA   => open,
      DOPA  => open,
      DOB   => rd_data_bram_u,
      DOPB  => rd_eof_bram_u);


  
end RTL;
