
// Copyright (C) 1991-2012 Altera Corporation
// Your use of Altera Corporation's design tools, logic functions 
// and other software and tools, and its AMPP partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License 
// Subscription Agreement, Altera MegaCore Function License 
// Agreement, or other applicable license agreement, including, 
// without limitation, that your use is for the sole purpose of 
// programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the 
// applicable agreement for further details.

//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on

module  sata_basic
	( 
	inclk,
	reset,
	rx_datain,
	tx_datain,
	tx_ctrlin,
	tx_forceelecidle,
	reconf_clk,
	sata_gen,
	reconfig,
	locked,
	rx_dataout,
	rx_ctrlout,
	rx_errdetect,
	rx_disperr,
	rx_signaldetect,
	rx_clkout,
	tx_dataout,
	tx_clkout,
	busy);

input reset;
input inclk;
input rx_datain;
input [31:0] tx_datain;
input [3:0] tx_ctrlin;
input tx_forceelecidle;
input reconf_clk;
input [1:0] sata_gen;
input reconfig;
output locked;
output [31:0] rx_dataout;
output [3:0] rx_ctrlout;
output [3:0] rx_errdetect;
output [3:0] rx_disperr;
output rx_clkout;
output rx_signaldetect;
output tx_dataout;
output tx_clkout;
output busy;

reg rx_patternalign;
reg [1:0] sata_genreg;
reg [2:0] state;

parameter IDLE = 3'b001;
parameter CONF = 3'b010;
parameter WAIT = 3'b100;

wire digitalreset;
wire [15:0] reconf_data;
wire [3:0] reconf_togxb;
wire [16:0] reconf_fromgxb;
wire [5:0] reconf_address;
wire reconf_busy;

wire  cal_blk0_nonusertocmu;
wire  [1:0]   ch_clk_div0_analogfastrefclkout;
wire  [1:0]   ch_clk_div0_analogrefclkout;
wire  ch_clk_div0_analogrefclkpulse;
wire  [99:0]   ch_clk_div0_dprioout;
wire  ch_clk_div0_rateswitchdone;
wire  [599:0]   cent_unit0_cmudividerdprioout;
wire  [1799:0]   cent_unit0_cmuplldprioout;
wire  cent_unit0_dpriodisableout;
wire  cent_unit0_dprioout;
wire  [1:0]   cent_unit0_pllpowerdn;
wire  [1:0]   cent_unit0_pllresetout;
wire  cent_unit0_quadresetout;
wire  [5:0]   cent_unit0_rxanalogresetout;
wire  [5:0]   cent_unit0_rxcrupowerdown;
wire  [5:0]   cent_unit0_rxcruresetout;
wire  [3:0]   cent_unit0_rxdigitalresetout;
wire  [5:0]   cent_unit0_rxibpowerdown;
wire  [1599:0]   cent_unit0_rxpcsdprioout;
wire  [1799:0]   cent_unit0_rxpmadprioout;
wire  [5:0]   cent_unit0_txanalogresetout;
wire  [3:0]   cent_unit0_txctrlout;
wire  [31:0]   cent_unit0_txdataout;
wire  [5:0]   cent_unit0_txdetectrxpowerdown;
wire  [3:0]   cent_unit0_txdigitalresetout;
wire  [5:0]   cent_unit0_txobpowerdown;
wire  [599:0]   cent_unit0_txpcsdprioout;
wire  [1799:0]   cent_unit0_txpmadprioout;
wire  [3:0]   rx_cdr_pll0_clk;
wire  [1:0]   rx_cdr_pll0_dataout;
wire  [299:0]   rx_cdr_pll0_dprioout;
wire  rx_cdr_pll0_locked;
wire  rx_cdr_pll0_pfdrefclkout;
wire  [3:0]   tx_pll0_clk;
wire  [299:0]   tx_pll0_dprioout;
wire  receive_pcs0_autospdrateswitchout;
wire  receive_pcs0_cdrctrlearlyeios;
wire  receive_pcs0_cdrctrllocktorefclkout;
wire  [63:0]   receive_pcs0_dataoutfull;
wire  [399:0]   receive_pcs0_dprioout;
wire  receive_pcs0_pipestatetransdoneout;
wire  [19:0]   receive_pcs0_revparallelfdbkdata;
wire  [7:0]   receive_pma0_analogtestbus;
wire  receive_pma0_clockout;
wire  receive_pma0_dataout;
wire  [299:0]   receive_pma0_dprioout;
wire  receive_pma0_locktorefout;
wire  [63:0]   receive_pma0_recoverdataout;
wire  receive_pma0_reverselpbkout;
wire  [19:0]   transmit_pcs0_dataout;
wire  [149:0]  transmit_pcs0_dprioout;
wire  transmit_pcs0_forceelecidleout;
wire  [2:0]   transmit_pcs0_grayelecidleinferselout;
wire  transmit_pcs0_pipeenrevparallellpbkout;
wire  [1:0]   transmit_pcs0_pipepowerdownout;
wire  [3:0]   transmit_pcs0_pipepowerstateout;
wire  transmit_pcs0_txdetectrx;
wire  transmit_pma0_clockout;
wire  [299:0]   transmit_pma0_dprioout;
wire  transmit_pma0_rxdetectvalidout;
wire  transmit_pma0_rxfoundout;
wire  transmit_pma0_seriallpbkout;

