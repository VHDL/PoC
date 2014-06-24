
// Copyright (C) 1991-2011 Altera Corporation
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

module sata_basic (
	inclk,
	reset,
	rx_datain,
	tx_datain,
	tx_ctrlin,
	tx_clkin,
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
input tx_clkin;
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
wire [2:0] reconf_togxb;
wire [0:0] reconf_fromgxb;
wire [4:0] reconf_address;
wire reconf_busy;
wire tx_pllfastclk_in;
wire pllreset_in;
wire pllpowerdn_in;
wire cent_unit_dpriodisableout;
wire [39:0] pll0_dprioin;
wire [299:0] rx_dprioin;
wire [149:0] tx_dprioin;
wire [39:0] pll0_dprioout;
wire [299:0] rx_dprioout;
wire [149:0] tx_dprioout;
wire cent_unit_quadresetout;
wire rx_analogreset_out;
wire rx_adceresetout;
wire rx_cruresetout;
wire cent_unit_rxadcepowerdn;
wire cent_unit_rxcrupowerdn;
wire cent_unit_rxibpowerdn;
wire rx_digitalreset_out;
wire tx_digitalreset_out;
wire tx_analogreset_out;
wire cent_unit_txobpowerdn;
wire cent_unit_txdividerpowerdn;
wire cent_unit_txdetectrxpowerdn;
wire cent_unit_txctrlout;
wire [7:0] cent_unit_tx_xgmdataout;

wire [63:0] receive_DATAOUT_bus;
wire [31:0] cent_unit_TXDATAOUT_bus;
wire [3:0] cent_unit_TXCTRLOUT_bus;
wire [2:0] cent_unit_PLLRESETOUT_bus;
wire [3:0] cent_unit_TXDIGITALRESETOUT_bus;
wire [3:0] cent_unit_RXDIGITALRESETOUT_bus;
wire [3:0] cent_unit_TXANALOGRESETOUT_bus;
wire [3:0] cent_unit_RXANALOGRESETOUT_bus;
wire [119:0] cent_unit_CMUPLLDPRIOOUT_bus;
wire [1199:0] cent_unit_RXDPRIOOUT_bus;
wire [599:0] cent_unit_TXDPRIOOUT_bus;
wire [119:0] cent_unit_CMUPLLDPRIOIN_bus;
wire [1199:0] cent_unit_RXDPRIOIN_bus;
wire [599:0] cent_unit_TXDPRIOIN_bus;
wire [3:0] cent_unit_RXCRURESETOUT_bus;
wire [3:0] cent_unit_RXADCERESETOUT_bus;
wire [3:0] cent_unit_RXADCEPOWERDN_bus;
wire [3:0] cent_unit_RXCRUPOWERDN_bus;
wire [3:0] cent_unit_RXIBPOWERDN_bus;
wire [3:0] cent_unit_TXOBPOWERDN_bus;
wire [3:0] cent_unit_TXDIVIDERPOWERDN_bus;
wire [3:0] cent_unit_TXDETECTRXPOWERDN_bus;
wire [2:0] cent_unit_PLLPOWERDN_bus;

assign rx_dataout[ 7: 0] = receive_DATAOUT_bus[7:0];
assign rx_dataout[15: 8] = receive_DATAOUT_bus[23:16];
assign rx_dataout[23:16] = receive_DATAOUT_bus[39:32];
assign rx_dataout[31:24] = receive_DATAOUT_bus[55:48];

assign rx_ctrlout[0] = receive_DATAOUT_bus[8];
assign rx_ctrlout[1] = receive_DATAOUT_bus[24];
assign rx_ctrlout[2] = receive_DATAOUT_bus[40];
assign rx_ctrlout[3] = receive_DATAOUT_bus[56];

assign rx_errdetect[0] = receive_DATAOUT_bus[9];
assign rx_errdetect[1] = receive_DATAOUT_bus[25]; 
assign rx_errdetect[2] = receive_DATAOUT_bus[41];
assign rx_errdetect[3] = receive_DATAOUT_bus[57];

assign rx_disperr[0] = receive_DATAOUT_bus[11];
assign rx_disperr[1] = receive_DATAOUT_bus[27];
assign rx_disperr[2] = receive_DATAOUT_bus[43];
assign rx_disperr[3] = receive_DATAOUT_bus[59];

assign cent_unit_tx_xgmdataout = cent_unit_TXDATAOUT_bus[7:0];
assign cent_unit_txctrlout = cent_unit_TXCTRLOUT_bus[0];
assign tx_digitalreset_out = cent_unit_TXDIGITALRESETOUT_bus[0];
assign rx_digitalreset_out = cent_unit_RXDIGITALRESETOUT_bus[0];
assign tx_analogreset_out = cent_unit_TXANALOGRESETOUT_bus[0];
assign rx_analogreset_out = cent_unit_RXANALOGRESETOUT_bus[0];

assign pllreset_in  = cent_unit_PLLRESETOUT_bus[0];
assign pll0_dprioin = cent_unit_CMUPLLDPRIOOUT_bus[39:0];
assign rx_dprioin = cent_unit_RXDPRIOOUT_bus[299:0];
assign tx_dprioin = cent_unit_TXDPRIOOUT_bus[149:0];
assign cent_unit_RXDPRIOIN_bus[299:0] = rx_dprioout;
assign cent_unit_TXDPRIOIN_bus[149:0] = tx_dprioout;
assign cent_unit_CMUPLLDPRIOIN_bus[39:0] = pll0_dprioout;

assign rx_cruresetout = cent_unit_RXCRURESETOUT_bus[0];
assign rx_adceresetout = cent_unit_RXADCERESETOUT_bus[0];
assign cent_unit_rxadcepowerdn = cent_unit_RXADCEPOWERDN_bus[0];
assign cent_unit_rxcrupowerdn = cent_unit_RXCRUPOWERDN_bus[0];
assign cent_unit_rxibpowerdn = cent_unit_RXIBPOWERDN_bus[0];
assign cent_unit_txobpowerdn = cent_unit_TXOBPOWERDN_bus[0];
assign cent_unit_txdividerpowerdn = cent_unit_TXDIVIDERPOWERDN_bus[0];
assign cent_unit_txdetectrxpowerdn = cent_unit_TXDETECTRXPOWERDN_bus[0];
assign pllpowerdn_in = cent_unit_PLLPOWERDN_bus[0];

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

stratixiigx_hssi_cmu_pll pll0 (
	.pllreset(pllreset_in),
	.pllpowerdn(pllpowerdn_in),
	.dpriodisable(cent_unit_dpriodisableout),
	.clk({7'b0000000,inclk}),
	.dprioin(pll0_dprioin),
	.clkout(tx_pllfastclk_in),
	.locked(locked),
	.vcobypassout(),
	.dprioout(pll0_dprioout),
	.fbclkout());
defparam pll0.charge_pump_current_control = 2;
defparam pll0.divide_by = 1;
defparam pll0.dprio_config_mode = 22;
defparam pll0.enable_pll_cascade = "false";
defparam pll0.inclk0_period = 6667;
defparam pll0.loop_filter_resistor_control = 3;
defparam pll0.multiply_by = 20;
defparam pll0.pfd_clk_select = 0;
defparam pll0.pll_number = 0;
defparam pll0.pll_type = "normal";
defparam pll0.protocol_hint = "basic";
defparam pll0.sim_clkout_latency = 0;
defparam pll0.sim_clkout_phase_shift = 0;
defparam pll0.vco_range = "low";

stratixiigx_hssi_receiver receiver (
	.datain(rx_datain),
	.locktodata(1'b0),
	.locktorefclk(1'b0),
	.quadreset(cent_unit_quadresetout),
	.analogreset(rx_analogreset_out),
	.adcereset(rx_adceresetout),
	.crureset(rx_cruresetout),
	.adcepowerdn(cent_unit_rxadcepowerdn),
	.crupowerdn(cent_unit_rxcrupowerdn),
	.ibpowerdn(cent_unit_rxibpowerdn),
	.serialfdbk(1'b0),
	.seriallpbken(1'b0),
	.coreclk(rx_clkout),
	.masterclk(1'b0),
	.localrefclk(1'b0),
	.refclk(1'b0),
	.a1a2size(1'b0),
	.enapatternalign(rx_patternalign),
	.bitslip(1'b0),
	.pipe8b10binvpolarity(1'b0),
	.rmfifordena(1'b0),
	.rmfifowrena(1'b0),
	.enabyteord(1'b0),
	.phfifordenable(1'b1),
	.phfifowrdisable(1'b0),
	.phfifox4wrenable(1'b1),
	.phfifox4rdenable(1'b1),
	.phfifox4wrclk(1'b1),
	.phfifox4bytesel(1'b0),
	.phfifox8wrenable(1'b1),
	.phfifox8rdenable(1'b1),
	.phfifox8wrclk(1'b1),
	.phfifox8bytesel(1'b0),
	.invpol(1'b0),
	.revbitorderwa(1'b0),
	.revbyteorderwa(1'b0),
	.digitalreset(rx_digitalreset_out),
	.phfiforeset(1'b0),
	.rmfiforeset(1'b0),
	.dpriodisable(cent_unit_dpriodisableout),
	.rxdetectvalid(1'b0),
	.alignstatus(1'b0),
	.disablefifordin(1'b0),
	.disablefifowrin(1'b0),
	.fifordin(1'b0),
	.alignstatussync(1'b0),
	.enabledeskew(1'b0),
	.fiforesetrd(1'b0),
	.xgmctrlin(1'b0),
	.cruclk({8'b00000000,inclk}),
	.parallelfdbk(20'b00000000000000000000),
	.pipepowerstate(4'b0000),
	.xgmdatain(8'b00000000),
	.termvoltage(3'b000),
	.testsel(4'b0000),
	.rxfound(2'b00),
	.pipepowerdown(2'b00),
	.dprioin(rx_dprioin),
	.syncstatusdeskew(),
	.adetectdeskew(),
	.rdalign(),
	.xgmctrldet(),
	.xgmrunningdisp(),
	.xgmdatavalid(),
	.rmfifofull(),
	.rmfifoalmostfull(),
	.rmfifoempty(),
	.rmfifoalmostempty(),
	.clkout(rx_clkout),
	.recovclkout(),
	.cmudivclkout(),
	.byteorderalignstatus(),
	.phfifooverflow(),
	.phfifounderflow(),
	.phfifowrenableout(),
	.phfifordenableout(),
	.phfifowrclkout(),
	.phfifobyteselout(),
	.pipephydonestatus(),
	.pipedatavalid(),
	.pipeelecidle(),
	.pipestatetransdoneout(),
	.disablefifordout(),
	.disablefifowrout(),
	.fifordout(),
	.alignstatussyncout(),
	.rlv(),
	.bisterr(),
	.bistdone(),
	.revserialfdbkout(),
	.signaldetect(rx_signaldetect),
	.phaselockloss(),
	.freqlock(),
	.dataout(),
	.dataoutfull(receive_DATAOUT_bus),
	.syncstatus(),
	.patterndetect(),
	.a1a2sizeout(),
	.ctrldetect(),
	.errdetect(),
	.disperr(),
	.xgmdataout(),
	.runningdisp(),
	.rmfifodatainserted(),
	.rmfifodatadeleted(),
	.revparallelfdbkdata(),
	.analogtestbus(),
	.a1detect(),
	.a2detect(),
	.k1detect(),
	.k2detect(),
	.pipestatus(),
	.pipebufferstat(),
	.dprioout(rx_dprioout));
defparam receiver.adaptive_equalization_mode = "none";
defparam receiver.align_loss_sync_error_num = 1;
defparam receiver.align_pattern = "0101111100";
defparam receiver.align_pattern_length = 10;
defparam receiver.align_to_deskew_pattern_pos_disp_only = "false";
defparam receiver.allow_align_polarity_inversion = "false";
defparam receiver.allow_pipe_polarity_inversion = "false";
defparam receiver.allow_serial_loopback = "false";
defparam receiver.bandwidth_mode = 1;
defparam receiver.bit_slip_enable = "false";
defparam receiver.byte_order_pad_pattern = "000000000";
defparam receiver.byte_order_pattern = "000000000";
defparam receiver.byte_ordering_mode = "pattern based";
defparam receiver.channel_bonding = "none";
defparam receiver.channel_number = 0;
defparam receiver.channel_width = 32;
defparam receiver.charge_pump_current_control = 1;
defparam receiver.clk1_mux_select = "recovered clock";
defparam receiver.clk2_mux_select = "recovered clock";
defparam receiver.common_mode = "0.9v";
defparam receiver.cru_clock_select = 0;
defparam receiver.cru_divide_by = 1;
defparam receiver.cru_multiply_by = 20;
defparam receiver.cru_pre_divide_by = 1;
defparam receiver.cruclk0_period = 6667;
defparam receiver.datapath_protocol = "basic";
defparam receiver.dec_8b_10b_compatibility_mode = "true";
defparam receiver.dec_8b_10b_mode = "cascaded";
defparam receiver.deskew_pattern = "0";
defparam receiver.disable_auto_idle_insertion = "false";
defparam receiver.disable_ph_low_latency_mode = "false";
defparam receiver.disable_running_disp_in_word_align = "false";
defparam receiver.disallow_kchar_after_pattern_ordered_set = "false";
defparam receiver.dprio_config_mode = 22;
defparam receiver.dprio_width = 300;
defparam receiver.enable_bit_reversal = "false";
defparam receiver.enable_dc_coupling = "false";
defparam receiver.enable_deep_align = "true";
defparam receiver.enable_deep_align_byte_swap = "false";
defparam receiver.enable_lock_to_data_sig = "false";
defparam receiver.enable_lock_to_refclk_sig = "false";
defparam receiver.enable_self_test_mode = "false";
defparam receiver.enable_true_complement_match_in_word_align = "true";
defparam receiver.eq_adapt_seq_control = 3;
defparam receiver.eq_max_gradient_control = 7;
defparam receiver.equalizer_ctrl_a = 0;
defparam receiver.equalizer_ctrl_b = 0;
defparam receiver.equalizer_ctrl_c = 0;
defparam receiver.equalizer_ctrl_d = 0;
defparam receiver.equalizer_ctrl_v = 0;
defparam receiver.equalizer_dc_gain = 0;
defparam receiver.force_freq_det_high = "false";
defparam receiver.force_freq_det_low = "false";
defparam receiver.force_signal_detect = "true";
defparam receiver.force_signal_detect_dig = "true";
defparam receiver.ignore_lock_detect = "false";
defparam receiver.infiniband_invalid_code = 0;
defparam receiver.insert_pad_on_underflow = "false";
defparam receiver.loop_filter_resistor_control = 0;
defparam receiver.loop_filter_ripple_capacitor_control = 0;
defparam receiver.num_align_code_groups_in_ordered_set = 0;
defparam receiver.num_align_cons_good_data = 1;
defparam receiver.num_align_cons_pat = 1;
defparam receiver.phystatus_reset_toggle = "false";
defparam receiver.ppmselect = 32;
defparam receiver.prbs_all_one_detect = "false";
defparam receiver.protocol_hint = "basic";
defparam receiver.rate_match_almost_empty_threshold = 11;
defparam receiver.rate_match_almost_full_threshold = 13;
defparam receiver.rate_match_back_to_back = "false";
defparam receiver.rate_match_fifo_mode = "none";
defparam receiver.rate_match_ordered_set_based = "false";
defparam receiver.rate_match_pattern1 = "0";
defparam receiver.rate_match_pattern2 = "0";
defparam receiver.rate_match_pattern_size = 10;
defparam receiver.rate_match_skip_set_based = "false";
defparam receiver.rd_clk_mux_select = "core clock";
defparam receiver.recovered_clk_mux_select = "recovered clock";
defparam receiver.run_length = 200;
defparam receiver.run_length_enable = "false";
defparam receiver.rx_detect_bypass = "false";
defparam receiver.self_test_mode = "incremental";
defparam receiver.send_direct_reverse_serial_loopback = "true";
defparam receiver.signal_detect_hysteresis_enabled = "false";
defparam receiver.signal_detect_threshold = 7;
defparam receiver.sim_rxpll_clkout_latency = 0;
defparam receiver.sim_rxpll_clkout_phase_shift = 0;
defparam receiver.termination = "oct_100_ohms";
defparam receiver.use_align_state_machine = "true";
defparam receiver.use_deserializer_double_data_mode = "true";
defparam receiver.use_deskew_fifo = "false";
defparam receiver.use_double_data_mode = "true";
defparam receiver.use_parallel_loopback = "false";
defparam receiver.use_rate_match_pattern1_only = "false";
defparam receiver.use_rising_edge_triggered_pattern_align = "true";
defparam receiver.use_termvoltage_signal = "false";
defparam receiver.vco_range = "low";

stratixiigx_hssi_transmitter transmitter (
	.detectrxloop(1'b0),
	.revserialfdbk(1'b0),
	.enrevparallellpbk(1'b0),
	.forceelecidle(tx_forceelecidle),
	.forcedispcompliance(1'b0),
	.pipestatetransdone(1'b0),
	.digitalreset(tx_digitalreset_out),
	.phfiforeset(1'b0),
	.invpol(1'b0),
	.coreclk(tx_clkin),
	.phfiforddisable(1'b0),
	.phfifowrenable(1'b1),
	.phfifox4wrenable(1'b1),
	.phfifox4rdenable(1'b1),
	.phfifox4rdclk(1'b1),
	.phfifox4bytesel(1'b0),
	.phfifox8wrenable(1'b1),
	.phfifox8rdenable(1'b1),
	.phfifox8rdclk(1'b1),
	.phfifox8bytesel(1'b0),
	.analogx4refclk(1'b0),
	.analogx4fastrefclk(1'b0),
	.analogx8refclk(1'b0),
	.analogx8fastrefclk(1'b0),
	.refclk(1'b0),
	.quadreset(cent_unit_quadresetout),
	.analogreset(tx_analogreset_out),
	.obpowerdn(cent_unit_txobpowerdn),
	.dividerpowerdn(cent_unit_txdividerpowerdn),
	.detectrxpowerdn(cent_unit_txdetectrxpowerdn),
	.xgmctrl(cent_unit_txctrlout),
	.dpriodisable(cent_unit_dpriodisableout),
	.vcobypassin(1'b0),
	.datain(40'b0000000000000000000000000000000000000000),
	.datainfull({2'b00,tx_ctrlin[3],tx_datain[31:24],2'b00,tx_ctrlin[2],tx_datain[23:16],2'b00,tx_ctrlin[1],tx_datain[15:8],2'b00,tx_ctrlin[0],tx_datain[7:0]}),
	.ctrlenable(4'b0000),
	.forcedisp(4'b0000),
	.dispval(4'b0000),
	.revparallelfdbk(20'b00000000000000000000),
	.powerdn(2'b00),
	.pllfastclk({1'b0,tx_pllfastclk_in}),
	.termvoltage(2'b00),
	.xgmdatain(cent_unit_tx_xgmdataout),
	.dprioin(tx_dprioin),
	.dataout(tx_dataout),
	.clkout(tx_clkout),
	.refclkout(),
	.phfifooverflow(),
	.phfifounderflow(),
	.phfifowrenableout(),
	.phfifordenableout(),
	.phfifordclkout(),
	.phfifobyteselout(),
	.serialfdbkout(),
	.xgmctrlenable(),
	.rdenablesync(),
	.rxdetectvalidout(),
	.parallelfdbkout(),
	.xgmdataout(),
	.pipepowerstateout(),
	.pipepowerdownout(),
	.rxfoundout(),
	.dprioout(tx_dprioout));
defparam transmitter.allow_polarity_inversion = "false";
defparam transmitter.analog_power = "1.5v";
defparam transmitter.channel_bonding = "none";
defparam transmitter.channel_number = 0;
defparam transmitter.channel_width = 32;
defparam transmitter.common_mode = "0.6v";
defparam transmitter.disable_ph_low_latency_mode = "false";
defparam transmitter.disparity_mode = "none";
defparam transmitter.divider_refclk_select_pll_fast_clk0 = "true";
defparam transmitter.dprio_config_mode = 22;
defparam transmitter.dprio_width = 150;
defparam transmitter.elec_idle_delay = 5;
defparam transmitter.enable_bit_reversal = "false";
defparam transmitter.enable_idle_selection = "false";
defparam transmitter.enable_reverse_parallel_loopback = "false";
defparam transmitter.enable_reverse_serial_loopback = "false";
defparam transmitter.enable_self_test_mode = "false";
defparam transmitter.enable_slew_rate = "false";
defparam transmitter.enable_symbol_swap = "false";
defparam transmitter.enc_8b_10b_compatibility_mode = "true";
defparam transmitter.enc_8b_10b_mode = "cascaded";
defparam transmitter.force_echar = "false";
defparam transmitter.force_kchar = "false";
defparam transmitter.prbs_all_one_detect = "false";
defparam transmitter.preemp_pretap = 0;
defparam transmitter.preemp_pretap_inv = "false";
defparam transmitter.preemp_tap_1 = 0;
defparam transmitter.preemp_tap_2 = 0;
defparam transmitter.preemp_tap_2_inv = "false";
defparam transmitter.protocol_hint = "basic";
defparam transmitter.refclk_divide_by = 1;
defparam transmitter.refclk_select = "local";
defparam transmitter.rxdetect_ctrl = 0;
defparam transmitter.self_test_mode = "incremental";
defparam transmitter.serializer_clk_select = "local";
defparam transmitter.termination = "oct_100_ohms";
defparam transmitter.transmit_protocol = "basic";
defparam transmitter.use_double_data_mode = "true";
defparam transmitter.use_serializer_double_data_mode = "true";
defparam transmitter.use_termvoltage_signal = "false";
defparam transmitter.vod_selection = 2;
defparam transmitter.wr_clk_mux_select = "core_clk";

stratixiigx_hssi_central_management_unit cent_unit (
	.quadenable(1'b1),
	.quadreset(1'b0),
	.dpclk(reconf_clk),
	.rdenablesync(1'b0),
	.txclk(1'b0),
	.rxclk(1'b0),
	.recovclk(1'b0),
	.dprioin(reconf_togxb[0]),
	.dpriodisable(reconf_togxb[1]),
	.dprioload(reconf_togxb[2]),
	.rxdigitalreset({3'b000,digitalreset}),
	.txdigitalreset({3'b000,digitalreset}),
	.rxanalogreset(4'b0000),
	.rxpowerdown(4'b0000),
	.fixedclk(4'b0000),
	.txdatain(32'b00000000000000000000000000000000),
	.txctrl(4'b0000),
	.rxdatain(32'b00000000000000000000000000000000),
	.rxctrl(4'b0000),
	.rxrunningdisp(4'b0000),
	.rxdatavalid(4'b0000),
	.adet(4'b0000),
	.syncstatus(4'b0000),
	.rdalign(4'b0000),
	.rxdprioin(cent_unit_RXDPRIOIN_bus),
	.txdprioin(cent_unit_TXDPRIOIN_bus),
	.cmuplldprioin(cent_unit_CMUPLLDPRIOIN_bus),
	.cmudividerdprioin(30'b000000000000000000000000000000),
	.refclkdividerdprioin(2'b00),
	.dprioout(reconf_fromgxb[0]),
	.dpriooe(),
	.dpriodisableout(cent_unit_dpriodisableout),
	.quadresetout(cent_unit_quadresetout),
	.clkdivpowerdn(),
	.alignstatus(),
	.enabledeskew(),
	.fiforesetrd(),
	.txdigitalresetout(cent_unit_TXDIGITALRESETOUT_bus),
	.txanalogresetout(cent_unit_TXANALOGRESETOUT_bus),
	.rxdigitalresetout(cent_unit_RXDIGITALRESETOUT_bus),
	.rxanalogresetout(cent_unit_RXANALOGRESETOUT_bus),
	.rxcruresetout(cent_unit_RXCRURESETOUT_bus),
	.rxadceresetout(cent_unit_RXADCERESETOUT_bus),
	.pllresetout(cent_unit_PLLRESETOUT_bus),
	.rxadcepowerdn(cent_unit_RXADCEPOWERDN_bus),
	.rxcrupowerdn(cent_unit_RXCRUPOWERDN_bus),
	.rxibpowerdn(cent_unit_RXIBPOWERDN_bus),
	.txobpowerdn(cent_unit_TXOBPOWERDN_bus),
	.txdividerpowerdn(cent_unit_TXDIVIDERPOWERDN_bus),
	.txdetectrxpowerdn(cent_unit_TXDETECTRXPOWERDN_bus),
	.pllpowerdn(cent_unit_PLLPOWERDN_bus),
	.rxdprioout(cent_unit_RXDPRIOOUT_bus),
	.txdprioout(cent_unit_TXDPRIOOUT_bus),
	.cmuplldprioout(cent_unit_CMUPLLDPRIOOUT_bus),
	.cmudividerdprioout(),
	.refclkdividerdprioout(),
	.txdataout(cent_unit_TXDATAOUT_bus),
	.rxdataout(),
	.txctrlout(cent_unit_TXCTRLOUT_bus),
	.rxctrlout(),
	.digitaltestout());
defparam cent_unit.bonded_quad_mode = "none";
defparam cent_unit.cmu_divider_inclk0_physical_mapping = "none";
defparam cent_unit.cmu_divider_inclk1_physical_mapping = "none";
defparam cent_unit.cmu_divider_inclk2_physical_mapping = "none";
defparam cent_unit.devaddr = 1;
defparam cent_unit.dprio_config_mode = 30;
defparam cent_unit.in_xaui_mode = "false";
defparam cent_unit.num_con_align_chars_for_align = 0;
defparam cent_unit.num_con_errors_for_align_loss = 0;
defparam cent_unit.num_con_good_data_for_align_approach = 0;
defparam cent_unit.offset_all_errors_align = "false";
defparam cent_unit.pll0_inclk0_logical_to_physical_mapping = "iq0";
defparam cent_unit.pll0_inclk1_logical_to_physical_mapping = "iq1";
defparam cent_unit.pll0_inclk2_logical_to_physical_mapping = "iq2";
defparam cent_unit.pll0_inclk3_logical_to_physical_mapping = "iq3";
defparam cent_unit.pll0_inclk4_logical_to_physical_mapping = "iq4";
defparam cent_unit.pll0_inclk5_logical_to_physical_mapping = "pld_clk";
defparam cent_unit.pll0_inclk6_logical_to_physical_mapping = "clkrefclk0";
defparam cent_unit.pll0_inclk7_logical_to_physical_mapping = "clkrefclk1";
defparam cent_unit.pll0_logical_to_physical_mapping = -1;
defparam cent_unit.pll1_inclk0_logical_to_physical_mapping = "iq0";
defparam cent_unit.pll1_inclk1_logical_to_physical_mapping = "iq1";
defparam cent_unit.pll1_inclk2_logical_to_physical_mapping = "iq2";
defparam cent_unit.pll1_inclk3_logical_to_physical_mapping = "iq3";
defparam cent_unit.pll1_inclk4_logical_to_physical_mapping = "iq4";
defparam cent_unit.pll1_inclk5_logical_to_physical_mapping = "pld_clk";
defparam cent_unit.pll1_inclk6_logical_to_physical_mapping = "clkrefclk0";
defparam cent_unit.pll1_inclk7_logical_to_physical_mapping = "clkrefclk1";
defparam cent_unit.pll1_logical_to_physical_mapping = -1;
defparam cent_unit.pll2_inclk0_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk1_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk2_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk3_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk4_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk5_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk6_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_inclk7_logical_to_physical_mapping = "none";
defparam cent_unit.pll2_logical_to_physical_mapping = -1;
defparam cent_unit.portaddr = 1;
defparam cent_unit.refclk_divider0_logical_to_physical_mapping = -1;
defparam cent_unit.refclk_divider1_logical_to_physical_mapping = -1;
defparam cent_unit.rx0_cru_clock0_physical_mapping = "iq0";
defparam cent_unit.rx0_cru_clock1_physical_mapping = "iq1";
defparam cent_unit.rx0_cru_clock2_physical_mapping = "iq2";
defparam cent_unit.rx0_cru_clock3_physical_mapping = "iq3";
defparam cent_unit.rx0_cru_clock4_physical_mapping = "iq4";
defparam cent_unit.rx0_cru_clock5_physical_mapping = "pld_cru_clk";
defparam cent_unit.rx0_cru_clock6_physical_mapping = "none";
defparam cent_unit.rx0_cru_clock7_physical_mapping = "none";
defparam cent_unit.rx0_cru_clock8_physical_mapping = "cmu_div_clk";
defparam cent_unit.rx0_logical_to_physical_mapping = -1;
defparam cent_unit.rx1_cru_clock0_physical_mapping = "iq0";
defparam cent_unit.rx1_cru_clock1_physical_mapping = "iq1";
defparam cent_unit.rx1_cru_clock2_physical_mapping = "iq2";
defparam cent_unit.rx1_cru_clock3_physical_mapping = "iq3";
defparam cent_unit.rx1_cru_clock4_physical_mapping = "iq4";
defparam cent_unit.rx1_cru_clock5_physical_mapping = "pld_cru_clk";
defparam cent_unit.rx1_cru_clock6_physical_mapping = "none";
defparam cent_unit.rx1_cru_clock7_physical_mapping = "none";
defparam cent_unit.rx1_cru_clock8_physical_mapping = "cmu_div_clk";
defparam cent_unit.rx1_logical_to_physical_mapping = -1;
defparam cent_unit.rx2_cru_clock0_physical_mapping = "iq0";
defparam cent_unit.rx2_cru_clock1_physical_mapping = "iq1";
defparam cent_unit.rx2_cru_clock2_physical_mapping = "iq2";
defparam cent_unit.rx2_cru_clock3_physical_mapping = "iq3";
defparam cent_unit.rx2_cru_clock4_physical_mapping = "iq4";
defparam cent_unit.rx2_cru_clock5_physical_mapping = "pld_cru_clk";
defparam cent_unit.rx2_cru_clock6_physical_mapping = "none";
defparam cent_unit.rx2_cru_clock7_physical_mapping = "none";
defparam cent_unit.rx2_cru_clock8_physical_mapping = "cmu_div_clk";
defparam cent_unit.rx2_logical_to_physical_mapping = -1;
defparam cent_unit.rx3_cru_clock0_physical_mapping = "iq0";
defparam cent_unit.rx3_cru_clock1_physical_mapping = "iq1";
defparam cent_unit.rx3_cru_clock2_physical_mapping = "iq2";
defparam cent_unit.rx3_cru_clock3_physical_mapping = "iq3";
defparam cent_unit.rx3_cru_clock4_physical_mapping = "iq4";
defparam cent_unit.rx3_cru_clock5_physical_mapping = "pld_cru_clk";
defparam cent_unit.rx3_cru_clock6_physical_mapping = "none";
defparam cent_unit.rx3_cru_clock7_physical_mapping = "none";
defparam cent_unit.rx3_cru_clock8_physical_mapping = "cmu_div_clk";
defparam cent_unit.rx3_logical_to_physical_mapping = -1;
defparam cent_unit.rx_dprio_width = 1200;
defparam cent_unit.tx0_logical_to_physical_mapping = -1;
defparam cent_unit.tx0_pll_fast_clk0_physical_mapping = "pll0";
defparam cent_unit.tx0_pll_fast_clk1_physical_mapping = "pll1";
defparam cent_unit.tx1_logical_to_physical_mapping = -1;
defparam cent_unit.tx1_pll_fast_clk0_physical_mapping = "pll0";
defparam cent_unit.tx1_pll_fast_clk1_physical_mapping = "pll1";
defparam cent_unit.tx2_logical_to_physical_mapping = -1;
defparam cent_unit.tx2_pll_fast_clk0_physical_mapping = "pll0";
defparam cent_unit.tx2_pll_fast_clk1_physical_mapping = "pll1";
defparam cent_unit.tx3_logical_to_physical_mapping = -1;
defparam cent_unit.tx3_pll_fast_clk0_physical_mapping = "pll0";
defparam cent_unit.tx3_pll_fast_clk1_physical_mapping = "pll1";
defparam cent_unit.tx_dprio_width = 600;
defparam cent_unit.use_deskew_fifo = "false";

gxb_reconfig reconf (
	.reconfig_clk(reconf_clk),
	.reconfig_fromgxb(reconf_fromgxb),
	.reconfig_togxb(reconf_togxb),
	.reconfig_mode_sel(3'b001),
	.reconfig_data(reconf_data),
	.reconfig_address_out(reconf_address),
	.write_all((state == CONF)),
	.busy(reconf_busy));

altsyncram config_rom (
	.clock0 (reconf_clk),
	.address_a ({sata_genreg,reconf_address}),
	.q_a (reconf_data));
defparam config_rom.init_file = "sata_config.mif";
defparam config_rom.intended_device_family = "Stratix II GX";
defparam config_rom.lpm_hint = "ENABLE_RUNTIME_MOD=NO";
defparam config_rom.lpm_type = "altsyncram";
defparam config_rom.numwords_a = 128;
defparam config_rom.operation_mode = "ROM";
defparam config_rom.widthad_a = 7;
defparam config_rom.width_a = 16;

endmodule
