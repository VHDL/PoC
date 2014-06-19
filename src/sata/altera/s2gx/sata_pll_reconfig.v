
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

module sata_pll_reconfig (
	busy,
	clock,
	counter_param,
	counter_type,
	data_in,
	pll_scanclk,
	pll_scandata,
	pll_scandone,
	pll_scanread,
	pll_scanwrite,
	reconfig,
	write_param);
	output  busy;
	input   clock;
	input   [2:0] counter_param;
	input   [3:0] counter_type;
	input   [8:0] data_in;
	output  pll_scanclk;
	output  pll_scandata;
	input   pll_scandone;
	output  pll_scanread;
	output  pll_scanwrite;
	input   reconfig;
	input   write_param;

	reg	[2:0]	counter_param_latch_reg;
	reg	[3:0]	counter_type_latch_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	idle_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_init_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_post_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_tx_data_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_tx_ena_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_tx_last_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_wait_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=HIGH"} *)
	reg	reset_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	scan_cache_same_since_reconfig_reg;
	reg	[8:0]	shift_reg;
	wire	shift_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	write_data_state;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	write_init_state;
	wire  [6:0]   cntr1_q;
	wire  [3:0]   cntr2_q;
	wire  addr_counter_done;
	wire  addr_counter_enable;
	wire  [6:0]  addr_counter_out;
	wire  addr_counter_sload;
	wire  [6:0]  addr_counter_sload_value;
	wire  [6:0]  addr_decoder_out;
	wire  [6:0]  const_scan_chain_size;
	wire  [2:0]  counter_param_latch;
	wire  [3:0]  counter_type_latch;
	wire  input_latch_enable;
	wire  power_up;
	wire  reconfig_done;
	wire  reconfig_post_done;
	wire  [6:0]  scan_cache_address;
	wire  scan_cache_in;
	wire  scan_cache_out;
	wire  scan_cache_write_enable;
	wire  sel_param_bypass;
	wire  sel_param_high_nominal_i;
	wire  sel_param_low_spread_r;
	wire  sel_param_odd_spread_bypass;
	wire  sel_param_phase_c;
	wire  sel_type_c0;
	wire  sel_type_c1;
	wire  sel_type_c2;
	wire  sel_type_c3;
	wire  sel_type_cplf;
	wire  sel_type_m;
	wire  sel_type_n;
	wire  shift_reg_load_enable;
	wire  shift_reg_serial_in;
	wire  shift_reg_serial_out;
	wire  shift_reg_shift_enable;
	wire  [7:0]  shift_reg_width_select;
	wire  timedout;
	wire  width_counter_done;
	wire  width_counter_enable;
	wire  width_counter_sload;
	wire  [3:0]  width_counter_sload_value;
	wire  [3:0]  width_decoder_out;
	wire  [7:0]  width_decoder_select;

	altsyncram cache
	( 
	.address_a(scan_cache_address),
	.clock0(clock),
	.data_a({scan_cache_in}),
	.eccstatus(),
	.q_a(scan_cache_out),
	.q_b(),
	.wren_a(scan_cache_write_enable)
	);
	defparam
		cache.init_file = "sata_pll.mif",
		cache.numwords_a = 75,
		cache.operation_mode = "SINGLE_PORT",
		cache.width_a = 1,
		cache.width_byteena_a = 1,
		cache.widthad_a = 7,
		cache.intended_device_family = "Stratix II GX",
		cache.lpm_type = "altsyncram";
	// synopsys translate_off
	initial
		counter_param_latch_reg = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		if (input_latch_enable) counter_param_latch_reg <= counter_param;
	// synopsys translate_off
	initial
		counter_type_latch_reg = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		if (input_latch_enable) counter_type_latch_reg <= counter_type;
	// synopsys translate_off
	initial
		idle_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		idle_state <= (((((idle_state & (~ write_param) & (~ reconfig))) | (write_data_state & width_counter_done)) | (reconfig_wait_state & reconfig_done)) | reset_state);
	// synopsys translate_off
	initial
		reconfig_init_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_init_state <= (idle_state & reconfig);
	// synopsys translate_off
	initial
		reconfig_post_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_post_state <= ((reconfig_tx_last_state | (reconfig_post_state & (~ reconfig_post_done))) | (reconfig_init_state & scan_cache_same_since_reconfig_reg));
	// synopsys translate_off
	initial
		reconfig_tx_data_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_tx_data_state <= (reconfig_tx_ena_state | (reconfig_tx_data_state & (~ addr_counter_done)));
	// synopsys translate_off
	initial
		reconfig_tx_ena_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_tx_ena_state <= (reconfig_init_state & (~ scan_cache_same_since_reconfig_reg));
	// synopsys translate_off
	initial
		reconfig_tx_last_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_tx_last_state <= (reconfig_tx_data_state & addr_counter_done);
	// synopsys translate_off
	initial
		reconfig_wait_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		reconfig_wait_state <= ((reconfig_post_state & reconfig_post_done) | (reconfig_wait_state & (~ reconfig_done)));
	// synopsys translate_off
	initial
		reset_state = {1{1'b1}};
	// synopsys translate_on
	always @ ( posedge clock )
		reset_state <= power_up;
	// synopsys translate_off
	initial
		scan_cache_same_since_reconfig_reg = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		scan_cache_same_since_reconfig_reg <= ((~ write_init_state) & (reconfig_post_state | scan_cache_same_since_reconfig_reg));
	// synopsys translate_off
	initial
		shift_reg = 9'b000000000;
	// synopsys translate_on
	always @ ( posedge clock )
		if (shift_reg_ena) begin
			shift_reg[0] <= ((shift_reg_load_enable & data_in[0]) | ((~ shift_reg_load_enable) & shift_reg_serial_in));
			shift_reg[1] <= ((shift_reg_load_enable & data_in[1]) | ((~ shift_reg_load_enable) & shift_reg[0]));
			shift_reg[2] <= ((shift_reg_load_enable & data_in[2]) | ((~ shift_reg_load_enable) & shift_reg[1]));
			shift_reg[3] <= ((shift_reg_load_enable & data_in[3]) | ((~ shift_reg_load_enable) & shift_reg[2]));
			shift_reg[4] <= ((shift_reg_load_enable & data_in[4]) | ((~ shift_reg_load_enable) & shift_reg[3]));
			shift_reg[5] <= ((shift_reg_load_enable & data_in[5]) | ((~ shift_reg_load_enable) & shift_reg[4]));
			shift_reg[6] <= ((shift_reg_load_enable & data_in[6]) | ((~ shift_reg_load_enable) & shift_reg[5]));
			shift_reg[7] <= ((shift_reg_load_enable & data_in[7]) | ((~ shift_reg_load_enable) & shift_reg[6]));
			shift_reg[8] <= ((shift_reg_load_enable & data_in[8]) | ((~ shift_reg_load_enable) & shift_reg[7]));
		end
	assign
		shift_reg_ena = (shift_reg_load_enable | shift_reg_shift_enable);
	// synopsys translate_off
	initial
		write_data_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		write_data_state <= (write_init_state | (write_data_state & (~ width_counter_done)));
	// synopsys translate_off
	initial
		write_init_state = 0;
	// synopsys translate_on
	always @ ( posedge clock )
		write_init_state <= (idle_state & write_param);

	lpm_counter   cntr1
	( 
	.clock(clock),
	.cnt_en(addr_counter_enable),
	.cout(),
	.data(addr_counter_sload_value),
	.eq(),
	.q(cntr1_q),
	.sload(addr_counter_sload)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.sclr(1'b0),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		cntr1.lpm_direction = "DOWN",
		cntr1.lpm_modulus = 75,
		cntr1.lpm_port_updown = "PORT_UNUSED",
		cntr1.lpm_width = 7,
		cntr1.lpm_type = "lpm_counter";

	lpm_counter   cntr2
	( 
	.clock(clock),
	.cnt_en(width_counter_enable),
	.cout(),
	.data(width_counter_sload_value),
	.eq(),
	.q(cntr2_q),
	.sload(width_counter_sload)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.sclr(1'b0),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		cntr2.lpm_direction = "DOWN",
		cntr2.lpm_port_updown = "PORT_UNUSED",
		cntr2.lpm_width = 4,
		cntr2.lpm_type = "lpm_counter";

	lpm_counter   timeout_ctr
	( 
	.clock(clock),
	.cnt_en(reconfig_wait_state),
	.cout(timedout),
	.eq(),
	.q(),
	.sclr(pll_scandone)
	);
	defparam
		timeout_ctr.lpm_direction = "UP",
		timeout_ctr.lpm_modulus = 40,
		timeout_ctr.lpm_port_updown = "PORT_UNUSED",
		timeout_ctr.lpm_width = 6,
		timeout_ctr.lpm_type = "lpm_counter";

	assign
		addr_counter_done = (((((((~ cntr1_q[0]) & (~ cntr1_q[1])) & (~ cntr1_q[2])) & (~ cntr1_q[3])) & (~ cntr1_q[4])) & (~ cntr1_q[5])) & (~ cntr1_q[6])),
		addr_counter_enable = ((( write_data_state) | reconfig_tx_data_state) | reconfig_tx_ena_state),
		addr_counter_out = cntr1_q,
		addr_counter_sload = (write_init_state | reconfig_init_state),
		addr_counter_sload_value = ((addr_decoder_out & {7{write_init_state}}) | (const_scan_chain_size & {7{reconfig_init_state}})),
		addr_decoder_out = ((((((((((((((((((((((((((((({{5{1'b0}}, {2{(sel_type_cplf & sel_param_high_nominal_i)}}} | {{3{1'b0}}, (sel_type_cplf & sel_param_low_spread_r), {2{1'b0}}, (sel_type_cplf & sel_param_low_spread_r)}) | {{3{1'b0}}, (sel_type_cplf & sel_param_phase_c), 1'b0, {2{(sel_type_cplf & sel_param_phase_c)}}}) | {{3{1'b0}}, {2{(sel_type_m & sel_param_phase_c)}}, 1'b0, (sel_type_m & sel_param_phase_c)}) | {{3{1'b0}}, {4{(sel_type_c3 & sel_param_phase_c)}}}) | {{2{1'b0}}, (sel_type_c2 & sel_param_phase_c), {3{1'b0}}, (sel_type_c2 & sel_param_phase_c)}) | {{2{1'b0}}, (sel_type_c1 & sel_param_phase_c), {2{1'b0}}, {2{(sel_type_c1 & sel_param_phase_c)}}}) | {{2{1'b0}}, (sel_type_c0 & sel_param_phase_c), 1'b0, (sel_type_c0 & sel_param_phase_c), 1'b0, (sel_type_c0 & sel_param_phase_c)}) | {{2{1'b0}}, {2{(sel_type_c0 & sel_param_high_nominal_i)}}, {2{1'b0}}, (sel_type_c0 & sel_param_high_nominal_i)}) | {{2{1'b0}}, {2{(sel_type_c0 & sel_param_bypass)}}, 1'b0, (sel_type_c0 & sel_param_bypass), 1'b0}) | {{2{1'b0}}, {4{(sel_type_c0 & sel_param_low_spread_r)}}, 1'b0}) | {{2{1'b0}}, {5{(sel_type_c0 & sel_param_odd_spread_bypass)}}}) | {1'b0, (sel_type_c1 & sel_param_high_nominal_i), {3{1'b0}}, {2{(sel_type_c1 & sel_param_high_nominal_i)}}}) | {1'b0, (sel_type_c1 & sel_param_bypass), {2{1'b0}}, (sel_type_c1 & sel_param_bypass), {2{1'b0}}}) | {1'b0, (sel_type_c1 & sel_param_low_spread_r), 1'b0, (sel_type_c1 & sel_param_low_spread_r), {3{1'b0}}}) | {1'b0, (sel_type_c1 & sel_param_odd_spread_bypass), 1'b0, (sel_type_c1 & sel_param_odd_spread_bypass), {2{1'b0}}, (sel_type_c1 & sel_param_odd_spread_bypass)}) | {1'b0, (sel_type_c2 & sel_param_high_nominal_i), 1'b0, {2{(sel_type_c2 & sel_param_high_nominal_i)}}, 1'b0, (sel_type_c2 & sel_param_high_nominal_i)}) | {1'b0, (sel_type_c2 & sel_param_bypass), 1'b0, {3{(sel_type_c2 & sel_param_bypass)}}, 1'b0}) | {1'b0, {2{(sel_type_c2 & sel_param_low_spread_r)}}, {2{1'b0}}, (sel_type_c2 & sel_param_low_spread_r), 1'b0}) | {1'b0, {2{(sel_type_c2 & sel_param_odd_spread_bypass)}}, {2{1'b0}}, {2{(sel_type_c2 & sel_param_odd_spread_bypass)}}}) | {1'b0, {2{(sel_type_c3 & sel_param_high_nominal_i)}}, 1'b0, {3{(sel_type_c3 & sel_param_high_nominal_i)}}}) | {1'b0, {3{(sel_type_c3 & sel_param_bypass)}}, {3{1'b0}}}) | {1'b0, {4{(sel_type_c3 & sel_param_low_spread_r)}}, {2{1'b0}}}) | {1'b0, {4{(sel_type_c3 & sel_param_odd_spread_bypass)}}, 1'b0, (sel_type_c3 & sel_param_odd_spread_bypass)}) | {(sel_type_m & sel_param_high_nominal_i), {5{1'b0}}, (sel_type_m & sel_param_high_nominal_i)}) | {(sel_type_m & sel_param_bypass), {4{1'b0}}, (sel_type_m & sel_param_bypass), 1'b0}) | {(sel_type_m & sel_param_low_spread_r), {3{1'b0}}, {2{(sel_type_m & sel_param_low_spread_r)}}, 1'b0}) | {(sel_type_m & sel_param_odd_spread_bypass), {3{1'b0}}, {3{(sel_type_m & sel_param_odd_spread_bypass)}}}) | {(sel_type_n & sel_param_high_nominal_i), {2{1'b0}}, (sel_type_n & sel_param_high_nominal_i), {2{1'b0}}, (sel_type_n & sel_param_high_nominal_i)}) | {(sel_type_n & sel_param_bypass), {2{1'b0}}, (sel_type_n & sel_param_bypass), 1'b0, (sel_type_n & sel_param_bypass), 1'b0}),
		busy = (~ idle_state),
		const_scan_chain_size = 7'b1001010,
		counter_param_latch = counter_param_latch_reg,
		counter_type_latch = counter_type_latch_reg,
		input_latch_enable = (idle_state & (write_param)),
		pll_scanclk = clock,
		pll_scandata = (scan_cache_out & ((reconfig_tx_data_state | reconfig_tx_last_state) | reconfig_post_state)),
		pll_scanread = (reconfig_tx_ena_state | reconfig_tx_data_state),
		pll_scanwrite = reconfig_wait_state,
		power_up = ((((((((((((((~ reset_state) & (~ idle_state))))) & (~ write_init_state)) & (~ write_data_state)))) & (~ reconfig_tx_ena_state)) & (~ reconfig_tx_data_state)) & (~ reconfig_tx_last_state)) & (~ reconfig_post_state)) & (~ reconfig_wait_state)),
		reconfig_done = (pll_scandone | timedout),
		reconfig_post_done = (~ (pll_scandone | timedout)),
		scan_cache_address = addr_counter_out,
		scan_cache_in = shift_reg_serial_out,
		scan_cache_write_enable = write_data_state,
		sel_param_bypass = (((~ counter_param_latch[0]) & (~ counter_param_latch[1])) & counter_param_latch[2]),
		sel_param_high_nominal_i = (((~ counter_param_latch[0]) & (~ counter_param_latch[1])) & (~ counter_param_latch[2])),
		sel_param_low_spread_r = ((counter_param_latch[0] & (~ counter_param_latch[1])) & (~ counter_param_latch[2])),
		sel_param_odd_spread_bypass = ((counter_param_latch[0] & (~ counter_param_latch[1])) & counter_param_latch[2]),
		sel_param_phase_c = (((~ counter_param_latch[0]) & counter_param_latch[1]) & (~ counter_param_latch[2])),
		sel_type_c0 = ((((~ counter_type_latch[0]) & (~ counter_type_latch[1])) & counter_type_latch[2]) & (~ counter_type_latch[3])),
		sel_type_c1 = (((counter_type_latch[0] & (~ counter_type_latch[1])) & counter_type_latch[2]) & (~ counter_type_latch[3])),
		sel_type_c2 = ((((~ counter_type_latch[0]) & counter_type_latch[1]) & counter_type_latch[2]) & (~ counter_type_latch[3])),
		sel_type_c3 = (((counter_type_latch[0] & counter_type_latch[1]) & counter_type_latch[2]) & (~ counter_type_latch[3])),
		sel_type_cplf = ((((~ counter_type_latch[0]) & counter_type_latch[1]) & (~ counter_type_latch[2])) & (~ counter_type_latch[3])),
		sel_type_m = (((counter_type_latch[0] & (~ counter_type_latch[1])) & (~ counter_type_latch[2])) & (~ counter_type_latch[3])),
		sel_type_n = ((((~ counter_type_latch[0]) & (~ counter_type_latch[1])) & (~ counter_type_latch[2])) & (~ counter_type_latch[3])),
		shift_reg_load_enable = (idle_state & write_param),
		shift_reg_serial_in = scan_cache_out,
		shift_reg_serial_out = ((((((((shift_reg[0:0] & shift_reg_width_select[0]) | (shift_reg[3:3] & shift_reg_width_select[1])) | (shift_reg[8:8] & shift_reg_width_select[2])) | (shift_reg[1:1] & shift_reg_width_select[3])) | (shift_reg[5:5] & shift_reg_width_select[4])) | (shift_reg[7:7] & shift_reg_width_select[5])) | (shift_reg[2:2] & shift_reg_width_select[6])) | (shift_reg[4:4] & shift_reg_width_select[7])),
		shift_reg_shift_enable = write_data_state,
		shift_reg_width_select = width_decoder_select,
		width_counter_done = ((((~ cntr2_q[0]) & (~ cntr2_q[1])) & (~ cntr2_q[2])) & (~ cntr2_q[3])),
		width_counter_enable = write_data_state,
		width_counter_sload = write_init_state,
		width_counter_sload_value = width_decoder_out,
		width_decoder_out = ((({4{1'b0}} | {{2{1'b0}}, {2{width_decoder_select[1]}}}) | {{3{1'b0}}, width_decoder_select[3]}) | {1'b0, width_decoder_select[4], 1'b0, width_decoder_select[4]}),
		width_decoder_select = {{3{1'b0}}, (sel_type_cplf & sel_param_low_spread_r), (((((((sel_type_cplf & sel_param_phase_c) | (sel_type_m & sel_param_phase_c)) | (sel_type_c3 & sel_param_phase_c)) | (sel_type_c2 & sel_param_phase_c)) | (sel_type_c1 & sel_param_phase_c)) | (sel_type_c0 & sel_param_phase_c)) | (sel_type_n & sel_param_high_nominal_i)), 1'b0, (((((((((((sel_type_cplf & sel_param_high_nominal_i) | (sel_type_c0 & sel_param_high_nominal_i)) | (sel_type_c0 & sel_param_low_spread_r)) | (sel_type_c1 & sel_param_high_nominal_i)) | (sel_type_c1 & sel_param_low_spread_r)) | (sel_type_c2 & sel_param_high_nominal_i)) | (sel_type_c2 & sel_param_low_spread_r)) | (sel_type_c3 & sel_param_high_nominal_i)) | (sel_type_c3 & sel_param_low_spread_r)) | (sel_type_m & sel_param_high_nominal_i)) | (sel_type_m & sel_param_low_spread_r)), (((((((((((sel_type_c0 & sel_param_bypass) | (sel_type_c0 & sel_param_odd_spread_bypass)) | (sel_type_c1 & sel_param_bypass)) | (sel_type_c1 & sel_param_odd_spread_bypass)) | (sel_type_c2 & sel_param_bypass)) | (sel_type_c2 & sel_param_odd_spread_bypass)) | (sel_type_c3 & sel_param_bypass)) | (sel_type_c3 & sel_param_odd_spread_bypass)) | (sel_type_m & sel_param_bypass)) | (sel_type_m & sel_param_odd_spread_bypass)) | (sel_type_n & sel_param_bypass))};
endmodule // sata_pll_reconfig