assign busy = (state != IDLE);
assign digitalreset = reset | busy;

initial state <= IDLE;
always @ (posedge reconf_clk)
begin
	case (state)
		IDLE: if (reconfig) begin sata_genreg <= sata_gen; state <= CONF; end
		CONF: state <= WAIT;
		WAIT: if (~reconf_busy) state <= (reconf_address) ? CONF : IDLE;
	endcase
end

initial rx_patternalign <= 1'b0;
always @ (posedge rx_clkout)
	rx_patternalign <= ~rx_patternalign & (rx_errdetect != 4'b0000);

stratixiv_hssi_calibration_block cal_blk0 ( 
	.calibrationstatus(),
	.clk(reconf_clk),
	.enabletestbus(1'b1),
	.nonusertocmu(cal_blk0_nonusertocmu));

stratixiv_hssi_clock_divider ch_clk_div0 ( 
	.analogfastrefclkout(ch_clk_div0_analogfastrefclkout),
	.analogfastrefclkoutshifted(),
	.analogrefclkout(ch_clk_div0_analogrefclkout),
	.analogrefclkoutshifted(),
	.analogrefclkpulse(ch_clk_div0_analogrefclkpulse),
	.analogrefclkpulseshifted(),
	.clk0in(tx_pll0_clk),
	.coreclkout(),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_cmudividerdprioout[99:0]),
	.dprioout(ch_clk_div0_dprioout),
	.quadreset(cent_unit0_quadresetout),
	.rateswitch(receive_pcs0_autospdrateswitchout),
	.rateswitchbaseclock(),
	.rateswitchdone(ch_clk_div0_rateswitchdone),
	.rateswitchout(),
	.refclkout(),
	.clk1in(4'b0000),
	.powerdn(1'b0),
	.rateswitchbaseclkin(2'b00),
	.rateswitchdonein(2'b00),
	.refclkdig(1'b0),
	.refclkin(2'b00),
	.vcobypassin(1'b0));
defparam
	ch_clk_div0.channel_num = 0,
	ch_clk_div0.divide_by = 5,
	ch_clk_div0.divider_type = "CHANNEL_REGULAR",
	ch_clk_div0.dprio_config_mode = 8'h1A,
	ch_clk_div0.effective_data_rate = "6000 Mbps",
	ch_clk_div0.enable_dynamic_divider = "false",
	ch_clk_div0.enable_refclk_out = "false",
	ch_clk_div0.inclk_select = 0,
	ch_clk_div0.logical_channel_address = 0,
	ch_clk_div0.pre_divide_by = 1,
	ch_clk_div0.select_local_rate_switch_done = "false",
	ch_clk_div0.sim_analogfastrefclkout_phase_shift = 0,
	ch_clk_div0.sim_analogrefclkout_phase_shift = 0,
	ch_clk_div0.sim_coreclkout_phase_shift = 0,
	ch_clk_div0.sim_refclkout_phase_shift = 0,
	ch_clk_div0.use_coreclk_out_post_divider = "false",
	ch_clk_div0.use_refclk_post_divider = "false",
	ch_clk_div0.use_vco_bypass = "false",
	ch_clk_div0.lpm_type = "stratixiv_hssi_clock_divider";

stratixiv_hssi_cmu cent_unit0 (
	.adet({4{1'b0}}),
	.alignstatus(),
	.autospdx4configsel(),
	.autospdx4rateswitchout(),
	.autospdx4spdchg(),
	.clkdivpowerdn(),
	.cmudividerdprioin({{500{1'b0}}, ch_clk_div0_dprioout}),
	.cmudividerdprioout(cent_unit0_cmudividerdprioout),
	.cmuplldprioin({{300{1'b0}}, tx_pll0_dprioout, {900{1'b0}}, rx_cdr_pll0_dprioout}),
	.cmuplldprioout(cent_unit0_cmuplldprioout),
	.digitaltestout(),
	.dpclk(reconf_clk),
	.dpriodisable(reconf_togxb[1]),
	.dpriodisableout(cent_unit0_dpriodisableout),
	.dprioin(reconf_togxb[0]),
	.dprioload(reconf_togxb[2]),
	.dpriooe(),
	.dprioout(cent_unit0_dprioout),
	.enabledeskew(),
	.extra10gout(),
	.fiforesetrd(),
	.fixedclk({5'b00000, reconf_clk}),
	.lccmutestbus(),
	.nonuserfromcal(cal_blk0_nonusertocmu),
	.phfifiox4ptrsreset(),
	.pllpowerdn(cent_unit0_pllpowerdn),
	.pllresetout(cent_unit0_pllresetout),
	.quadreset(1'b0),
	.quadresetout(cent_unit0_quadresetout),
	.rdalign({4{1'b0}}),
	.rdenablesync(1'b0),
	.recovclk(1'b0),
	.refclkdividerdprioin({2{1'b0}}),
	.refclkdividerdprioout(),
	.rxadcepowerdown(),
	.rxadceresetout(),
	.rxanalogreset(6'b000000),
	.rxanalogresetout(cent_unit0_rxanalogresetout),
	.rxcrupowerdown(cent_unit0_rxcrupowerdown),
	.rxcruresetout(cent_unit0_rxcruresetout),
	.rxctrl({4{1'b0}}),
	.rxctrlout(),
	.rxdatain({32{1'b0}}),
	.rxdataout(),
	.rxdatavalid({4{1'b0}}),
	.rxdigitalreset({3'b000, digitalreset}),
	.rxdigitalresetout(cent_unit0_rxdigitalresetout),
	.rxibpowerdown(cent_unit0_rxibpowerdown),
	.rxpcsdprioin({{1200{1'b0}}, receive_pcs0_dprioout}),
	.rxpcsdprioout(cent_unit0_rxpcsdprioout),
	.rxphfifox4byteselout(),
	.rxphfifox4rdenableout(),
	.rxphfifox4wrclkout(),
	.rxphfifox4wrenableout(),
	.rxpmadprioin({{1500{1'b0}}, receive_pma0_dprioout}),
	.rxpmadprioout(cent_unit0_rxpmadprioout),
	.rxpowerdown(6'b000000),
	.rxrunningdisp({4{1'b0}}),
	.scanout(),
	.syncstatus({4{1'b0}}),
	.testout(),
	.txanalogresetout(cent_unit0_txanalogresetout),
	.txctrl({4{1'b0}}),
	.txctrlout(cent_unit0_txctrlout),
	.txdatain({32{1'b0}}),
	.txdataout(cent_unit0_txdataout),
	.txdetectrxpowerdown(cent_unit0_txdetectrxpowerdown),
	.txdigitalreset({3'b000, digitalreset}),
	.txdigitalresetout(cent_unit0_txdigitalresetout),
	.txdividerpowerdown(),
	.txobpowerdown(cent_unit0_txobpowerdown),
	.txpcsdprioin({{450{1'b0}}, transmit_pcs0_dprioout}),
	.txpcsdprioout(cent_unit0_txpcsdprioout),
	.txphfifox4byteselout(),
	.txphfifox4rdclkout(),
	.txphfifox4rdenableout(),
	.txphfifox4wrenableout(),
	.txpllreset(2'b00),
	.txpmadprioin({{1500{1'b0}}, transmit_pma0_dprioout}),
	.txpmadprioout(cent_unit0_txpmadprioout));
defparam
	cent_unit0.auto_spd_deassert_ph_fifo_rst_count = 8,
	cent_unit0.auto_spd_phystatus_notify_count = 14,
	cent_unit0.bonded_quad_mode = "none",
	cent_unit0.devaddr = 1,
	cent_unit0.in_xaui_mode = "false",
	cent_unit0.offset_all_errors_align = "false",
	cent_unit0.pipe_auto_speed_nego_enable = "false",
	cent_unit0.pipe_freq_scale_mode = "Frequency",
	cent_unit0.pma_done_count = 249950,
	cent_unit0.portaddr = 1,
	cent_unit0.rx0_auto_spd_self_switch_enable = "false",
	cent_unit0.rx0_channel_bonding = "none",
	cent_unit0.tx0_auto_spd_self_switch_enable = "false",
	cent_unit0.tx0_channel_bonding = "none",
	cent_unit0.use_deskew_fifo = "false",
	cent_unit0.vcceh_voltage = "Auto",
	cent_unit0.lpm_type = "stratixiv_hssi_cmu";

stratixiv_hssi_pll rx_cdr_pll0 (
	.areset(cent_unit0_rxcruresetout[0]),
	.clk(rx_cdr_pll0_clk),
	.datain(receive_pma0_dataout),
	.dataout(rx_cdr_pll0_dataout),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_cmuplldprioout[299:0]),
	.dprioout(rx_cdr_pll0_dprioout),
	.freqlocked(),
	.inclk({9'b000000000, inclk}),
	.locked(rx_cdr_pll0_locked),
	.locktorefclk(receive_pma0_locktorefout),
	.pfdfbclkout(),
	.pfdrefclkout(rx_cdr_pll0_pfdrefclkout),
	.powerdown(cent_unit0_rxcrupowerdown[0]),
	.rateswitch(receive_pcs0_autospdrateswitchout),
	.vcobypassout());
defparam
	rx_cdr_pll0.bandwidth_type = "Auto",
	rx_cdr_pll0.channel_num = 0,
	rx_cdr_pll0.dprio_config_mode = 8'h10,
	rx_cdr_pll0.effective_data_rate = "6000 Mbps",
	rx_cdr_pll0.enable_dynamic_divider = "false",
	rx_cdr_pll0.fast_lock_control = "false",
	rx_cdr_pll0.inclk0_input_period = 6667,
	rx_cdr_pll0.input_clock_frequency = "150.0 MHz",
	rx_cdr_pll0.m = 20,
	rx_cdr_pll0.n = 1,
	rx_cdr_pll0.pfd_clk_select = 0,
	rx_cdr_pll0.pll_type = "RX CDR",
	rx_cdr_pll0.use_refclk_pin = "false",
	rx_cdr_pll0.vco_post_scale = 1,
	rx_cdr_pll0.lpm_type = "stratixiv_hssi_pll";

stratixiv_hssi_pll tx_pll0 ( 
	.areset(cent_unit0_pllresetout[0]),
	.clk(tx_pll0_clk),
	.dataout(),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_cmuplldprioout[1499:1200]),
	.dprioout(tx_pll0_dprioout),
	.freqlocked(),
	.inclk({9'b000000000, inclk}),
	.locked(locked),
	.pfdfbclkout(),
	.pfdrefclkout(),
	.powerdown(cent_unit0_pllpowerdn[0]),
	.vcobypassout());
defparam
	tx_pll0.bandwidth_type = "Auto",
	tx_pll0.channel_num = 4,
	tx_pll0.dprio_config_mode = 8'h10,
	tx_pll0.inclk0_input_period = 6667,
	tx_pll0.input_clock_frequency = "150.0 MHz",
	tx_pll0.logical_tx_pll_number = 0,
	tx_pll0.m = 20,
	tx_pll0.n = 1,
	tx_pll0.pfd_clk_select = 0,
	tx_pll0.pfd_fb_select = "internal",
	tx_pll0.pll_type = "CMU",
	tx_pll0.use_refclk_pin = "false",
	tx_pll0.vco_post_scale = 1,
	tx_pll0.lpm_type = "stratixiv_hssi_pll";

stratixiv_hssi_rx_pcs receive_pcs0 ( 
	.a1a2size(1'b0),
	.a1a2sizeout(),
	.a1detect(),
	.a2detect(),
	.adetectdeskew(),
	.alignstatus(1'b0),
	.alignstatussync(1'b0),
	.alignstatussyncout(),
	.autospdrateswitchout(receive_pcs0_autospdrateswitchout),
	.autospdspdchgout(),
	.bistdone(),
	.bisterr(),
	.bitslipboundaryselectout(),
	.byteorderalignstatus(),
	.cdrctrlearlyeios(receive_pcs0_cdrctrlearlyeios),
	.cdrctrllocktorefcl(reconf_togxb[3]),
	.cdrctrllocktorefclkout(receive_pcs0_cdrctrllocktorefclkout),
	.clkout(rx_clkout),
	.coreclk(rx_clkout),
	.coreclkout(),
	.ctrldetect(),
	.datain(receive_pma0_recoverdataout[19:0]),
	.dataout(),
	.dataoutfull(receive_pcs0_dataoutfull),
	.digitalreset(cent_unit0_rxdigitalresetout[0]),
	.digitaltestout(),
	.disablefifordin(1'b0),
	.disablefifordout(),
	.disablefifowrin(1'b0),
	.disablefifowrout(),
	.disperr(),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_rxpcsdprioout[399:0]),
	.dprioout(receive_pcs0_dprioout),
	.elecidleinfersel({3{1'b0}}),
	.enabledeskew(1'b0),
	.enabyteord(1'b0),
	.enapatternalign(rx_patternalign),
	.errdetect(),
	.fifordin(1'b0),
	.fifordout(),
	.fiforesetrd(1'b0),
	.grayelecidleinferselfromtx(transmit_pcs0_grayelecidleinferselout),
	.hipdataout(),
	.hipdatavalid(),
	.hipelecidle(),
	.hipphydonestatus(),
	.hipstatus(),
	.invpol(1'b0),
	.iqpphfifobyteselout(),
	.iqpphfifoptrsresetout(),
	.iqpphfifordenableout(),
	.iqpphfifowrclkout(),
	.iqpphfifowrenableout(),
	.k1detect(),
	.k2detect(),
	.localrefclk(transmit_pma0_clockout),
	.masterclk(1'b0),
	.parallelfdbk({20{1'b0}}),
	.patterndetect(),
	.phfifobyteselout(),
	.phfifobyteserdisableout(),
	.phfifooverflow(),
	.phfifoptrsresetout(),
	.phfifordenable(1'b1),
	.phfifordenableout(),
	.phfiforeset(),
	.phfiforesetout(),
	.phfifounderflow(),
	.phfifowrclkout(),
	.phfifowrdisable(1'b0),
	.phfifowrdisableout(),
	.phfifowrenableout(),
	.pipe8b10binvpolarity(1'b0),
	.pipebufferstat(),
	.pipedatavalid(),
	.pipeelecidle(),
	.pipeenrevparallellpbkfromtx(transmit_pcs0_pipeenrevparallellpbkout),
	.pipephydonestatus(),
	.pipepowerdown(transmit_pcs0_pipepowerdownout),
	.pipepowerstate(transmit_pcs0_pipepowerstateout),
	.pipestatetransdoneout(receive_pcs0_pipestatetransdoneout),
	.pipestatus(),
	.powerdn(2'b00),
	.prbscidenable(1'b0),
	.quadreset(cent_unit0_quadresetout),
	.rateswitchisdone(ch_clk_div0_rateswitchdone),
	.rateswitchout(),
	.rdalign(),
	.recoveredclk(receive_pma0_clockout),
	.revbitorderwa(1'b0),
	.revbyteorderwa(1'b0),
	.revparallelfdbkdata(receive_pcs0_revparallelfdbkdata),
	.rlv(),
	.rmfifoalmostempty(),
	.rmfifoalmostfull(),
	.rmfifodatadeleted(),
	.rmfifodatainserted(),
	.rmfifoempty(),
	.rmfifofull(),
	.rmfifordena(1'b0),
	.rmfiforeset(1'b0),
	.rmfifowrena(1'b0),
	.runningdisp(),
	.rxdetectvalid(transmit_pma0_rxdetectvalidout),
	.rxfound({transmit_pcs0_txdetectrx, transmit_pma0_rxfoundout}),
	.signaldetect(),
	.syncstatus(),
	.syncstatusdeskew(),
	.xauidelcondmetout(),
	.xauififoovrout(),
	.xauiinsertincompleteout(),
	.xauilatencycompout(),
	.xgmctrldet(),
	.xgmctrlin(1'b0),
	.xgmdatain({8{1'b0}}),
	.xgmdataout(),
	.xgmdatavalid(),
	.xgmrunningdisp());
defparam
	receive_pcs0.align_pattern = "0101111100",
	receive_pcs0.align_pattern_length = 10,
	receive_pcs0.align_to_deskew_pattern_pos_disp_only = "false",
	receive_pcs0.allow_align_polarity_inversion = "false",
	receive_pcs0.allow_pipe_polarity_inversion = "false",
	receive_pcs0.auto_spd_deassert_ph_fifo_rst_count = 8,
	receive_pcs0.auto_spd_phystatus_notify_count = 14,
	receive_pcs0.auto_spd_self_switch_enable = "false",
	receive_pcs0.bit_slip_enable = "false",
	receive_pcs0.byte_order_mode = "none",
	receive_pcs0.byte_order_pad_pattern = "0",
	receive_pcs0.byte_order_pattern = "0",
	receive_pcs0.byte_order_pld_ctrl_enable = "false",
	receive_pcs0.cdrctrl_bypass_ppm_detector_cycle = 1000,
	receive_pcs0.cdrctrl_enable = "false",
	receive_pcs0.cdrctrl_rxvalid_mask = "false",
	receive_pcs0.channel_bonding = "none",
	receive_pcs0.channel_number = 0,
	receive_pcs0.channel_width = 32,
	receive_pcs0.clk1_mux_select = "recovered clock",
	receive_pcs0.clk2_mux_select = "recovered clock",
	receive_pcs0.core_clock_0ppm = "false",
	receive_pcs0.datapath_low_latency_mode = "false",
	receive_pcs0.datapath_protocol = "basic",
	receive_pcs0.dec_8b_10b_compatibility_mode = "true",
	receive_pcs0.dec_8b_10b_mode = "cascaded",
	receive_pcs0.dec_8b_10b_polarity_inv_enable = "false",
	receive_pcs0.deskew_pattern = "0",
	receive_pcs0.disable_auto_idle_insertion = "true",
	receive_pcs0.disable_running_disp_in_word_align = "false",
	receive_pcs0.disallow_kchar_after_pattern_ordered_set = "false",
	receive_pcs0.dprio_config_mode = 8'h16,
	receive_pcs0.elec_idle_infer_enable = "false",
	receive_pcs0.elec_idle_num_com_detect = 0,
	receive_pcs0.enable_bit_reversal = "false",
	receive_pcs0.enable_deep_align = "true",
	receive_pcs0.enable_deep_align_byte_swap = "false",
	receive_pcs0.enable_self_test_mode = "false",
	receive_pcs0.enable_true_complement_match_in_word_align = "true",
	receive_pcs0.force_signal_detect_dig = "true",
	receive_pcs0.hip_enable = "false",
	receive_pcs0.infiniband_invalid_code = 0,
	receive_pcs0.insert_pad_on_underflow = "false",
	receive_pcs0.logical_channel_address = 0,
	receive_pcs0.num_align_code_groups_in_ordered_set = 0,
	receive_pcs0.num_align_cons_good_data = 1,
	receive_pcs0.num_align_cons_pat = 1,
	receive_pcs0.num_align_loss_sync_error = 1,
	receive_pcs0.ph_fifo_low_latency_enable = "true",
	receive_pcs0.ph_fifo_reg_mode = "false",
	receive_pcs0.ph_fifo_xn_mapping0 = "none",
	receive_pcs0.ph_fifo_xn_mapping1 = "none",
	receive_pcs0.ph_fifo_xn_mapping2 = "none",
	receive_pcs0.ph_fifo_xn_select = 1,
	receive_pcs0.pipe_auto_speed_nego_enable = "false",
	receive_pcs0.pipe_freq_scale_mode = "Frequency",
	receive_pcs0.pma_done_count = 249950,
	receive_pcs0.protocol_hint = "basic",
	receive_pcs0.rate_match_almost_empty_threshold = 11,
	receive_pcs0.rate_match_almost_full_threshold = 13,
	receive_pcs0.rate_match_back_to_back = "true",
	receive_pcs0.rate_match_delete_threshold = 13,
	receive_pcs0.rate_match_empty_threshold = 5,
	receive_pcs0.rate_match_fifo_mode = "false",
	receive_pcs0.rate_match_full_threshold = 20,
	receive_pcs0.rate_match_insert_threshold = 11,
	receive_pcs0.rate_match_ordered_set_based = "false",
	receive_pcs0.rate_match_pattern1 = "0",
	receive_pcs0.rate_match_pattern2 = "0",
	receive_pcs0.rate_match_pattern_size = 10,
	receive_pcs0.rate_match_reset_enable = "false",
	receive_pcs0.rate_match_skip_set_based = "false",
	receive_pcs0.rate_match_start_threshold = 7,
	receive_pcs0.rd_clk_mux_select = "core clock",
	receive_pcs0.recovered_clk_mux_select = "recovered clock",
	receive_pcs0.run_length = 40,
	receive_pcs0.run_length_enable = "true",
	receive_pcs0.rx_detect_bypass = "false",
	receive_pcs0.rx_phfifo_wait_cnt = 0,
	receive_pcs0.rxstatus_error_report_mode = 1,
	receive_pcs0.self_test_mode = "incremental",
	receive_pcs0.use_alignment_state_machine = "true",
	receive_pcs0.use_deserializer_double_data_mode = "true",
	receive_pcs0.use_deskew_fifo = "false",
	receive_pcs0.use_double_data_mode = "true",
	receive_pcs0.use_parallel_loopback = "false",
	receive_pcs0.use_rising_edge_triggered_pattern_align = "true",
	receive_pcs0.lpm_type = "stratixiv_hssi_rx_pcs";

stratixiv_hssi_rx_pma receive_pma0 ( 
	.adaptdone(),
	.analogtestbus(receive_pma0_analogtestbus),
	.clockout(receive_pma0_clockout),
	.datain(rx_datain),
	.dataout(receive_pma0_dataout),
	.dataoutfull(),
	.deserclock(rx_cdr_pll0_clk),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_rxpmadprioout[299:0]),
	.dprioout(receive_pma0_dprioout),
	.freqlock(1'b0),
	.ignorephslck(1'b0),
	.locktodata(1'b0),
	.locktoref(receive_pcs0_cdrctrllocktorefclkout),
	.locktorefout(receive_pma0_locktorefout),
	.offsetcancellationen(1'b0),
	.plllocked(rx_cdr_pll0_locked),
	.powerdn(cent_unit0_rxibpowerdown[0]),
	.ppmdetectclkrel(),
	.ppmdetectrefclk(rx_cdr_pll0_pfdrefclkout),
	.recoverdatain(rx_cdr_pll0_dataout),
	.recoverdataout(receive_pma0_recoverdataout),
	.reverselpbkout(receive_pma0_reverselpbkout),
	.revserialfdbkout(),
	.rxpmareset(cent_unit0_rxanalogresetout[0]),
	.seriallpbken(1'b0),
	.seriallpbkin(transmit_pma0_seriallpbkout),
	.signaldetect(rx_signaldetect),
	.testbussel(4'b0110));
defparam
	receive_pma0.adaptive_equalization_mode = "none",
	receive_pma0.allow_serial_loopback = "false",
	receive_pma0.channel_number = 0,
	receive_pma0.channel_type = "auto",
	receive_pma0.common_mode = "0.82V",
	receive_pma0.deserialization_factor = 20,
	receive_pma0.dprio_config_mode = 8'h16,
	receive_pma0.enable_ltd = "false",
	receive_pma0.enable_ltr = "false",
	receive_pma0.eq_dc_gain = 0,
	receive_pma0.eqa_ctrl = 0,
	receive_pma0.eqb_ctrl = 0,
	receive_pma0.eqc_ctrl = 0,
	receive_pma0.eqd_ctrl = 0,
	receive_pma0.eqv_ctrl = 0,
	receive_pma0.eyemon_bandwidth = 0,
	receive_pma0.force_signal_detect = "true",
	receive_pma0.logical_channel_address = 0,
	receive_pma0.low_speed_test_select = 0,
	receive_pma0.offset_cancellation = 1,
	receive_pma0.ppmselect = 32,
	receive_pma0.protocol_hint = "basic",
	receive_pma0.send_direct_reverse_serial_loopback = "None",
	receive_pma0.signal_detect_hysteresis = 2,
	receive_pma0.signal_detect_hysteresis_valid_threshold = 14,
	receive_pma0.signal_detect_loss_threshold = 9,
	receive_pma0.termination = "OCT 100 Ohms",
	receive_pma0.use_deser_double_data_width = "true",
	receive_pma0.use_external_termination = "false",
	receive_pma0.use_pma_direct = "false",
	receive_pma0.lpm_type = "stratixiv_hssi_rx_pma";

stratixiv_hssi_tx_pcs transmit_pcs0 ( 
	.clkout(tx_clkout),
	.coreclk(tx_clkout),
	.coreclkout(),
	.ctrlenable({{4{1'b0}}}),
	.datain({40{1'b0}}),
	.datainfull({2'b00,tx_ctrlin[3],tx_datain[31:24],2'b00,tx_ctrlin[2],tx_datain[23:16],2'b00,tx_ctrlin[1],tx_datain[15:8],2'b00,tx_ctrlin[0],tx_datain[7:0]}),
	.dataout(transmit_pcs0_dataout),
	.detectrxloop(1'b0),
	.digitalreset(cent_unit0_txdigitalresetout[0]),
	.dispval({{4{1'b0}}}),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_txpcsdprioout[149:0]),
	.dprioout(transmit_pcs0_dprioout),
	.elecidleinfersel(3'b000),
	.enrevparallellpbk(1'b0),
	.forcedisp({{4{1'b0}}}),
	.forcedispcompliance(1'b0),
	.forceelecidle(tx_forceelecidle),
	.forceelecidleout(transmit_pcs0_forceelecidleout),
	.grayelecidleinferselout(transmit_pcs0_grayelecidleinferselout),
	.hiptxclkout(),
	.invpol(1'b0),
	.iqpphfifobyteselout(),
	.iqpphfifordclkout(),
	.iqpphfifordenableout(),
	.iqpphfifowrenableout(),
	.localrefclk(transmit_pma0_clockout),
	.parallelfdbkout(),
	.phfifobyteselout(),
	.phfifobyteserdisable(),
	.phfifooverflow(),
	.phfifoptrsreset(),
	.phfifordclkout(),
	.phfiforddisable(1'b0),
	.phfiforddisableout(),
	.phfifordenableout(),
	.phfiforeset(1'b0),
	.phfiforesetout(),
	.phfifounderflow(),
	.phfifowrenable(1'b1),
	.phfifowrenableout(),
	.pipeenrevparallellpbkout(transmit_pcs0_pipeenrevparallellpbkout),
	.pipepowerdownout(transmit_pcs0_pipepowerdownout),
	.pipepowerstateout(transmit_pcs0_pipepowerstateout),
	.pipestatetransdone(receive_pcs0_pipestatetransdoneout),
	.pipetxdeemph(1'b0),
	.pipetxmargin(3'b000),
	.pipetxswing(1'b0),
	.powerdn(2'b00),
	.quadreset(cent_unit0_quadresetout),
	.rateswitchout(),
	.rdenablesync(),
	.revparallelfdbk(receive_pcs0_revparallelfdbkdata),
	.txdetectrx(transmit_pcs0_txdetectrx),
	.xgmctrl(cent_unit0_txctrlout[0]),
	.xgmctrlenable(),
	.xgmdatain(cent_unit0_txdataout[7:0]),
	.xgmdataout());
defparam
	transmit_pcs0.allow_polarity_inversion = "false",
	transmit_pcs0.auto_spd_self_switch_enable = "false",
	transmit_pcs0.bitslip_enable = "false",
	transmit_pcs0.channel_bonding = "none",
	transmit_pcs0.channel_number = 0,
	transmit_pcs0.channel_width = 32,
	transmit_pcs0.core_clock_0ppm = "false",
	transmit_pcs0.datapath_low_latency_mode = "false",
	transmit_pcs0.datapath_protocol = "basic",
	transmit_pcs0.disable_ph_low_latency_mode = "false",
	transmit_pcs0.disparity_mode = "none",
	transmit_pcs0.dprio_config_mode = 8'h16,
	transmit_pcs0.elec_idle_delay = 3,
	transmit_pcs0.enable_bit_reversal = "false",
	transmit_pcs0.enable_idle_selection = "false",
	transmit_pcs0.enable_reverse_parallel_loopback = "false",
	transmit_pcs0.enable_self_test_mode = "false",
	transmit_pcs0.enable_symbol_swap = "false",
	transmit_pcs0.enc_8b_10b_compatibility_mode = "true",
	transmit_pcs0.enc_8b_10b_mode = "cascaded",
	transmit_pcs0.force_echar = "false",
	transmit_pcs0.force_kchar = "false",
	transmit_pcs0.hip_enable = "false",
	transmit_pcs0.logical_channel_address = 0,
	transmit_pcs0.ph_fifo_reg_mode = "false",
	transmit_pcs0.ph_fifo_xn_mapping0 = "none",
	transmit_pcs0.ph_fifo_xn_mapping1 = "none",
	transmit_pcs0.ph_fifo_xn_mapping2 = "none",
	transmit_pcs0.ph_fifo_xn_select = 1,
	transmit_pcs0.pipe_auto_speed_nego_enable = "false",
	transmit_pcs0.pipe_freq_scale_mode = "Frequency",
	transmit_pcs0.prbs_cid_pattern = "false",
	transmit_pcs0.protocol_hint = "basic",
	transmit_pcs0.refclk_select = "local",
	transmit_pcs0.self_test_mode = "incremental",
	transmit_pcs0.use_double_data_mode = "true",
	transmit_pcs0.use_serializer_double_data_mode = "true",
	transmit_pcs0.wr_clk_mux_select = "core_clk",
	transmit_pcs0.lpm_type = "stratixiv_hssi_tx_pcs";

stratixiv_hssi_tx_pma transmit_pma0 ( 
	.clockout(transmit_pma0_clockout),
	.datain({{44{1'b0}}, transmit_pcs0_dataout}),
	.dataout(tx_dataout),
	.detectrxpowerdown(cent_unit0_txdetectrxpowerdown[0]),
	.dftout(),
	.dpriodisable(cent_unit0_dpriodisableout),
	.dprioin(cent_unit0_txpmadprioout[299:0]),
	.dprioout(transmit_pma0_dprioout),
	.fastrefclk0in(ch_clk_div0_analogfastrefclkout),
	.fastrefclk1in({2{1'b0}}),
	.fastrefclk2in({2{1'b0}}),
	.fastrefclk4in({2{1'b0}}),
	.forceelecidle(transmit_pcs0_forceelecidleout),
	.powerdn(cent_unit0_txobpowerdown[0]),
	.refclk0in(ch_clk_div0_analogrefclkout),
	.refclk0inpulse(ch_clk_div0_analogrefclkpulse),
	.refclk1in({2{1'b0}}),
	.refclk1inpulse(1'b0),
	.refclk2in({2{1'b0}}),
	.refclk2inpulse(1'b0),
	.refclk4in({2{1'b0}}),
	.refclk4inpulse(1'b0),
	.revserialfdbk(receive_pma0_reverselpbkout),
	.rxdetecten(transmit_pcs0_txdetectrx),
	.rxdetectvalidout(transmit_pma0_rxdetectvalidout),
	.rxfoundout(transmit_pma0_rxfoundout),
	.seriallpbkout(transmit_pma0_seriallpbkout),
	.txpmareset(cent_unit0_txanalogresetout[0]));
defparam
	transmit_pma0.analog_power = "1.4V",
	transmit_pma0.channel_number = 0,
	transmit_pma0.channel_type = "auto",
	transmit_pma0.clkin_select = 0,
	transmit_pma0.clkmux_delay = "false",
	transmit_pma0.common_mode = "0.65V",
	transmit_pma0.dprio_config_mode = 8'h16,
	transmit_pma0.enable_reverse_serial_loopback = "false",
	transmit_pma0.logical_channel_address = 0,
	transmit_pma0.logical_protocol_hint_0 = "basic",
	transmit_pma0.low_speed_test_select = 0,
	transmit_pma0.physical_clkin0_mapping = "x1",
	transmit_pma0.preemp_pretap = 0,
	transmit_pma0.preemp_pretap_inv = "false",
	transmit_pma0.preemp_tap_1 = 0,
	transmit_pma0.preemp_tap_2 = 0,
	transmit_pma0.preemp_tap_2_inv = "false",
	transmit_pma0.protocol_hint = "basic",
	transmit_pma0.rx_detect = 0,
	transmit_pma0.serialization_factor = 20,
	transmit_pma0.slew_rate = "off",
	transmit_pma0.termination = "OCT 100 Ohms",
	transmit_pma0.use_external_termination = "false",
	transmit_pma0.use_pma_direct = "false",
	transmit_pma0.use_ser_double_data_mode = "true",
	transmit_pma0.vod_selection = 4,
	transmit_pma0.lpm_type = "stratixiv_hssi_tx_pma";

assign reconf_fromgxb = {{12{1'b0}}, receive_pma0_analogtestbus[5:2], cent_unit0_dprioout};

assign rx_dataout[ 7: 0] = receive_pcs0_dataoutfull[7:0];
assign rx_dataout[15: 8] = receive_pcs0_dataoutfull[23:16];
assign rx_dataout[23:16] = receive_pcs0_dataoutfull[39:32];
assign rx_dataout[31:24] = receive_pcs0_dataoutfull[55:48];

assign rx_ctrlout[0] = receive_pcs0_dataoutfull[8];
assign rx_ctrlout[1] = receive_pcs0_dataoutfull[24];
assign rx_ctrlout[2] = receive_pcs0_dataoutfull[40];
assign rx_ctrlout[3] = receive_pcs0_dataoutfull[56];

assign rx_errdetect[0] = receive_pcs0_dataoutfull[9];
assign rx_errdetect[1] = receive_pcs0_dataoutfull[25]; 
assign rx_errdetect[2] = receive_pcs0_dataoutfull[41];
assign rx_errdetect[3] = receive_pcs0_dataoutfull[57];

assign rx_disperr[0] = receive_pcs0_dataoutfull[11];
assign rx_disperr[1] = receive_pcs0_dataoutfull[27];
assign rx_disperr[2] = receive_pcs0_dataoutfull[43];
assign rx_disperr[3] = receive_pcs0_dataoutfull[59];

gxb_reconfig reconf (
	.reconfig_clk(reconf_clk),
	.reconfig_fromgxb(reconf_fromgxb),
	.reconfig_togxb(reconf_togxb),
	.reconfig_mode_sel(3'b101),
	.reconfig_data(reconf_data),
	.reconfig_address_out(reconf_address),
	.write_all((state == CONF)),
	.busy(reconf_busy));

altsyncram config_rom (
	.clock0 (reconf_clk),
	.address_a ({sata_genreg,reconf_address}),
	.q_a (reconf_data));
defparam config_rom.init_file = "sata_config.mif";
defparam config_rom.intended_device_family = "Stratix IV";
defparam config_rom.lpm_hint = "ENABLE_RUNTIME_MOD=NO";
defparam config_rom.lpm_type = "altsyncram";
defparam config_rom.numwords_a = 256;
defparam config_rom.operation_mode = "ROM";
defparam config_rom.widthad_a = 8;
defparam config_rom.width_a = 16;

endmodule // sata_basic
