
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


//synthesis_resources = lpm_compare 3 lpm_counter 1 lpm_decode 1 lut 1 reg 102 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"{-to addr_shift_reg[31]} DPRIO_INTERFACE_REG=ON;{-to wr_out_data_shift_reg[31]} DPRIO_INTERFACE_REG=ON;{-to rd_out_data_shift_reg[13]} DPRIO_INTERFACE_REG=ON;{-to in_data_shift_reg[0]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[0]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[1]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[2]} DPRIO_INTERFACE_REG=ON"} *)
module  gxb_reconfig_dprio
	( 
	address,
	busy,
	datain,
	dataout,
	dpclk,
	dpriodisable,
	dprioin,
	dprioload,
	dprioout,
	quad_address,
	rden,
	reset,
	status_out,
	wren,
	wren_data) /* synthesis synthesis_clearbox=2 */;
	input   [15:0]  address;
	output   busy;
	input   [15:0]  datain;
	output   [15:0]  dataout;
	input   dpclk;
	output   dpriodisable;
	output   dprioin;
	output   dprioload;
	input   dprioout;
	input   [8:0]  quad_address;
	input   rden;
	input   reset;
	output   [3:0]  status_out;
	input   wren;
	input   wren_data;

	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[31:0]	addr_shift_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	in_data_shift_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	rd_out_data_shift_reg;
	wire	[2:0]	wire_startup_cntr_d;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	startup_cntr;
	wire	[2:0]	wire_startup_cntr_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	state_mc_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[31:0]	wr_out_data_shift_reg;
	wire  wire_pre_amble_cmpr_aeb;
	wire  wire_pre_amble_cmpr_agb;
	wire  wire_rd_data_output_cmpr_ageb;
	wire  wire_rd_data_output_cmpr_alb;
	wire  wire_state_mc_cmpr_aeb;
	wire  [5:0]   wire_state_mc_counter_q;
	wire  [7:0]   wire_state_mc_decode_eq;
	wire	wire_dprioin_mux_dataout;
	wire  busy_state;
	wire  idle_state;
	wire  rd_addr_done;
	wire  rd_addr_state;
	wire  rd_data_done;
	wire  rd_data_input_state;
	wire  rd_data_output_state;
	wire  rd_data_state;
	wire rdinc;
	wire  read_state;
	wire  s0_to_0;
	wire  s0_to_1;
	wire  s1_to_0;
	wire  s1_to_1;
	wire  s2_to_0;
	wire  s2_to_1;
	wire  startup_done;
	wire  startup_idle;
	wire  wr_addr_done;
	wire  wr_addr_state;
	wire  wr_data_done;
	wire  wr_data_state;
	wire  write_state;

	// synopsys translate_off
	initial
		addr_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk or  posedge reset)
		if (reset == 1'b1) addr_shift_reg <= 32'b0;
		else
			if (wire_pre_amble_cmpr_aeb == 1'b1) addr_shift_reg <= {{2{{2{1'b0}}}}, 1'b0, quad_address[8:0], 2'b10, address};
			else  addr_shift_reg <= {addr_shift_reg[30:0], 1'b0};
	// synopsys translate_off
	initial
		in_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk or  posedge reset)
		if (reset == 1'b1) in_data_shift_reg <= 16'b0;
		else if  (rd_data_input_state == 1'b1)   in_data_shift_reg <= {in_data_shift_reg[14:0], dprioout};
	// synopsys translate_off
	initial
		rd_out_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk or  posedge reset)
		if (reset == 1'b1) rd_out_data_shift_reg <= 16'b0;
		else
			if (wire_pre_amble_cmpr_aeb == 1'b1) rd_out_data_shift_reg <= {{2{1'b0}}, {2{1'b1}}, 1'b0, quad_address, 2'b10};
			else  rd_out_data_shift_reg <= {rd_out_data_shift_reg[14:0], 1'b0};
	// synopsys translate_off
	initial
		startup_cntr[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge dpclk)
		if (wire_startup_cntr_ena[0:0] == 1'b1) 
			if (reset == 1'b1) startup_cntr[0:0] <= 1'b0;
			else  startup_cntr[0:0] <= wire_startup_cntr_d[0:0];
	// synopsys translate_off
	initial
		startup_cntr[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge dpclk)
		if (wire_startup_cntr_ena[1:1] == 1'b1) 
			if (reset == 1'b1) startup_cntr[1:1] <= 1'b0;
			else  startup_cntr[1:1] <= wire_startup_cntr_d[1:1];
	// synopsys translate_off
	initial
		startup_cntr[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge dpclk)
		if (wire_startup_cntr_ena[2:2] == 1'b1) 
			if (reset == 1'b1) startup_cntr[2:2] <= 1'b0;
			else  startup_cntr[2:2] <= wire_startup_cntr_d[2:2];
	assign
		wire_startup_cntr_d = {(startup_cntr[2] ^ (startup_cntr[1] & startup_cntr[0])), (startup_cntr[0] ^ startup_cntr[1]), (~ startup_cntr[0])};
	assign
		wire_startup_cntr_ena = {3{((((rden | wren) | rdinc) | (~ startup_idle)) & (~ startup_done))}};
	// synopsys translate_off
	initial
		state_mc_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk or  posedge reset)
		if (reset == 1'b1) state_mc_reg <= 3'b0;
		else  state_mc_reg <= {(s2_to_1 | (((~ s2_to_0) & (~ s2_to_1)) & state_mc_reg[2])), (s1_to_1 | (((~ s1_to_0) & (~ s1_to_1)) & state_mc_reg[1])), (s0_to_1 | (((~ s0_to_0) & (~ s0_to_1)) & state_mc_reg[0]))};
	// synopsys translate_off
	initial
		wr_out_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk or  posedge reset)
		if (reset == 1'b1) wr_out_data_shift_reg <= 32'b0;
		else
			if (wire_pre_amble_cmpr_aeb == 1'b1) wr_out_data_shift_reg <= {{2{1'b0}}, 2'b01, 1'b0, quad_address[8:0], 2'b10, datain};
			else  wr_out_data_shift_reg <= {wr_out_data_shift_reg[30:0], 1'b0};
	lpm_compare   pre_amble_cmpr
	( 
	.aeb(wire_pre_amble_cmpr_aeb),
	.agb(wire_pre_amble_cmpr_agb),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(wire_state_mc_counter_q),
	.datab(6'b011111)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		pre_amble_cmpr.lpm_width = 6,
		pre_amble_cmpr.lpm_type = "lpm_compare";
	lpm_compare   rd_data_output_cmpr
	( 
	.aeb(),
	.agb(),
	.ageb(wire_rd_data_output_cmpr_ageb),
	.alb(wire_rd_data_output_cmpr_alb),
	.aleb(),
	.aneb(),
	.dataa(wire_state_mc_counter_q),
	.datab(6'b110000)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		rd_data_output_cmpr.lpm_width = 6,
		rd_data_output_cmpr.lpm_type = "lpm_compare";
	lpm_compare   state_mc_cmpr
	( 
	.aeb(wire_state_mc_cmpr_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(wire_state_mc_counter_q),
	.datab({6{1'b1}})
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		state_mc_cmpr.lpm_width = 6,
		state_mc_cmpr.lpm_type = "lpm_compare";
	lpm_counter   state_mc_counter
	( 
	.clock(dpclk),
	.cnt_en((write_state | read_state)),
	.cout(),
	.eq(),
	.q(wire_state_mc_counter_q),
	.sclr(reset)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.data({6{1'b0}}),
	.sload(1'b0),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		state_mc_counter.lpm_port_updown = "PORT_UNUSED",
		state_mc_counter.lpm_width = 6,
		state_mc_counter.lpm_type = "lpm_counter";
	lpm_decode   state_mc_decode
	( 
	.data(state_mc_reg),
	.eq(wire_state_mc_decode_eq)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0),
	.enable(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		state_mc_decode.lpm_decodes = 8,
		state_mc_decode.lpm_width = 3,
		state_mc_decode.lpm_type = "lpm_decode";
	or(wire_dprioin_mux_dataout, ((((((wr_addr_state | rd_addr_state) & addr_shift_reg[31]) & wire_pre_amble_cmpr_agb) | ((~ wire_pre_amble_cmpr_agb) & (wr_addr_state | rd_addr_state))) | (((wr_data_state & wr_out_data_shift_reg[31]) & wire_pre_amble_cmpr_agb) | ((~ wire_pre_amble_cmpr_agb) & wr_data_state))) | (((rd_data_output_state & rd_out_data_shift_reg[15]) & wire_pre_amble_cmpr_agb) | ((~ wire_pre_amble_cmpr_agb) & rd_data_output_state))), ~(((write_state | rd_addr_state) | rd_data_output_state)));
	assign
		busy = busy_state,
		busy_state = (write_state | read_state),
		dataout = in_data_shift_reg,
		dpriodisable = (~ (startup_cntr[2] & (startup_cntr[0] | startup_cntr[1]))),
		dprioin = wire_dprioin_mux_dataout,
		dprioload = (~ ((startup_cntr[0] ^ startup_cntr[1]) & (~ startup_cntr[2]))),
		idle_state = wire_state_mc_decode_eq[0],
		rd_addr_done = (rd_addr_state & wire_state_mc_cmpr_aeb),
		rd_addr_state = (wire_state_mc_decode_eq[5] & startup_done),
		rd_data_done = (rd_data_state & wire_state_mc_cmpr_aeb),
		rd_data_input_state = (wire_rd_data_output_cmpr_ageb & rd_data_state),
		rd_data_output_state = (wire_rd_data_output_cmpr_alb & rd_data_state),
		rd_data_state = (wire_state_mc_decode_eq[7] & startup_done),
		rdinc = 1'b0,
		read_state = (rd_addr_state | rd_data_state),
		s0_to_0 = ((wr_data_state & wr_data_done) | (rd_data_state & rd_data_done)),
		s0_to_1 = (((idle_state & (wren | ((~ wren) & ((rden | rdinc) | wren_data)))) | (wr_addr_state & wr_addr_done)) | (rd_addr_state & rd_addr_done)),
		s1_to_0 = (((wr_data_state & wr_data_done) | (rd_data_state & rd_data_done)) | (idle_state & (wren | (((~ wren) & (~ wren_data)) & rden)))),
		s1_to_1 = (((idle_state & ((~ wren) & (rdinc | wren_data))) | (wr_addr_state & wr_addr_done)) | (rd_addr_state & rd_addr_done)),
		s2_to_0 = ((((wr_addr_state & wr_addr_done) | (wr_data_state & wr_data_done)) | (rd_data_state & rd_data_done)) | (idle_state & (wren | wren_data))),
		s2_to_1 = ((idle_state & (((~ wren) & (~ wren_data)) & (rdinc | rden))) | (rd_addr_state & rd_addr_done)),
		startup_done = ((startup_cntr[2] & (~ startup_cntr[0])) & startup_cntr[1]),
		startup_idle = ((~ startup_cntr[0]) & (~ (startup_cntr[2] ^ startup_cntr[1]))),
		status_out = {rd_data_done, rd_addr_done, wr_data_done, wr_addr_done},
		wr_addr_done = (wr_addr_state & wire_state_mc_cmpr_aeb),
		wr_addr_state = (wire_state_mc_decode_eq[1] & startup_done),
		wr_data_done = (wr_data_state & wire_state_mc_cmpr_aeb),
		wr_data_state = (wire_state_mc_decode_eq[3] & startup_done),
		write_state = (wr_addr_state | wr_data_state);
endmodule //gxb_reconfig_dprio


//lpm_mux CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" LPM_SIZE=10 LPM_WIDTH=6 LPM_WIDTHS=4 data result sel
//VERSION_BEGIN 12.1 cbx_lpm_mux 2012:11:07:18:03:20:SJ cbx_mgl 2012:11:07:18:50:05:SJ  VERSION_END

//synthesis_resources = lut 30 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  gxb_reconfig_mux_r7a
	( 
	data,
	result,
	sel) ;
	input   [59:0]  data;
	output   [5:0]  result;
	input   [3:0]  sel;

	wire	wire_l1_w0_n0_mux_dataout;
	wire	wire_l1_w0_n1_mux_dataout;
	wire	wire_l1_w0_n2_mux_dataout;
	wire	wire_l1_w0_n3_mux_dataout;
	wire	wire_l1_w0_n4_mux_dataout;
	wire	wire_l1_w0_n5_mux_dataout;
	wire	wire_l1_w0_n6_mux_dataout;
	wire	wire_l1_w0_n7_mux_dataout;
	wire	wire_l1_w1_n0_mux_dataout;
	wire	wire_l1_w1_n1_mux_dataout;
	wire	wire_l1_w1_n2_mux_dataout;
	wire	wire_l1_w1_n3_mux_dataout;
	wire	wire_l1_w1_n4_mux_dataout;
	wire	wire_l1_w1_n5_mux_dataout;
	wire	wire_l1_w1_n6_mux_dataout;
	wire	wire_l1_w1_n7_mux_dataout;
	wire	wire_l1_w2_n0_mux_dataout;
	wire	wire_l1_w2_n1_mux_dataout;
	wire	wire_l1_w2_n2_mux_dataout;
	wire	wire_l1_w2_n3_mux_dataout;
	wire	wire_l1_w2_n4_mux_dataout;
	wire	wire_l1_w2_n5_mux_dataout;
	wire	wire_l1_w2_n6_mux_dataout;
	wire	wire_l1_w2_n7_mux_dataout;
	wire	wire_l1_w3_n0_mux_dataout;
	wire	wire_l1_w3_n1_mux_dataout;
	wire	wire_l1_w3_n2_mux_dataout;
	wire	wire_l1_w3_n3_mux_dataout;
	wire	wire_l1_w3_n4_mux_dataout;
	wire	wire_l1_w3_n5_mux_dataout;
	wire	wire_l1_w3_n6_mux_dataout;
	wire	wire_l1_w3_n7_mux_dataout;
	wire	wire_l1_w4_n0_mux_dataout;
	wire	wire_l1_w4_n1_mux_dataout;
	wire	wire_l1_w4_n2_mux_dataout;
	wire	wire_l1_w4_n3_mux_dataout;
	wire	wire_l1_w4_n4_mux_dataout;
	wire	wire_l1_w4_n5_mux_dataout;
	wire	wire_l1_w4_n6_mux_dataout;
	wire	wire_l1_w4_n7_mux_dataout;
	wire	wire_l1_w5_n0_mux_dataout;
	wire	wire_l1_w5_n1_mux_dataout;
	wire	wire_l1_w5_n2_mux_dataout;
	wire	wire_l1_w5_n3_mux_dataout;
	wire	wire_l1_w5_n4_mux_dataout;
	wire	wire_l1_w5_n5_mux_dataout;
	wire	wire_l1_w5_n6_mux_dataout;
	wire	wire_l1_w5_n7_mux_dataout;
	wire	wire_l2_w0_n0_mux_dataout;
	wire	wire_l2_w0_n1_mux_dataout;
	wire	wire_l2_w0_n2_mux_dataout;
	wire	wire_l2_w0_n3_mux_dataout;
	wire	wire_l2_w1_n0_mux_dataout;
	wire	wire_l2_w1_n1_mux_dataout;
	wire	wire_l2_w1_n2_mux_dataout;
	wire	wire_l2_w1_n3_mux_dataout;
	wire	wire_l2_w2_n0_mux_dataout;
	wire	wire_l2_w2_n1_mux_dataout;
	wire	wire_l2_w2_n2_mux_dataout;
	wire	wire_l2_w2_n3_mux_dataout;
	wire	wire_l2_w3_n0_mux_dataout;
	wire	wire_l2_w3_n1_mux_dataout;
	wire	wire_l2_w3_n2_mux_dataout;
	wire	wire_l2_w3_n3_mux_dataout;
	wire	wire_l2_w4_n0_mux_dataout;
	wire	wire_l2_w4_n1_mux_dataout;
	wire	wire_l2_w4_n2_mux_dataout;
	wire	wire_l2_w4_n3_mux_dataout;
	wire	wire_l2_w5_n0_mux_dataout;
	wire	wire_l2_w5_n1_mux_dataout;
	wire	wire_l2_w5_n2_mux_dataout;
	wire	wire_l2_w5_n3_mux_dataout;
	wire	wire_l3_w0_n0_mux_dataout;
	wire	wire_l3_w0_n1_mux_dataout;
	wire	wire_l3_w1_n0_mux_dataout;
	wire	wire_l3_w1_n1_mux_dataout;
	wire	wire_l3_w2_n0_mux_dataout;
	wire	wire_l3_w2_n1_mux_dataout;
	wire	wire_l3_w3_n0_mux_dataout;
	wire	wire_l3_w3_n1_mux_dataout;
	wire	wire_l3_w4_n0_mux_dataout;
	wire	wire_l3_w4_n1_mux_dataout;
	wire	wire_l3_w5_n0_mux_dataout;
	wire	wire_l3_w5_n1_mux_dataout;
	wire	wire_l4_w0_n0_mux_dataout;
	wire	wire_l4_w1_n0_mux_dataout;
	wire	wire_l4_w2_n0_mux_dataout;
	wire	wire_l4_w3_n0_mux_dataout;
	wire	wire_l4_w4_n0_mux_dataout;
	wire	wire_l4_w5_n0_mux_dataout;
	wire  [179:0]  data_wire;
	wire  [5:0]  result_wire_ext;
	wire  [15:0]  sel_wire;

	assign		wire_l1_w0_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[6] : data_wire[0];
	assign		wire_l1_w0_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[18] : data_wire[12];
	assign		wire_l1_w0_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[30] : data_wire[24];
	assign		wire_l1_w0_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[42] : data_wire[36];
	assign		wire_l1_w0_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[54] : data_wire[48];
	assign		wire_l1_w0_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[66] : data_wire[60];
	assign		wire_l1_w0_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[78] : data_wire[72];
	assign		wire_l1_w0_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[90] : data_wire[84];
	assign		wire_l1_w1_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[7] : data_wire[1];
	assign		wire_l1_w1_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[19] : data_wire[13];
	assign		wire_l1_w1_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[31] : data_wire[25];
	assign		wire_l1_w1_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[43] : data_wire[37];
	assign		wire_l1_w1_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[55] : data_wire[49];
	assign		wire_l1_w1_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[67] : data_wire[61];
	assign		wire_l1_w1_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[79] : data_wire[73];
	assign		wire_l1_w1_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[91] : data_wire[85];
	assign		wire_l1_w2_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[8] : data_wire[2];
	assign		wire_l1_w2_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[20] : data_wire[14];
	assign		wire_l1_w2_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[32] : data_wire[26];
	assign		wire_l1_w2_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[44] : data_wire[38];
	assign		wire_l1_w2_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[56] : data_wire[50];
	assign		wire_l1_w2_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[68] : data_wire[62];
	assign		wire_l1_w2_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[80] : data_wire[74];
	assign		wire_l1_w2_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[92] : data_wire[86];
	assign		wire_l1_w3_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[9] : data_wire[3];
	assign		wire_l1_w3_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[21] : data_wire[15];
	assign		wire_l1_w3_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[33] : data_wire[27];
	assign		wire_l1_w3_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[45] : data_wire[39];
	assign		wire_l1_w3_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[57] : data_wire[51];
	assign		wire_l1_w3_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[69] : data_wire[63];
	assign		wire_l1_w3_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[81] : data_wire[75];
	assign		wire_l1_w3_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[93] : data_wire[87];
	assign		wire_l1_w4_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[10] : data_wire[4];
	assign		wire_l1_w4_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[22] : data_wire[16];
	assign		wire_l1_w4_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[34] : data_wire[28];
	assign		wire_l1_w4_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[46] : data_wire[40];
	assign		wire_l1_w4_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[58] : data_wire[52];
	assign		wire_l1_w4_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[70] : data_wire[64];
	assign		wire_l1_w4_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[82] : data_wire[76];
	assign		wire_l1_w4_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[94] : data_wire[88];
	assign		wire_l1_w5_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[11] : data_wire[5];
	assign		wire_l1_w5_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[23] : data_wire[17];
	assign		wire_l1_w5_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[35] : data_wire[29];
	assign		wire_l1_w5_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[47] : data_wire[41];
	assign		wire_l1_w5_n4_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[59] : data_wire[53];
	assign		wire_l1_w5_n5_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[71] : data_wire[65];
	assign		wire_l1_w5_n6_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[83] : data_wire[77];
	assign		wire_l1_w5_n7_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[95] : data_wire[89];
	assign		wire_l2_w0_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[97] : data_wire[96];
	assign		wire_l2_w0_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[99] : data_wire[98];
	assign		wire_l2_w0_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[101] : data_wire[100];
	assign		wire_l2_w0_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[103] : data_wire[102];
	assign		wire_l2_w1_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[105] : data_wire[104];
	assign		wire_l2_w1_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[107] : data_wire[106];
	assign		wire_l2_w1_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[109] : data_wire[108];
	assign		wire_l2_w1_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[111] : data_wire[110];
	assign		wire_l2_w2_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[113] : data_wire[112];
	assign		wire_l2_w2_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[115] : data_wire[114];
	assign		wire_l2_w2_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[117] : data_wire[116];
	assign		wire_l2_w2_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[119] : data_wire[118];
	assign		wire_l2_w3_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[121] : data_wire[120];
	assign		wire_l2_w3_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[123] : data_wire[122];
	assign		wire_l2_w3_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[125] : data_wire[124];
	assign		wire_l2_w3_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[127] : data_wire[126];
	assign		wire_l2_w4_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[129] : data_wire[128];
	assign		wire_l2_w4_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[131] : data_wire[130];
	assign		wire_l2_w4_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[133] : data_wire[132];
	assign		wire_l2_w4_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[135] : data_wire[134];
	assign		wire_l2_w5_n0_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[137] : data_wire[136];
	assign		wire_l2_w5_n1_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[139] : data_wire[138];
	assign		wire_l2_w5_n2_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[141] : data_wire[140];
	assign		wire_l2_w5_n3_mux_dataout = (sel_wire[5] === 1'b1) ? data_wire[143] : data_wire[142];
	assign		wire_l3_w0_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[145] : data_wire[144];
	assign		wire_l3_w0_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[147] : data_wire[146];
	assign		wire_l3_w1_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[149] : data_wire[148];
	assign		wire_l3_w1_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[151] : data_wire[150];
	assign		wire_l3_w2_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[153] : data_wire[152];
	assign		wire_l3_w2_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[155] : data_wire[154];
	assign		wire_l3_w3_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[157] : data_wire[156];
	assign		wire_l3_w3_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[159] : data_wire[158];
	assign		wire_l3_w4_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[161] : data_wire[160];
	assign		wire_l3_w4_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[163] : data_wire[162];
	assign		wire_l3_w5_n0_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[165] : data_wire[164];
	assign		wire_l3_w5_n1_mux_dataout = (sel_wire[10] === 1'b1) ? data_wire[167] : data_wire[166];
	assign		wire_l4_w0_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[169] : data_wire[168];
	assign		wire_l4_w1_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[171] : data_wire[170];
	assign		wire_l4_w2_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[173] : data_wire[172];
	assign		wire_l4_w3_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[175] : data_wire[174];
	assign		wire_l4_w4_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[177] : data_wire[176];
	assign		wire_l4_w5_n0_mux_dataout = (sel_wire[15] === 1'b1) ? data_wire[179] : data_wire[178];
	assign
		data_wire = {wire_l3_w5_n1_mux_dataout, wire_l3_w5_n0_mux_dataout, wire_l3_w4_n1_mux_dataout, wire_l3_w4_n0_mux_dataout, wire_l3_w3_n1_mux_dataout, wire_l3_w3_n0_mux_dataout, wire_l3_w2_n1_mux_dataout, wire_l3_w2_n0_mux_dataout, wire_l3_w1_n1_mux_dataout, wire_l3_w1_n0_mux_dataout, wire_l3_w0_n1_mux_dataout, wire_l3_w0_n0_mux_dataout, wire_l2_w5_n3_mux_dataout, wire_l2_w5_n2_mux_dataout, wire_l2_w5_n1_mux_dataout, wire_l2_w5_n0_mux_dataout, wire_l2_w4_n3_mux_dataout, wire_l2_w4_n2_mux_dataout, wire_l2_w4_n1_mux_dataout, wire_l2_w4_n0_mux_dataout, wire_l2_w3_n3_mux_dataout, wire_l2_w3_n2_mux_dataout, wire_l2_w3_n1_mux_dataout, wire_l2_w3_n0_mux_dataout, wire_l2_w2_n3_mux_dataout, wire_l2_w2_n2_mux_dataout, wire_l2_w2_n1_mux_dataout, wire_l2_w2_n0_mux_dataout, wire_l2_w1_n3_mux_dataout, wire_l2_w1_n2_mux_dataout, wire_l2_w1_n1_mux_dataout, wire_l2_w1_n0_mux_dataout, wire_l2_w0_n3_mux_dataout, wire_l2_w0_n2_mux_dataout, wire_l2_w0_n1_mux_dataout, wire_l2_w0_n0_mux_dataout, wire_l1_w5_n7_mux_dataout, wire_l1_w5_n6_mux_dataout, wire_l1_w5_n5_mux_dataout, wire_l1_w5_n4_mux_dataout, wire_l1_w5_n3_mux_dataout, wire_l1_w5_n2_mux_dataout, wire_l1_w5_n1_mux_dataout, wire_l1_w5_n0_mux_dataout, wire_l1_w4_n7_mux_dataout, wire_l1_w4_n6_mux_dataout, wire_l1_w4_n5_mux_dataout, wire_l1_w4_n4_mux_dataout, wire_l1_w4_n3_mux_dataout, wire_l1_w4_n2_mux_dataout, wire_l1_w4_n1_mux_dataout, wire_l1_w4_n0_mux_dataout, wire_l1_w3_n7_mux_dataout, wire_l1_w3_n6_mux_dataout, wire_l1_w3_n5_mux_dataout, wire_l1_w3_n4_mux_dataout, wire_l1_w3_n3_mux_dataout, wire_l1_w3_n2_mux_dataout, wire_l1_w3_n1_mux_dataout, wire_l1_w3_n0_mux_dataout, wire_l1_w2_n7_mux_dataout, wire_l1_w2_n6_mux_dataout, wire_l1_w2_n5_mux_dataout, wire_l1_w2_n4_mux_dataout, wire_l1_w2_n3_mux_dataout, wire_l1_w2_n2_mux_dataout, wire_l1_w2_n1_mux_dataout, wire_l1_w2_n0_mux_dataout, wire_l1_w1_n7_mux_dataout, wire_l1_w1_n6_mux_dataout, wire_l1_w1_n5_mux_dataout, wire_l1_w1_n4_mux_dataout, wire_l1_w1_n3_mux_dataout, wire_l1_w1_n2_mux_dataout, wire_l1_w1_n1_mux_dataout, wire_l1_w1_n0_mux_dataout
, wire_l1_w0_n7_mux_dataout, wire_l1_w0_n6_mux_dataout, wire_l1_w0_n5_mux_dataout, wire_l1_w0_n4_mux_dataout, wire_l1_w0_n3_mux_dataout, wire_l1_w0_n2_mux_dataout, wire_l1_w0_n1_mux_dataout, wire_l1_w0_n0_mux_dataout, {36{1'b0}}, data},
		result = result_wire_ext,
		result_wire_ext = {wire_l4_w5_n0_mux_dataout, wire_l4_w4_n0_mux_dataout, wire_l4_w3_n0_mux_dataout, wire_l4_w2_n0_mux_dataout, wire_l4_w1_n0_mux_dataout, wire_l4_w0_n0_mux_dataout},
		sel_wire = {sel[3], {4{1'b0}}, sel[2], {4{1'b0}}, sel[1], {4{1'b0}}, sel[0]};
endmodule //gxb_reconfig_mux_r7a


//lpm_mux CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" LPM_SIZE=3 LPM_WIDTH=5 LPM_WIDTHS=2 data result sel
//VERSION_BEGIN 12.1 cbx_lpm_mux 2012:11:07:18:03:20:SJ cbx_mgl 2012:11:07:18:50:05:SJ  VERSION_END

//synthesis_resources = lut 10 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  gxb_reconfig_mux_a6a
	( 
	data,
	result,
	sel) ;
	input   [14:0]  data;
	output   [4:0]  result;
	input   [1:0]  sel;

	wire  [4:0]  data0_wire;
	wire  [4:0]  data1_wire;
	wire  [4:0]  data2_wire;
	wire  [4:0]  result_node;

	assign
		data0_wire = (data[4:0] & {5{(~ sel[0])}}),
		data1_wire = (data[9:5] & {5{sel[0]}}),
		data2_wire = (data[14:10] & {5{sel[1]}}),
		result = result_node,
		result_node = (((data0_wire | data1_wire) & {5{(~ sel[1])}}) | data2_wire);
endmodule //gxb_reconfig_mux_a6a


//lpm_mux CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" LPM_SIZE=5 LPM_WIDTH=5 LPM_WIDTHS=3 data result sel
//VERSION_BEGIN 12.1 cbx_lpm_mux 2012:11:07:18:03:20:SJ cbx_mgl 2012:11:07:18:50:05:SJ  VERSION_END

//synthesis_resources = lut 12 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  gxb_reconfig_mux_d6a
	( 
	data,
	result,
	sel) ;
	input   [24:0]  data;
	output   [4:0]  result;
	input   [2:0]  sel;

	wire	wire_l1_w0_n0_mux_dataout;
	wire	wire_l1_w0_n1_mux_dataout;
	wire	wire_l1_w0_n2_mux_dataout;
	wire	wire_l1_w0_n3_mux_dataout;
	wire	wire_l1_w1_n0_mux_dataout;
	wire	wire_l1_w1_n1_mux_dataout;
	wire	wire_l1_w1_n2_mux_dataout;
	wire	wire_l1_w1_n3_mux_dataout;
	wire	wire_l1_w2_n0_mux_dataout;
	wire	wire_l1_w2_n1_mux_dataout;
	wire	wire_l1_w2_n2_mux_dataout;
	wire	wire_l1_w2_n3_mux_dataout;
	wire	wire_l1_w3_n0_mux_dataout;
	wire	wire_l1_w3_n1_mux_dataout;
	wire	wire_l1_w3_n2_mux_dataout;
	wire	wire_l1_w3_n3_mux_dataout;
	wire	wire_l1_w4_n0_mux_dataout;
	wire	wire_l1_w4_n1_mux_dataout;
	wire	wire_l1_w4_n2_mux_dataout;
	wire	wire_l1_w4_n3_mux_dataout;
	wire	wire_l2_w0_n0_mux_dataout;
	wire	wire_l2_w0_n1_mux_dataout;
	wire	wire_l2_w1_n0_mux_dataout;
	wire	wire_l2_w1_n1_mux_dataout;
	wire	wire_l2_w2_n0_mux_dataout;
	wire	wire_l2_w2_n1_mux_dataout;
	wire	wire_l2_w3_n0_mux_dataout;
	wire	wire_l2_w3_n1_mux_dataout;
	wire	wire_l2_w4_n0_mux_dataout;
	wire	wire_l2_w4_n1_mux_dataout;
	wire	wire_l3_w0_n0_mux_dataout;
	wire	wire_l3_w1_n0_mux_dataout;
	wire	wire_l3_w2_n0_mux_dataout;
	wire	wire_l3_w3_n0_mux_dataout;
	wire	wire_l3_w4_n0_mux_dataout;
	wire  [69:0]  data_wire;
	wire  [4:0]  result_wire_ext;
	wire  [8:0]  sel_wire;

	assign		wire_l1_w0_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[5] : data_wire[0];
	assign		wire_l1_w0_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[15] : data_wire[10];
	assign		wire_l1_w0_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[25] : data_wire[20];
	assign		wire_l1_w0_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[35] : data_wire[30];
	assign		wire_l1_w1_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[6] : data_wire[1];
	assign		wire_l1_w1_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[16] : data_wire[11];
	assign		wire_l1_w1_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[26] : data_wire[21];
	assign		wire_l1_w1_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[36] : data_wire[31];
	assign		wire_l1_w2_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[7] : data_wire[2];
	assign		wire_l1_w2_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[17] : data_wire[12];
	assign		wire_l1_w2_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[27] : data_wire[22];
	assign		wire_l1_w2_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[37] : data_wire[32];
	assign		wire_l1_w3_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[8] : data_wire[3];
	assign		wire_l1_w3_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[18] : data_wire[13];
	assign		wire_l1_w3_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[28] : data_wire[23];
	assign		wire_l1_w3_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[38] : data_wire[33];
	assign		wire_l1_w4_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[9] : data_wire[4];
	assign		wire_l1_w4_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[19] : data_wire[14];
	assign		wire_l1_w4_n2_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[29] : data_wire[24];
	assign		wire_l1_w4_n3_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[39] : data_wire[34];
	assign		wire_l2_w0_n0_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[41] : data_wire[40];
	assign		wire_l2_w0_n1_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[43] : data_wire[42];
	assign		wire_l2_w1_n0_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[45] : data_wire[44];
	assign		wire_l2_w1_n1_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[47] : data_wire[46];
	assign		wire_l2_w2_n0_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[49] : data_wire[48];
	assign		wire_l2_w2_n1_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[51] : data_wire[50];
	assign		wire_l2_w3_n0_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[53] : data_wire[52];
	assign		wire_l2_w3_n1_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[55] : data_wire[54];
	assign		wire_l2_w4_n0_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[57] : data_wire[56];
	assign		wire_l2_w4_n1_mux_dataout = (sel_wire[4] === 1'b1) ? data_wire[59] : data_wire[58];
	assign		wire_l3_w0_n0_mux_dataout = (sel_wire[8] === 1'b1) ? data_wire[61] : data_wire[60];
	assign		wire_l3_w1_n0_mux_dataout = (sel_wire[8] === 1'b1) ? data_wire[63] : data_wire[62];
	assign		wire_l3_w2_n0_mux_dataout = (sel_wire[8] === 1'b1) ? data_wire[65] : data_wire[64];
	assign		wire_l3_w3_n0_mux_dataout = (sel_wire[8] === 1'b1) ? data_wire[67] : data_wire[66];
	assign		wire_l3_w4_n0_mux_dataout = (sel_wire[8] === 1'b1) ? data_wire[69] : data_wire[68];
	assign
		data_wire = {wire_l2_w4_n1_mux_dataout, wire_l2_w4_n0_mux_dataout, wire_l2_w3_n1_mux_dataout, wire_l2_w3_n0_mux_dataout, wire_l2_w2_n1_mux_dataout, wire_l2_w2_n0_mux_dataout, wire_l2_w1_n1_mux_dataout, wire_l2_w1_n0_mux_dataout, wire_l2_w0_n1_mux_dataout, wire_l2_w0_n0_mux_dataout, wire_l1_w4_n3_mux_dataout, wire_l1_w4_n2_mux_dataout, wire_l1_w4_n1_mux_dataout, wire_l1_w4_n0_mux_dataout, wire_l1_w3_n3_mux_dataout, wire_l1_w3_n2_mux_dataout, wire_l1_w3_n1_mux_dataout, wire_l1_w3_n0_mux_dataout, wire_l1_w2_n3_mux_dataout, wire_l1_w2_n2_mux_dataout, wire_l1_w2_n1_mux_dataout, wire_l1_w2_n0_mux_dataout, wire_l1_w1_n3_mux_dataout, wire_l1_w1_n2_mux_dataout, wire_l1_w1_n1_mux_dataout, wire_l1_w1_n0_mux_dataout, wire_l1_w0_n3_mux_dataout, wire_l1_w0_n2_mux_dataout, wire_l1_w0_n1_mux_dataout, wire_l1_w0_n0_mux_dataout, {15{1'b0}}, data},
		result = result_wire_ext,
		result_wire_ext = {wire_l3_w4_n0_mux_dataout, wire_l3_w3_n0_mux_dataout, wire_l3_w2_n0_mux_dataout, wire_l3_w1_n0_mux_dataout, wire_l3_w0_n0_mux_dataout},
		sel_wire = {sel[2], {3{1'b0}}, sel[1], {3{1'b0}}, sel[0]};
endmodule //gxb_reconfig_mux_d6a


//lpm_mux CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" LPM_SIZE=3 LPM_WIDTH=6 LPM_WIDTHS=2 data result sel
//VERSION_BEGIN 12.1 cbx_lpm_mux 2012:11:07:18:03:20:SJ cbx_mgl 2012:11:07:18:50:05:SJ  VERSION_END

//synthesis_resources = lut 12 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  gxb_reconfig_mux_b6a
	( 
	data,
	result,
	sel) ;
	input   [17:0]  data;
	output   [5:0]  result;
	input   [1:0]  sel;

	wire  [5:0]  data0_wire;
	wire  [5:0]  data1_wire;
	wire  [5:0]  data2_wire;
	wire  [5:0]  result_node;

	assign
		data0_wire = (data[5:0] & {6{(~ sel[0])}}),
		data1_wire = (data[11:6] & {6{sel[0]}}),
		data2_wire = (data[17:12] & {6{sel[1]}}),
		result = result_node,
		result_node = (((data0_wire | data1_wire) & {6{(~ sel[1])}}) | data2_wire);
endmodule //gxb_reconfig_mux_b6a


//lpm_mux CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" LPM_SIZE=4 LPM_WIDTH=6 LPM_WIDTHS=2 data result sel
//VERSION_BEGIN 12.1 cbx_lpm_mux 2012:11:07:18:03:20:SJ cbx_mgl 2012:11:07:18:50:05:SJ  VERSION_END

//synthesis_resources = lut 6 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  gxb_reconfig_mux_c6a
	( 
	data,
	result,
	sel) ;
	input   [23:0]  data;
	output   [5:0]  result;
	input   [1:0]  sel;

	wire	wire_l1_w0_n0_mux_dataout;
	wire	wire_l1_w0_n1_mux_dataout;
	wire	wire_l1_w1_n0_mux_dataout;
	wire	wire_l1_w1_n1_mux_dataout;
	wire	wire_l1_w2_n0_mux_dataout;
	wire	wire_l1_w2_n1_mux_dataout;
	wire	wire_l1_w3_n0_mux_dataout;
	wire	wire_l1_w3_n1_mux_dataout;
	wire	wire_l1_w4_n0_mux_dataout;
	wire	wire_l1_w4_n1_mux_dataout;
	wire	wire_l1_w5_n0_mux_dataout;
	wire	wire_l1_w5_n1_mux_dataout;
	wire	wire_l2_w0_n0_mux_dataout;
	wire	wire_l2_w1_n0_mux_dataout;
	wire	wire_l2_w2_n0_mux_dataout;
	wire	wire_l2_w3_n0_mux_dataout;
	wire	wire_l2_w4_n0_mux_dataout;
	wire	wire_l2_w5_n0_mux_dataout;
	wire  [35:0]  data_wire;
	wire  [5:0]  result_wire_ext;
	wire  [3:0]  sel_wire;

	assign		wire_l1_w0_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[6] : data_wire[0];
	assign		wire_l1_w0_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[18] : data_wire[12];
	assign		wire_l1_w1_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[7] : data_wire[1];
	assign		wire_l1_w1_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[19] : data_wire[13];
	assign		wire_l1_w2_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[8] : data_wire[2];
	assign		wire_l1_w2_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[20] : data_wire[14];
	assign		wire_l1_w3_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[9] : data_wire[3];
	assign		wire_l1_w3_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[21] : data_wire[15];
	assign		wire_l1_w4_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[10] : data_wire[4];
	assign		wire_l1_w4_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[22] : data_wire[16];
	assign		wire_l1_w5_n0_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[11] : data_wire[5];
	assign		wire_l1_w5_n1_mux_dataout = (sel_wire[0] === 1'b1) ? data_wire[23] : data_wire[17];
	assign		wire_l2_w0_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[25] : data_wire[24];
	assign		wire_l2_w1_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[27] : data_wire[26];
	assign		wire_l2_w2_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[29] : data_wire[28];
	assign		wire_l2_w3_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[31] : data_wire[30];
	assign		wire_l2_w4_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[33] : data_wire[32];
	assign		wire_l2_w5_n0_mux_dataout = (sel_wire[3] === 1'b1) ? data_wire[35] : data_wire[34];
	assign
		data_wire = {wire_l1_w5_n1_mux_dataout, wire_l1_w5_n0_mux_dataout, wire_l1_w4_n1_mux_dataout, wire_l1_w4_n0_mux_dataout, wire_l1_w3_n1_mux_dataout, wire_l1_w3_n0_mux_dataout, wire_l1_w2_n1_mux_dataout, wire_l1_w2_n0_mux_dataout, wire_l1_w1_n1_mux_dataout, wire_l1_w1_n0_mux_dataout, wire_l1_w0_n1_mux_dataout, wire_l1_w0_n0_mux_dataout, data},
		result = result_wire_ext,
		result_wire_ext = {wire_l2_w5_n0_mux_dataout, wire_l2_w4_n0_mux_dataout, wire_l2_w3_n0_mux_dataout, wire_l2_w2_n0_mux_dataout, wire_l2_w1_n0_mux_dataout, wire_l2_w0_n0_mux_dataout},
		sel_wire = {sel[1], {2{1'b0}}, sel[0]};
endmodule //gxb_reconfig_mux_c6a

//synthesis_resources = alt_cal 1 lpm_add_sub 2 lpm_compare 23 lpm_counter 3 lpm_decode 2 lut 72 reg 179 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"{-to address_pres_reg[11]} DPRIO_CHANNEL_NUM=11;{-to address_pres_reg[10]} DPRIO_CHANNEL_NUM=10;{-to address_pres_reg[9]} DPRIO_CHANNEL_NUM=9;{-to address_pres_reg[8]} DPRIO_CHANNEL_NUM=8;{-to address_pres_reg[7]} DPRIO_CHANNEL_NUM=7;{-to address_pres_reg[6]} DPRIO_CHANNEL_NUM=6;{-to address_pres_reg[5]} DPRIO_CHANNEL_NUM=5;{-to address_pres_reg[4]} DPRIO_CHANNEL_NUM=4;{-to address_pres_reg[3]} DPRIO_CHANNEL_NUM=3;{-to address_pres_reg[2]} DPRIO_CHANNEL_NUM=2;{-to address_pres_reg[1]} DPRIO_CHANNEL_NUM=1;{-to address_pres_reg[0]} DPRIO_CHANNEL_NUM=0;{-to cru_num_reg[3]} DPRIO_CRUCLK_NUM=3;{-to cru_num_reg[2]} DPRIO_CRUCLK_NUM=2;{-to cru_num_reg[1]} DPRIO_CRUCLK_NUM=1;{-to cru_num_reg[0]} DPRIO_CRUCLK_NUM=0;{-to tx_pll_inclk_reg[3]} DPRIO_TX_PLL0_REFCLK_NUM=3;{-to tx_pll_inclk_reg[2]} DPRIO_TX_PLL0_REFCLK_NUM=2;{-to tx_pll_inclk_reg[1]} DPRIO_TX_PLL0_REFCLK_NUM=1;{-to tx_pll_inclk_reg[0]} DPRIO_TX_PLL0_REFCLK_NUM=0;{-to tx_cmu_sel[2]}  DPRIO_TX_PLL_NUM=2;{-to tx_cmu_sel[1]}  DPRIO_TX_PLL_NUM=1;{-to le7} IMPLEMENT_AS_CLOCK_ENABLE = ON;{-to tx_cmu_sel[0]}  DPRIO_TX_PLL_NUM=0"} *)
module  gxb_reconfig ( 
	busy,
	reconfig_address_out,
	reconfig_clk,
	reconfig_data,
	reconfig_fromgxb,
	reconfig_mode_sel,
	reconfig_togxb,
	write_all);

	output   busy;
	output   [5:0]  reconfig_address_out;
	input   reconfig_clk;
	input   [15:0]  reconfig_data;
	input   [16:0]  reconfig_fromgxb;
	input   [2:0]  reconfig_mode_sel;
	output   [3:0]  reconfig_togxb;
	input   write_all;

	wire  wire_calibration_busy;
	wire  [15:0]   wire_calibration_dprio_addr;
	wire  [15:0]   wire_calibration_dprio_dataout;
	wire  wire_calibration_dprio_rden;
	wire  wire_calibration_dprio_wren;
	wire  [8:0]   wire_calibration_quad_addr;
	wire  wire_calibration_retain_addr;
	wire  wire_dprio_busy;
	wire  [15:0]   wire_dprio_dataout;
	wire  wire_dprio_dpriodisable;
	wire  wire_dprio_dprioin;
	wire  wire_dprio_dprioload;
	wire  [3:0]   wire_dprio_status_out;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON"} *)
	reg	[11:0]	address_pres_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[3:0]	cru_num_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	delay_mif_head;
	wire	wire_delay_mif_head_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	delay_second_mif_head;
	wire	wire_delay_second_mif_head_ena;
	wire	[15:0]	wire_dprio_dataout_reg_d;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	dprio_dataout_reg;
	wire	[15:0]	wire_dprio_dataout_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	dprio_pulse_reg;
	wire	wire_dprio_pulse_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	end_mif_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	global_register_reset_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	is_bonded_global_clk_div_reg;
	wire	wire_is_bonded_global_clk_div_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	is_bonded_reconfig_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[0:0]	logical_pll_num_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	mif_stage;
	wire	wire_mif_stage_sclr;
	wire	[4:0]	wire_mif_type_reg_d;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[4:0]	mif_type_reg;
	wire	[4:0]	wire_mif_type_reg_ena;
	wire	[4:0]	wire_mif_type_reg_sclr;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	reconf_mode_sel_reg;
	wire	[2:0]	wire_reconf_mode_sel_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	reconfig_data_reg;
	wire	[15:0]	wire_reconfig_data_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	reconfig_done_reg;
	wire	wire_reconfig_done_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[0:0]	state_mc_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON; PRESERVE_FANOUT_FREE_NODE=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	tx_cmu_sel;
	wire	[3:0]	wire_tx_pll_inclk_reg_d;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[3:0]	tx_pll_inclk_reg;
	wire	[3:0]	wire_tx_pll_inclk_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	wr_addr_inc_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	wr_rd_pulse_reg;
	wire	wire_wr_rd_pulse_reg_ena;
	wire	wire_wr_rd_pulse_reg_sclr;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	wren_data_reg;
	wire	wire_wren_data_reg_ena;
	wire  wire_le7_out;
	wire  [4:0]   wire_add_sub11_result;
	wire  [5:0]   wire_add_sub12_result;
	wire  wire_dprio_addr_offset_cmpr_aeb;
	wire  wire_is_cru_idx0_aeb;
	wire  wire_is_rcxpat_chnl_en_ch_word_aeb;
	wire  wire_is_second_mif_header_address_aeb;
	wire  wire_is_special_address_aeb;
	wire  wire_is_table_33_idx_aeb;
	wire  wire_is_table_35_cmp_aeb;
	wire  wire_is_table_37_cmp_aeb;
	wire  wire_is_table_38_cmp_aeb;
	wire  wire_is_table_42_cmp_aeb;
	wire  wire_is_table_43_cmp_aeb;
	wire  wire_is_table_44_cmp_aeb;
	wire  wire_is_table_46_cmp_aeb;
	wire  wire_is_table_47_cmp_aeb;
	wire  wire_is_table_59_idx_aeb;
	wire  wire_is_table_60_idx_aeb;
	wire  wire_is_table_61_idx_aeb;
	wire  wire_is_table_75_idx_aeb;
	wire  wire_is_table_76_idx_aeb;
	wire  wire_is_table_77_idx_aeb;
	wire  [4:0]   wire_dprio_addr_offset_cnt_q;
	wire  [5:0]   wire_mif_addr_cntr_q;
	wire  [7:0]   wire_reconf_mode_dec_eq;
	wire  [5:0]   wire_central_pcs_first_word_mux_result;
	wire  [4:0]   wire_central_pcs_global_clk_div_mux_result;
	wire  [4:0]   wire_max_word_per_mif_type_result;
	wire  [5:0]   wire_mif_addr_cntr_data_mux_result;
	wire  [5:0]   wire_pll_first_word_mux_result;
	wire  [15:0]  a2gr_dprio_addr;
	wire  [15:0]  a2gr_dprio_data;
	wire  a2gr_dprio_rden;
	wire  a2gr_dprio_wren;
	wire  a2gr_dprio_wren_data;
	wire  adce_busy_state;
	wire  adce_state;
	wire  [4:0]  add_sub_datab;
	wire  add_sub_sel;
	wire  [0:0]  aeq_ch_done;
	wire  bonded_skip;
	wire  busy_state;
	wire  cal_busy;
	wire  [2:0]  cal_channel_address;
	wire  [2:0]  cal_channel_address_out;
	wire  [15:0]  cal_dprio_address;
	wire  [0:0]  cal_dprioout_wire;
	wire  [8:0]  cal_quad_address;
	wire  [3:0]  cal_testbuses;
	wire  [4:0]  cent_clk_div_plus_one;
	wire  [5:0]  central_pcs_first_word_addr;
	wire  [4:0]  central_pcs_max;
	wire  [4:0]  central_pcs_minus_one;
	wire  [4:0]  central_pcs_plus_seven;
	wire  [1:0]  channel_address;
	wire  [1:0]  channel_address_out;
	wire  clr_offset;
	wire  [4:0]  cmu_max;
	wire  [4:0]  cmu_pll_plus_three;
	wire  [15:0]  cruclk_mux_data;
	wire  delay_mif_head_out;
	wire  delay_second_mif_head_out;
	wire  dfe_busy;
	wire  diff_mif_address_busy;
	wire  diff_mif_clr_offset;
	wire  diff_mif_load_mif_header;
	wire  [4:0]  diff_mif_mif_header;
	wire  diff_mif_reconfig_addr_load;
	wire  diff_mif_reconfig_addr_ready;
	wire  diff_mif_reconfig_addr_start;
	wire  [4:0]  diff_mif_reconfig_address;
	wire  diff_mif_wr_rd_busy;
	wire  [4:0]  dprio_addr_index;
	wire  [4:0]  dprio_addr_offset_cmpr_datab;
	wire  [4:0]  dprio_addr_offset_cnt_out;
	wire  [4:0]  dprio_addr_translated_offset;
	wire  [15:0]  dprio_datain;
	wire  [15:0]  dprio_datain_64_67;
	wire  [15:0]  dprio_datain_68_6B;
	wire  [15:0]  dprio_datain_7c_7f;
	wire  [15:0]  dprio_datain_7c_7f_inv;
	wire  [15:0]  dprio_datain_preemp1t;
	wire  [15:0]  dprio_datain_vodctrl;
	wire  dprio_pulse;
	wire  dprio_wr_done;
	wire  [5:0]  duplex_pma_first_pll;
	wire  [5:0]  duplex_pma_pcs_first_pll;
	wire  en_mif_addr_cntr;
	wire  en_write_trigger;
	wire  eyemon_busy;
	wire  [5:0]  global_clk_div_addr;
	wire  [5:0]  global_clk_div_addr_offset;
	wire  [4:0]  global_clk_div_mode_offset_max;
	wire  [4:0]  global_clk_div_mode_plus_five;
	wire  global_register_reset;
	wire  header_proc;
	wire  idle_state;
	wire  internal_write_pulse;
	wire  is_adce;
	wire  is_adce_all_control;
	wire  is_adce_continuous_single_control;
	wire  is_adce_one_time_single_control;
	wire  is_adce_single_control;
	wire  is_adce_standby_single_control;
	wire  is_analog_control;
	wire  is_bonded_global_clk_div;
	wire  is_bonded_reconfig;
	wire  is_cent_clk_div;
	wire  is_central_pcs;
	wire  is_channel_reconfig;
	wire  is_cmu;
	wire  is_cruclk_addr0;
	wire  is_diff_mif;
	wire  is_do_dfe;
	wire  is_do_eyemon;
	wire  is_end_mif;
	wire  is_global_clk_div_mode;
	wire  is_illegal_reg_d;
	wire  is_illegal_reg_out;
	wire  is_mif_header;
	wire  is_mif_stage;
	wire  is_offset_end;
	wire  is_pll_address;
	wire  is_pll_reconfig;
	wire  is_pll_reset_stage;
	wire  is_pma_mif_type;
	wire  is_protected_bit;
	wire  is_rcxpat_chnl_en_ch;
	wire  is_rx_mif_type;
	wire  is_rx_pcs;
	wire  is_rx_pma;
	wire  is_second_mif_header;
	wire  is_table_33;
	wire  is_table_35;
	wire  is_table_37;
	wire  is_table_38;
	wire  is_table_42;
	wire  is_table_43;
	wire  is_table_44;
	wire  is_table_46;
	wire  is_table_47;
	wire  is_table_59;
	wire  is_table_60;
	wire  is_table_61;
	wire  is_table_75;
	wire  is_table_76;
	wire  is_table_77;
	wire  is_tier_1;
	wire  is_tier_2;
	wire  is_tx_local_div_ctrl;
	wire  is_tx_pcs;
	wire  is_tx_pma;
	wire  legal_wr_mode_type;
	wire  load_mif_header;
	wire  local_ch_dec;
	wire  [1:0]  logical_pll_sel_num;
	wire  [15:0]  merged_dprioin;
	wire  [5:0]  mif_addr_cntr_data;
	wire  mif_reconfig_done;
	wire  mif_rx_only;
	wire offset_cancellation_reset;
	wire  [5:0]  pll_first_word_addr;
	wire  [8:0]  quad_address;
	wire  [8:0]  quad_address_out;
	wire  rd_pulse;
	wire  [15:0]  read_address;
	wire  [15:0]  read_reconfig_addr;
	wire  read_state;
	wire  reconf_done_reg_out;
	wire  [15:0]  reconfig_datain;
	wire  reconfig_reset_all;
	wire  reset_addr_done;
	wire  reset_reconf_addr;
	wire  reset_system;
	wire  [4:0]  rx_pcs_max;
	wire  [4:0]  rx_pma_max;
	wire  [4:0]  rx_pma_minus_one;
	wire  rx_reconfig;
	wire  s0_to_0;
	wire  s0_to_1;
	wire  s0_to_2;
	wire  s2_to_0;
	wire start;
	wire  [0:0]  state_mc_reg_in;
	wire  [15:0]  table_33_data;
	wire  [15:0]  table_35_data;
	wire  [15:0]  table_37_data;
	wire  [15:0]  table_38_data;
	wire  [15:0]  table_42_data;
	wire  [15:0]  table_43_data;
	wire  [15:0]  table_44_data;
	wire  [15:0]  table_46_data;
	wire  [15:0]  table_47_data;
	wire  [15:0]  table_59_data;
	wire  [15:0]  table_61_data;
	wire  [15:0]  table_75_data;
	wire  [15:0]  table_76_data;
	wire  [15:0]  table_77_data;
	wire transceiver_init;
	wire  [4:0]  tx_pcs_max;
	wire  [2:0]  tx_pll_sel_wire;
	wire  [5:0]  tx_pma_first_pll;
	wire  [4:0]  tx_pma_max;
	wire  [5:0]  tx_pma_pcs_first_pll;
	wire  tx_reconfig;
	wire  wr_pulse;
	wire  [15:0]  write_address;
	wire  write_all_int;
	wire  write_done;
	wire  write_happened;
	wire  write_mif_word_done;
	wire  [15:0]  write_reconfig_addr;
	wire  write_skip;
	wire  write_state;
	wire  write_word_64_67_data_valid;
	wire  write_word_68_6B_data_valid;
	wire  write_word_7c_7f_data_valid;
	wire  write_word_7c_7f_inv_data_valid;
	wire  write_word_done;
	wire  write_word_preemp1t_data_valid;
	wire  write_word_preemp1ta_data_valid;
	wire  write_word_preemp1tb_data_valid;
	wire  write_word_vodctrl_data_valid;
	wire  write_word_vodctrla_data_valid;

	alt_cal   calibration
	( 
	.busy(wire_calibration_busy),
	.cal_error(),
	.clock(reconfig_clk),
	.dprio_addr(wire_calibration_dprio_addr),
	.dprio_busy(wire_dprio_busy),
	.dprio_datain(wire_dprio_dataout),
	.dprio_dataout(wire_calibration_dprio_dataout),
	.dprio_rden(wire_calibration_dprio_rden),
	.dprio_wren(wire_calibration_dprio_wren),
	.quad_addr(wire_calibration_quad_addr),
	.remap_addr(address_pres_reg),
	.reset((offset_cancellation_reset | reconfig_reset_all)),
	.retain_addr(wire_calibration_retain_addr),
	.start(start),
	.testbuses(cal_testbuses),
	.transceiver_init(transceiver_init));
	defparam
		calibration.channel_address_width = 0,
		calibration.number_of_channels = 1,
		calibration.sim_model_mode = "FALSE",
		calibration.lpm_type = "alt_cal";
	gxb_reconfig_dprio   dprio
	( 
	.address((({16{wire_calibration_busy}} & cal_dprio_address) | ({16{(~ wire_calibration_busy)}} & a2gr_dprio_addr))),
	.busy(wire_dprio_busy),
	.datain((({16{wire_calibration_busy}} & wire_calibration_dprio_dataout) | ({16{(~ wire_calibration_busy)}} & a2gr_dprio_data))),
	.dataout(wire_dprio_dataout),
	.dpclk(reconfig_clk),
	.dpriodisable(wire_dprio_dpriodisable),
	.dprioin(wire_dprio_dprioin),
	.dprioload(wire_dprio_dprioload),
	.dprioout(cal_dprioout_wire),
	.quad_address(quad_address_out),
	.rden(((wire_calibration_busy & wire_calibration_dprio_rden) | ((~ wire_calibration_busy) & a2gr_dprio_rden))),
	.reset(reconfig_reset_all),
	.status_out(wire_dprio_status_out),
	.wren(((wire_calibration_busy & wire_calibration_dprio_wren) | ((~ wire_calibration_busy) & a2gr_dprio_wren))),
	.wren_data(((wire_calibration_busy & wire_calibration_retain_addr) | ((~ wire_calibration_busy) & a2gr_dprio_wren_data))));
	// synopsys translate_off
	initial
		address_pres_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) address_pres_reg <= 12'b0;
		else  address_pres_reg <= {(({9{cal_busy}} & cal_quad_address) | ({9{(~ cal_busy)}} & quad_address)), ((cal_busy & cal_channel_address[2]) | ((~ cal_busy) & ((is_pll_address | is_central_pcs) | is_bonded_global_clk_div))), ((cal_busy & cal_channel_address[1]) | ((~ cal_busy) & ((((channel_address[1] | is_bonded_global_clk_div) & (~ is_pll_address)) | ((logical_pll_sel_num[1] | (is_table_59 & is_bonded_reconfig)) & is_pll_address)) | is_central_pcs))), ((cal_busy & cal_channel_address[0]) | ((~ cal_busy) & (((((channel_address[0] | is_bonded_global_clk_div) & (~ is_pll_address)) | ((logical_pll_sel_num[0] | (is_table_59 & is_bonded_reconfig)) & is_pll_address)) & (~ is_central_pcs)) | (is_table_61 & is_central_pcs))))};
	// synopsys translate_off
	initial
		cru_num_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) cru_num_reg <= 4'b0;
		else if  (load_mif_header == 1'b1)   cru_num_reg <= reconfig_data_reg[6:3];
	// synopsys translate_off
	initial
		delay_mif_head = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) delay_mif_head <= 1'b0;
		else if  (wire_delay_mif_head_ena == 1'b1)   delay_mif_head <= (is_mif_header & is_tier_1);
	assign
		wire_delay_mif_head_ena = ((((write_state & (~ reconf_done_reg_out)) & (~ write_mif_word_done)) & (~ reset_reconf_addr)) & (~ reset_system));
	// synopsys translate_off
	initial
		delay_second_mif_head = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) delay_second_mif_head <= 1'b0;
		else if  (wire_delay_second_mif_head_ena == 1'b1)   delay_second_mif_head <= (is_second_mif_header & (~ write_done));
	assign
		wire_delay_second_mif_head_ena = ((((write_state & (~ write_mif_word_done)) & (~ reset_reconf_addr)) & (~ reset_system)) & is_tier_1);
	// synopsys translate_off
	initial
		dprio_dataout_reg[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[0:0] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[0:0] == 1'b1)   dprio_dataout_reg[0:0] <= wire_dprio_dataout_reg_d[0:0];
	// synopsys translate_off
	initial
		dprio_dataout_reg[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[1:1] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[1:1] == 1'b1)   dprio_dataout_reg[1:1] <= wire_dprio_dataout_reg_d[1:1];
	// synopsys translate_off
	initial
		dprio_dataout_reg[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[2:2] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[2:2] == 1'b1)   dprio_dataout_reg[2:2] <= wire_dprio_dataout_reg_d[2:2];
	// synopsys translate_off
	initial
		dprio_dataout_reg[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[3:3] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[3:3] == 1'b1)   dprio_dataout_reg[3:3] <= wire_dprio_dataout_reg_d[3:3];
	// synopsys translate_off
	initial
		dprio_dataout_reg[4:4] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[4:4] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[4:4] == 1'b1)   dprio_dataout_reg[4:4] <= wire_dprio_dataout_reg_d[4:4];
	// synopsys translate_off
	initial
		dprio_dataout_reg[5:5] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[5:5] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[5:5] == 1'b1)   dprio_dataout_reg[5:5] <= wire_dprio_dataout_reg_d[5:5];
	// synopsys translate_off
	initial
		dprio_dataout_reg[6:6] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[6:6] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[6:6] == 1'b1)   dprio_dataout_reg[6:6] <= wire_dprio_dataout_reg_d[6:6];
	// synopsys translate_off
	initial
		dprio_dataout_reg[7:7] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[7:7] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[7:7] == 1'b1)   dprio_dataout_reg[7:7] <= wire_dprio_dataout_reg_d[7:7];
	// synopsys translate_off
	initial
		dprio_dataout_reg[8:8] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[8:8] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[8:8] == 1'b1)   dprio_dataout_reg[8:8] <= wire_dprio_dataout_reg_d[8:8];
	// synopsys translate_off
	initial
		dprio_dataout_reg[9:9] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[9:9] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[9:9] == 1'b1)   dprio_dataout_reg[9:9] <= wire_dprio_dataout_reg_d[9:9];
	// synopsys translate_off
	initial
		dprio_dataout_reg[10:10] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[10:10] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[10:10] == 1'b1)   dprio_dataout_reg[10:10] <= wire_dprio_dataout_reg_d[10:10];
	// synopsys translate_off
	initial
		dprio_dataout_reg[11:11] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[11:11] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[11:11] == 1'b1)   dprio_dataout_reg[11:11] <= wire_dprio_dataout_reg_d[11:11];
	// synopsys translate_off
	initial
		dprio_dataout_reg[12:12] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[12:12] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[12:12] == 1'b1)   dprio_dataout_reg[12:12] <= wire_dprio_dataout_reg_d[12:12];
	// synopsys translate_off
	initial
		dprio_dataout_reg[13:13] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[13:13] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[13:13] == 1'b1)   dprio_dataout_reg[13:13] <= wire_dprio_dataout_reg_d[13:13];
	// synopsys translate_off
	initial
		dprio_dataout_reg[14:14] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[14:14] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[14:14] == 1'b1)   dprio_dataout_reg[14:14] <= wire_dprio_dataout_reg_d[14:14];
	// synopsys translate_off
	initial
		dprio_dataout_reg[15:15] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_dataout_reg[15:15] <= 1'b0;
		else if  (wire_dprio_dataout_reg_ena[15:15] == 1'b1)   dprio_dataout_reg[15:15] <= wire_dprio_dataout_reg_d[15:15];
	assign
		wire_dprio_dataout_reg_d = {wire_dprio_dataout[15:0]};
	assign
		wire_dprio_dataout_reg_ena = {16{(dprio_pulse & (~ idle_state))}};
	// synopsys translate_off
	initial
		dprio_pulse_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) dprio_pulse_reg <= 1'b0;
		else if  (wire_dprio_pulse_reg_ena == 1'b1)   dprio_pulse_reg <= wire_dprio_busy;
	assign
		wire_dprio_pulse_reg_ena = (read_state | write_state);
	// synopsys translate_off
	initial
		end_mif_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk)
		if (is_tier_1 == 1'b1)   end_mif_reg <= mif_reconfig_done;
	// synopsys translate_off
	initial
		global_register_reset_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk)
		  global_register_reset_reg <= (((reset_addr_done | reconfig_reset_all) | is_illegal_reg_out) | mif_reconfig_done);
	// synopsys translate_off
	initial
		is_bonded_global_clk_div_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge global_register_reset)
		if (global_register_reset == 1'b1) is_bonded_global_clk_div_reg <= 1'b0;
		else if  (wire_is_bonded_global_clk_div_reg_ena == 1'b1)   is_bonded_global_clk_div_reg <= (~ is_bonded_global_clk_div_reg);
	assign
		wire_is_bonded_global_clk_div_reg_ena = ((((((~ is_bonded_global_clk_div_reg) & is_table_33) | is_bonded_global_clk_div_reg) & is_bonded_reconfig) & (~ is_pll_reconfig)) & en_mif_addr_cntr);
	// synopsys translate_off
	initial
		is_bonded_reconfig_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge global_register_reset)
		if (global_register_reset == 1'b1) is_bonded_reconfig_reg <= 1'b0;
		else if  (delay_second_mif_head_out == 1'b1)   is_bonded_reconfig_reg <= reconfig_data_reg[14];
	// synopsys translate_off
	initial
		logical_pll_num_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) logical_pll_num_reg <= 1'b0;
		else if  (is_mif_header == 1'b1)   logical_pll_num_reg <= {reconfig_data_reg[0]};
	// synopsys translate_off
	initial
		mif_stage = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_stage <= 1'b0;
		else if  (is_tier_1 == 1'b1) 
			if (wire_mif_stage_sclr == 1'b1) mif_stage <= 1'b0;
			else  mif_stage <= (((~ mif_stage) & (is_mif_header | mif_reconfig_done)) | ((~ ((is_mif_header | mif_reconfig_done) & dprio_pulse)) & mif_stage));
	assign
		wire_mif_stage_sclr = ((reset_system | is_illegal_reg_out) | mif_reconfig_done);
	// synopsys translate_off
	initial
		mif_type_reg[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_type_reg[0:0] <= 1'b0;
		else if  (wire_mif_type_reg_ena[0:0] == 1'b1) 
			if (wire_mif_type_reg_sclr[0:0] == 1'b1) mif_type_reg[0:0] <= 1'b0;
			else  mif_type_reg[0:0] <= wire_mif_type_reg_d[0:0];
	// synopsys translate_off
	initial
		mif_type_reg[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_type_reg[1:1] <= 1'b0;
		else if  (wire_mif_type_reg_ena[1:1] == 1'b1) 
			if (wire_mif_type_reg_sclr[1:1] == 1'b1) mif_type_reg[1:1] <= 1'b0;
			else  mif_type_reg[1:1] <= wire_mif_type_reg_d[1:1];
	// synopsys translate_off
	initial
		mif_type_reg[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_type_reg[2:2] <= 1'b0;
		else if  (wire_mif_type_reg_ena[2:2] == 1'b1) 
			if (wire_mif_type_reg_sclr[2:2] == 1'b1) mif_type_reg[2:2] <= 1'b0;
			else  mif_type_reg[2:2] <= wire_mif_type_reg_d[2:2];
	// synopsys translate_off
	initial
		mif_type_reg[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_type_reg[3:3] <= 1'b0;
		else if  (wire_mif_type_reg_ena[3:3] == 1'b1) 
			if (wire_mif_type_reg_sclr[3:3] == 1'b1) mif_type_reg[3:3] <= 1'b0;
			else  mif_type_reg[3:3] <= wire_mif_type_reg_d[3:3];
	// synopsys translate_off
	initial
		mif_type_reg[4:4] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) mif_type_reg[4:4] <= 1'b0;
		else if  (wire_mif_type_reg_ena[4:4] == 1'b1) 
			if (wire_mif_type_reg_sclr[4:4] == 1'b1) mif_type_reg[4:4] <= 1'b0;
			else  mif_type_reg[4:4] <= wire_mif_type_reg_d[4:4];
	assign
		wire_mif_type_reg_d = ((((reconfig_data_reg[15:11] & {5{load_mif_header}}) & {5{(~ clr_offset)}}) | ({5{clr_offset}} & mif_type_reg)) | ({5{(is_diff_mif & diff_mif_load_mif_header)}} & diff_mif_mif_header));
	assign
		wire_mif_type_reg_ena = {5{((load_mif_header | clr_offset) | (is_diff_mif & diff_mif_load_mif_header))}},
		wire_mif_type_reg_sclr = {(((~ load_mif_header) & clr_offset) & is_tx_pcs), (((~ load_mif_header) & clr_offset) & is_rx_pcs), (((~ load_mif_header) & clr_offset) & is_tx_pma), (((~ load_mif_header) & clr_offset) & is_rx_pma), (((~ load_mif_header) & clr_offset) & is_cmu)};
	// synopsys translate_off
	initial
		reconf_mode_sel_reg[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconf_mode_sel_reg[0:0] <= 1'b0;
		else if  (wire_reconf_mode_sel_reg_ena[0:0] == 1'b1)   reconf_mode_sel_reg[0:0] <= reconfig_mode_sel[0:0];
	// synopsys translate_off
	initial
		reconf_mode_sel_reg[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconf_mode_sel_reg[1:1] <= 1'b0;
		else if  (wire_reconf_mode_sel_reg_ena[1:1] == 1'b1)   reconf_mode_sel_reg[1:1] <= reconfig_mode_sel[1:1];
	// synopsys translate_off
	initial
		reconf_mode_sel_reg[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconf_mode_sel_reg[2:2] <= 1'b0;
		else if  (wire_reconf_mode_sel_reg_ena[2:2] == 1'b1)   reconf_mode_sel_reg[2:2] <= reconfig_mode_sel[2:2];
	assign
		wire_reconf_mode_sel_reg_ena = {3{(idle_state & (~ mif_stage))}};
	// synopsys translate_off
	initial
		reconfig_data_reg[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[0:0] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[0:0] == 1'b1)   reconfig_data_reg[0:0] <= reconfig_data[0:0];
	// synopsys translate_off
	initial
		reconfig_data_reg[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[1:1] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[1:1] == 1'b1)   reconfig_data_reg[1:1] <= reconfig_data[1:1];
	// synopsys translate_off
	initial
		reconfig_data_reg[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[2:2] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[2:2] == 1'b1)   reconfig_data_reg[2:2] <= reconfig_data[2:2];
	// synopsys translate_off
	initial
		reconfig_data_reg[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[3:3] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[3:3] == 1'b1)   reconfig_data_reg[3:3] <= reconfig_data[3:3];
	// synopsys translate_off
	initial
		reconfig_data_reg[4:4] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[4:4] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[4:4] == 1'b1)   reconfig_data_reg[4:4] <= reconfig_data[4:4];
	// synopsys translate_off
	initial
		reconfig_data_reg[5:5] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[5:5] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[5:5] == 1'b1)   reconfig_data_reg[5:5] <= reconfig_data[5:5];
	// synopsys translate_off
	initial
		reconfig_data_reg[6:6] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[6:6] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[6:6] == 1'b1)   reconfig_data_reg[6:6] <= reconfig_data[6:6];
	// synopsys translate_off
	initial
		reconfig_data_reg[7:7] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[7:7] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[7:7] == 1'b1)   reconfig_data_reg[7:7] <= reconfig_data[7:7];
	// synopsys translate_off
	initial
		reconfig_data_reg[8:8] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[8:8] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[8:8] == 1'b1)   reconfig_data_reg[8:8] <= reconfig_data[8:8];
	// synopsys translate_off
	initial
		reconfig_data_reg[9:9] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[9:9] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[9:9] == 1'b1)   reconfig_data_reg[9:9] <= reconfig_data[9:9];
	// synopsys translate_off
	initial
		reconfig_data_reg[10:10] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[10:10] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[10:10] == 1'b1)   reconfig_data_reg[10:10] <= reconfig_data[10:10];
	// synopsys translate_off
	initial
		reconfig_data_reg[11:11] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[11:11] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[11:11] == 1'b1)   reconfig_data_reg[11:11] <= reconfig_data[11:11];
	// synopsys translate_off
	initial
		reconfig_data_reg[12:12] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[12:12] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[12:12] == 1'b1)   reconfig_data_reg[12:12] <= reconfig_data[12:12];
	// synopsys translate_off
	initial
		reconfig_data_reg[13:13] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[13:13] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[13:13] == 1'b1)   reconfig_data_reg[13:13] <= reconfig_data[13:13];
	// synopsys translate_off
	initial
		reconfig_data_reg[14:14] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[14:14] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[14:14] == 1'b1)   reconfig_data_reg[14:14] <= reconfig_data[14:14];
	// synopsys translate_off
	initial
		reconfig_data_reg[15:15] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_data_reg[15:15] <= 1'b0;
		else if  (wire_reconfig_data_reg_ena[15:15] == 1'b1)   reconfig_data_reg[15:15] <= reconfig_data[15:15];
	assign
		wire_reconfig_data_reg_ena = {16{(idle_state & write_all)}};
	// synopsys translate_off
	initial
		reconfig_done_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) reconfig_done_reg <= 1'b0;
		else if  (wire_reconfig_done_reg_ena == 1'b1) 
			if (reset_system == 1'b1) reconfig_done_reg <= 1'b0;
			else  reconfig_done_reg <= ((((mif_reconfig_done & ((~ is_diff_mif) & is_tier_1)) | (is_diff_mif & is_end_mif)) & (~ reconfig_done_reg)) | (reconfig_done_reg & ((((is_mif_header & (~ write_state)) & is_tier_1) | (is_end_mif & is_diff_mif)) | (~ is_tier_1))));
	assign
		wire_reconfig_done_reg_ena = (((is_mif_stage | (idle_state & (~ is_mif_stage))) & (~ is_diff_mif)) | is_diff_mif);
	// synopsys translate_off
	initial
		state_mc_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) state_mc_reg <= 1'b0;
		else  state_mc_reg <= state_mc_reg_in;
	// synopsys translate_off
	initial
		tx_cmu_sel = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) tx_cmu_sel <= 3'b0;
		else if  (wire_le7_out == 1'b1)   tx_cmu_sel <= reconfig_data_reg[2:0];
	// synopsys translate_off
	initial
		tx_pll_inclk_reg[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) tx_pll_inclk_reg[0:0] <= 1'b0;
		else if  (wire_tx_pll_inclk_reg_ena[0:0] == 1'b1)   tx_pll_inclk_reg[0:0] <= wire_tx_pll_inclk_reg_d[0:0];
	// synopsys translate_off
	initial
		tx_pll_inclk_reg[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) tx_pll_inclk_reg[1:1] <= 1'b0;
		else if  (wire_tx_pll_inclk_reg_ena[1:1] == 1'b1)   tx_pll_inclk_reg[1:1] <= wire_tx_pll_inclk_reg_d[1:1];
	// synopsys translate_off
	initial
		tx_pll_inclk_reg[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) tx_pll_inclk_reg[2:2] <= 1'b0;
		else if  (wire_tx_pll_inclk_reg_ena[2:2] == 1'b1)   tx_pll_inclk_reg[2:2] <= wire_tx_pll_inclk_reg_d[2:2];
	// synopsys translate_off
	initial
		tx_pll_inclk_reg[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) tx_pll_inclk_reg[3:3] <= 1'b0;
		else if  (wire_tx_pll_inclk_reg_ena[3:3] == 1'b1)   tx_pll_inclk_reg[3:3] <= wire_tx_pll_inclk_reg_d[3:3];
	assign
		wire_tx_pll_inclk_reg_d = reconfig_data_reg[10:7];
	assign
		wire_tx_pll_inclk_reg_ena = {4{((is_mif_header & (~ write_mif_word_done)) & is_tier_1)}};
	// synopsys translate_off
	initial
		wr_addr_inc_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) wr_addr_inc_reg <= 1'b0;
		else  wr_addr_inc_reg <= (wr_pulse | (((~ wr_pulse) & (~ rd_pulse)) & wr_addr_inc_reg));
	// synopsys translate_off
	initial
		wr_rd_pulse_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) wr_rd_pulse_reg <= 1'b0;
		else if  (wire_wr_rd_pulse_reg_ena == 1'b1) 
			if (wire_wr_rd_pulse_reg_sclr == 1'b1) wr_rd_pulse_reg <= 1'b0;
			else  wr_rd_pulse_reg <= (~ wr_rd_pulse_reg);
	assign
		wire_wr_rd_pulse_reg_ena = (((((((((~ dprio_pulse) & (~ is_diff_mif)) & (delay_mif_head_out | (delay_second_mif_head_out & ((((is_cruclk_addr0 | write_skip) | bonded_skip) | is_protected_bit) | is_cent_clk_div)))) | (is_diff_mif & diff_mif_reconfig_addr_start)) | (((dprio_pulse | (diff_mif_reconfig_addr_ready & is_diff_mif)) & ((~ is_tier_1) | (is_tier_1 & ((((((is_rcxpat_chnl_en_ch | is_cruclk_addr0) | write_skip) | (is_mif_header & (~ is_diff_mif))) | bonded_skip) | is_protected_bit) | is_cent_clk_div)))) & (~ read_state))) | (is_tier_1 & mif_reconfig_done)) | (is_diff_mif & write_done)) | reset_addr_done) | is_illegal_reg_out),
		wire_wr_rd_pulse_reg_sclr = ((((reset_system | (is_tier_1 & mif_reconfig_done)) | (is_diff_mif & write_done)) | reset_addr_done) | is_illegal_reg_out);
	// synopsys translate_off
	initial
		wren_data_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk or  posedge reconfig_reset_all)
		if (reconfig_reset_all == 1'b1) wren_data_reg <= 1'b0;
		else if  (wire_wren_data_reg_ena == 1'b1)   wren_data_reg <= (((~ wren_data_reg) & rd_pulse) | (wren_data_reg & (~ write_done)));
	assign
		wire_wren_data_reg_ena = (is_tier_1 & ((~ is_diff_mif) | (is_diff_mif & diff_mif_wr_rd_busy)));
	lcell   le7
	( 
	.in(is_mif_header),
	.out(wire_le7_out));
	lpm_add_sub   add_sub11
	( 
	.add_sub(add_sub_sel),
	.cout(),
	.dataa(wire_dprio_addr_offset_cnt_q),
	.datab(add_sub_datab),
	.overflow(),
	.result(wire_add_sub11_result)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.cin(),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		add_sub11.lpm_representation = "UNSIGNED",
		add_sub11.lpm_width = 5,
		add_sub11.lpm_type = "lpm_add_sub";
	lpm_add_sub   add_sub12
	( 
	.cout(),
	.dataa(pll_first_word_addr),
	.datab(global_clk_div_addr_offset),
	.overflow(),
	.result(wire_add_sub12_result)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.add_sub(1'b1),
	.cin(),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		add_sub12.lpm_direction = "ADD",
		add_sub12.lpm_representation = "UNSIGNED",
		add_sub12.lpm_width = 6,
		add_sub12.lpm_type = "lpm_add_sub";
	lpm_compare   dprio_addr_offset_cmpr
	( 
	.aeb(wire_dprio_addr_offset_cmpr_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(wire_dprio_addr_offset_cnt_q),
	.datab(dprio_addr_offset_cmpr_datab)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		dprio_addr_offset_cmpr.lpm_width = 5,
		dprio_addr_offset_cmpr.lpm_type = "lpm_compare";
	lpm_compare   is_cru_idx0
	( 
	.aeb(wire_is_cru_idx0_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab({5{1'b0}})
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_cru_idx0.lpm_width = 5,
		is_cru_idx0.lpm_type = "lpm_compare";
	lpm_compare   is_rcxpat_chnl_en_ch_word
	( 
	.aeb(wire_is_rcxpat_chnl_en_ch_word_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00001)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_rcxpat_chnl_en_ch_word.lpm_width = 5,
		is_rcxpat_chnl_en_ch_word.lpm_type = "lpm_compare";
	lpm_compare   is_second_mif_header_address
	( 
	.aeb(wire_is_second_mif_header_address_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(wire_mif_addr_cntr_q),
	.datab(6'b000001)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_second_mif_header_address.lpm_width = 6,
		is_second_mif_header_address.lpm_type = "lpm_compare";
	lpm_compare   is_special_address
	( 
	.aeb(wire_is_special_address_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(wire_mif_addr_cntr_q),
	.datab({6{1'b0}})
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_special_address.lpm_width = 6,
		is_special_address.lpm_type = "lpm_compare";
	lpm_compare   is_table_33_idx
	( 
	.aeb(wire_is_table_33_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00101)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_33_idx.lpm_width = 5,
		is_table_33_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_35_cmp
	( 
	.aeb(wire_is_table_35_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00110)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_35_cmp.lpm_width = 5,
		is_table_35_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_37_cmp
	( 
	.aeb(wire_is_table_37_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00010)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_37_cmp.lpm_width = 5,
		is_table_37_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_38_cmp
	( 
	.aeb(wire_is_table_38_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00011)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_38_cmp.lpm_width = 5,
		is_table_38_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_42_cmp
	( 
	.aeb(wire_is_table_42_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00111)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_42_cmp.lpm_width = 5,
		is_table_42_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_43_cmp
	( 
	.aeb(wire_is_table_43_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b01000)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_43_cmp.lpm_width = 5,
		is_table_43_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_44_cmp
	( 
	.aeb(wire_is_table_44_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b01001)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_44_cmp.lpm_width = 5,
		is_table_44_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_46_cmp
	( 
	.aeb(wire_is_table_46_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b01011)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_46_cmp.lpm_width = 5,
		is_table_46_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_47_cmp
	( 
	.aeb(wire_is_table_47_cmp_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b01100)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_47_cmp.lpm_width = 5,
		is_table_47_cmp.lpm_type = "lpm_compare";
	lpm_compare   is_table_59_idx
	( 
	.aeb(wire_is_table_59_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00100)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_59_idx.lpm_width = 5,
		is_table_59_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_60_idx
	( 
	.aeb(wire_is_table_60_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00101)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_60_idx.lpm_width = 5,
		is_table_60_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_61_idx
	( 
	.aeb(wire_is_table_61_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab({5{1'b0}})
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_61_idx.lpm_width = 5,
		is_table_61_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_75_idx
	( 
	.aeb(wire_is_table_75_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00001)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_75_idx.lpm_width = 5,
		is_table_75_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_76_idx
	( 
	.aeb(wire_is_table_76_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00010)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_76_idx.lpm_width = 5,
		is_table_76_idx.lpm_type = "lpm_compare";
	lpm_compare   is_table_77_idx
	( 
	.aeb(wire_is_table_77_idx_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(dprio_addr_offset_cnt_out),
	.datab(5'b00011)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		is_table_77_idx.lpm_width = 5,
		is_table_77_idx.lpm_type = "lpm_compare";
	lpm_counter   dprio_addr_offset_cnt
	( 
	.clock(reconfig_clk),
	.cnt_en((((en_mif_addr_cntr & (~ is_bonded_reconfig)) | ((en_mif_addr_cntr & is_bonded_reconfig) & ((((~ is_table_33) | is_pll_reconfig) | is_global_clk_div_mode) | is_bonded_global_clk_div))) & (~ is_diff_mif))),
	.cout(),
	.data(((diff_mif_reconfig_address & {5{diff_mif_address_busy}}) & {5{is_diff_mif}})),
	.eq(),
	.q(wire_dprio_addr_offset_cnt_q),
	.sclr((((clr_offset | is_mif_header) | global_register_reset) | (is_diff_mif & write_done))),
	.sload((((diff_mif_reconfig_addr_load & (~ is_bonded_reconfig)) | ((diff_mif_reconfig_addr_load & is_bonded_reconfig) & ((~ is_table_33) | is_bonded_global_clk_div))) & is_diff_mif))
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		dprio_addr_offset_cnt.lpm_port_updown = "PORT_UNUSED",
		dprio_addr_offset_cnt.lpm_width = 5,
		dprio_addr_offset_cnt.lpm_type = "lpm_counter";
	lpm_counter   mif_addr_cntr
	( 
	.clock(reconfig_clk),
	.cnt_en(((((en_mif_addr_cntr & (~ is_bonded_reconfig)) | ((en_mif_addr_cntr & is_bonded_reconfig) & (((~ is_table_33) | is_pll_reconfig) | is_bonded_global_clk_div))) | ((((((is_mif_header & write_state) | (is_second_mif_header & write_state)) & (~ write_done)) & (~ mif_reconfig_done)) & (~ reconf_done_reg_out)) & (~ dprio_pulse))) & is_tier_1)),
	.cout(),
	.data(mif_addr_cntr_data),
	.eq(),
	.q(wire_mif_addr_cntr_q),
	.sclr((((((reset_reconf_addr | is_end_mif) & (~ ((is_mif_header | is_second_mif_header) & write_state))) | ((wire_dprio_status_out[1] | wire_dprio_status_out[3]) & reset_system)) | is_illegal_reg_out) | reconfig_reset_all)),
	.sload(((((is_second_mif_header & (~ write_done)) & write_state) & (((is_pll_reconfig & (~ is_channel_reconfig)) | is_global_clk_div_mode) | is_central_pcs)) & (~ is_diff_mif)))
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		mif_addr_cntr.lpm_modulus = 62,
		mif_addr_cntr.lpm_port_updown = "PORT_UNUSED",
		mif_addr_cntr.lpm_width = 6,
		mif_addr_cntr.lpm_type = "lpm_counter";
	lpm_decode   reconf_mode_dec
	( 
	.data(reconf_mode_sel_reg),
	.enable(((~ idle_state) | mif_stage)),
	.eq(wire_reconf_mode_dec_eq)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.clken(1'b1),
	.clock(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		reconf_mode_dec.lpm_decodes = 8,
		reconf_mode_dec.lpm_width = 3,
		reconf_mode_dec.lpm_type = "lpm_decode";
	gxb_reconfig_mux_r7a   central_pcs_first_word_mux
	( 
	.data({6'b100110, 6'b001111, 6'b110111, 6'b010011, 6'b011100, 6'b001111, duplex_pma_pcs_first_pll, tx_pma_pcs_first_pll, duplex_pma_first_pll, tx_pma_first_pll}),
	.result(wire_central_pcs_first_word_mux_result),
	.sel({mif_rx_only, mif_type_reg[0], mif_type_reg[4], (((~ mif_rx_only) & mif_type_reg[1]) | (mif_rx_only & mif_type_reg[3]))}));
	gxb_reconfig_mux_a6a   central_pcs_global_clk_div_mux
	( 
	.data({global_clk_div_mode_offset_max, central_pcs_max, wire_max_word_per_mif_type_result}),
	.result(wire_central_pcs_global_clk_div_mux_result),
	.sel({is_global_clk_div_mode, is_central_pcs}));
	gxb_reconfig_mux_d6a   max_word_per_mif_type
	( 
	.data({cmu_max, rx_pma_max, tx_pma_max, rx_pcs_max, tx_pcs_max}),
	.result(wire_max_word_per_mif_type_result),
	.sel({is_cmu, is_pma_mif_type, is_rx_mif_type}));
	gxb_reconfig_mux_b6a   mif_addr_cntr_data_mux
	( 
	.data({global_clk_div_addr, central_pcs_first_word_addr, pll_first_word_addr}),
	.result(wire_mif_addr_cntr_data_mux_result),
	.sel({is_global_clk_div_mode, is_central_pcs}));
	gxb_reconfig_mux_c6a   pll_first_word_mux
	( 
	.data({duplex_pma_pcs_first_pll, tx_pma_pcs_first_pll, duplex_pma_first_pll, tx_pma_first_pll}),
	.result(wire_pll_first_word_mux_result),
	.sel({mif_type_reg[4], mif_type_reg[1]}));
	assign
		a2gr_dprio_addr = ((((write_address & {16{is_analog_control}}) | ((write_reconfig_addr & {16{(~ is_analog_control)}}) & {16{(~ header_proc)}})) & {16{write_state}}) | (((read_address & {16{is_analog_control}}) | ({16{(~ is_analog_control)}} & read_reconfig_addr)) & {16{read_state}})),
		a2gr_dprio_data = ((dprio_datain & {16{(~ header_proc)}}) & {16{write_state}}),
		a2gr_dprio_rden = (rd_pulse & ((~ is_diff_mif) | (is_diff_mif & diff_mif_wr_rd_busy))),
		a2gr_dprio_wren = (((wr_pulse & (~ wren_data_reg)) & (~ is_analog_control)) & ((~ is_diff_mif) | (is_diff_mif & diff_mif_wr_rd_busy))),
		a2gr_dprio_wren_data = ((wr_pulse & (wren_data_reg | is_analog_control)) & ((~ is_diff_mif) | (is_diff_mif & diff_mif_wr_rd_busy))),
		adce_busy_state = 1'b0,
		adce_state = 1'b0,
		add_sub_datab = ((((({5{is_rx_pma}} & rx_pma_minus_one) | (({5{(is_cmu & (~ is_cent_clk_div))}} & cmu_pll_plus_three) & {5{(~ is_global_clk_div_mode)}})) | (({5{(is_cmu & is_cent_clk_div)}} & cent_clk_div_plus_one) & {5{(~ is_global_clk_div_mode)}})) | ({5{is_global_clk_div_mode}} & global_clk_div_mode_plus_five)) | ({5{is_central_pcs}} & (({5{is_table_61}} & central_pcs_plus_seven) | ({5{(~ is_table_61)}} & central_pcs_minus_one)))),
		add_sub_sel = (~ (is_rx_pma | (is_central_pcs & (~ is_table_61)))),
		aeq_ch_done = 1'b0,
		bonded_skip = (((((((is_table_33 | is_table_35) & is_bonded_reconfig) | is_table_59) | is_table_61) | is_table_75) | is_table_76) | is_table_77),
		busy = (((((~ is_bonded_reconfig) & busy_state) | (is_bonded_reconfig & (((~ is_table_33) & busy_state) | (is_table_33 & (((~ is_bonded_global_clk_div) & busy_state) | is_bonded_global_clk_div))))) | internal_write_pulse) | cal_busy),
		busy_state = ((((read_state | write_state) | adce_state) | eyemon_busy) | dfe_busy),
		cal_busy = wire_calibration_busy,
		cal_channel_address = wire_calibration_dprio_addr[14:12],
		cal_channel_address_out = address_pres_reg[2:0],
		cal_dprio_address = {wire_calibration_dprio_addr[15], cal_channel_address_out, wire_calibration_dprio_addr[11:0]},
		cal_dprioout_wire = {reconfig_fromgxb[0]},
		cal_quad_address = wire_calibration_quad_addr,
		cal_testbuses = {reconfig_fromgxb[4:1]},
		cent_clk_div_plus_one = 5'b00001,
		central_pcs_first_word_addr = wire_central_pcs_first_word_mux_result,
		central_pcs_max = 5'b00101,
		central_pcs_minus_one = 5'b00001,
		central_pcs_plus_seven = 5'b00111,
		channel_address = {2{1'b0}},
		channel_address_out = (address_pres_reg[1:0] & {2{(~ ((address_pres_reg[2] & address_pres_reg[1]) & address_pres_reg[0]))}}),
		clr_offset = (((is_offset_end & en_mif_addr_cntr) & (~ is_diff_mif)) | (diff_mif_clr_offset & is_diff_mif)),
		cmu_max = 5'b00101,
		cmu_pll_plus_three = 5'b00011,
		cruclk_mux_data = {(((~ write_skip) & ((((~ cru_num_reg[1]) & (~ cru_num_reg[0])) | cru_num_reg[3]) | ((cru_num_reg[2] & cru_num_reg[1]) & cru_num_reg[0]))) | (write_skip & dprio_dataout_reg[15])), (((~ write_skip) & (((((~ cru_num_reg[3]) & (~ cru_num_reg[2])) & cru_num_reg[0]) | cru_num_reg[3]) | ((cru_num_reg[2] & cru_num_reg[1]) & (~ cru_num_reg[0])))) | (write_skip & dprio_dataout_reg[14])), (((~ write_skip) & ((cru_num_reg[3] | cru_num_reg[2]) | cru_num_reg[1])) | (write_skip & dprio_dataout_reg[13])), (((~ write_skip) & (((~ cru_num_reg[1]) & cru_num_reg[0]) | (cru_num_reg[2] & cru_num_reg[1]))) | (write_skip & dprio_dataout_reg[12])), (({6{(~ write_skip)}} & reconfig_data_reg[11:6]) | ({6{write_skip}} & dprio_dataout_reg[11:6])), dprio_dataout_reg[5:4], (({4{(~ write_skip)}} & reconfig_data_reg[3:0]) | ({4{write_skip}} & dprio_dataout_reg[3:0]))},
		delay_mif_head_out = delay_mif_head,
		delay_second_mif_head_out = delay_second_mif_head,
		dfe_busy = 1'b0,
		diff_mif_address_busy = 1'b0,
		diff_mif_clr_offset = 1'b0,
		diff_mif_load_mif_header = 1'b0,
		diff_mif_mif_header = {5{1'b0}},
		diff_mif_reconfig_addr_load = 1'b0,
		diff_mif_reconfig_addr_ready = 1'b0,
		diff_mif_reconfig_addr_start = 1'b0,
		diff_mif_reconfig_address = {5{1'b0}},
		diff_mif_wr_rd_busy = 1'b0,
		dprio_addr_index = (({5{(~ ((((~ is_cruclk_addr0) & is_rx_pma) | is_cmu) | is_central_pcs))}} & wire_dprio_addr_offset_cnt_q) | ({5{((((~ is_cruclk_addr0) & is_rx_pma) | is_cmu) | is_central_pcs)}} & dprio_addr_translated_offset)),
		dprio_addr_offset_cmpr_datab = wire_central_pcs_global_clk_div_mux_result,
		dprio_addr_offset_cnt_out = wire_dprio_addr_offset_cnt_q,
		dprio_addr_translated_offset = (wire_add_sub11_result & {5{((is_rx_pma | is_cmu) | is_central_pcs)}}),
		dprio_datain = ((((((((dprio_datain_vodctrl & {16{(write_word_vodctrl_data_valid | write_word_vodctrla_data_valid)}}) | (dprio_datain_preemp1t & {16{((write_word_preemp1t_data_valid | write_word_preemp1ta_data_valid) | write_word_preemp1tb_data_valid)}})) | (dprio_datain_64_67 & {16{write_word_64_67_data_valid}})) | ((dprio_datain_68_6B | {16{local_ch_dec}}) & {16{write_word_68_6B_data_valid}})) | (dprio_datain_7c_7f & {16{write_word_7c_7f_data_valid}})) | (dprio_datain_7c_7f_inv & {16{write_word_7c_7f_inv_data_valid}})) & {16{is_analog_control}}) | ({16{((is_tier_1 | is_tier_2) | is_tx_local_div_ctrl)}} & reconfig_datain)),
		dprio_datain_64_67 = {16{1'b0}},
		dprio_datain_68_6B = {16{1'b0}},
		dprio_datain_7c_7f = {16{1'b0}},
		dprio_datain_7c_7f_inv = {16{1'b0}},
		dprio_datain_preemp1t = {16{1'b0}},
		dprio_datain_vodctrl = {16{1'b0}},
		dprio_pulse = ((dprio_pulse_reg ^ wire_dprio_busy) & (~ wire_dprio_busy)),
		dprio_wr_done = wire_dprio_status_out[1],
		duplex_pma_first_pll = 6'b010110,
		duplex_pma_pcs_first_pll = 6'b110001,
		en_mif_addr_cntr = ((read_state & dprio_wr_done) | ((write_state & dprio_wr_done) & write_happened)),
		en_write_trigger = legal_wr_mode_type,
		eyemon_busy = 1'b0,
		global_clk_div_addr = wire_add_sub12_result,
		global_clk_div_addr_offset = 6'b000100,
		global_clk_div_mode_offset_max = {5{1'b0}},
		global_clk_div_mode_plus_five = 5'b00101,
		global_register_reset = global_register_reset_reg,
		header_proc = ((((delay_mif_head | is_mif_header) | delay_second_mif_head_out) | is_second_mif_header) & is_tier_1),
		idle_state = (~ state_mc_reg),
		internal_write_pulse = 1'b0,
		is_adce = ((((is_adce_single_control | is_adce_all_control) | is_adce_continuous_single_control) | is_adce_one_time_single_control) | is_adce_standby_single_control),
		is_adce_all_control = 1'b0,
		is_adce_continuous_single_control = 1'b0,
		is_adce_one_time_single_control = 1'b0,
		is_adce_single_control = 1'b0,
		is_adce_standby_single_control = 1'b0,
		is_analog_control = wire_reconf_mode_dec_eq[0],
		is_bonded_global_clk_div = is_bonded_global_clk_div_reg,
		is_bonded_reconfig = is_bonded_reconfig_reg,
		is_cent_clk_div = ((is_table_59 | is_table_60) | is_global_clk_div_mode),
		is_central_pcs = wire_reconf_mode_dec_eq[7],
		is_channel_reconfig = ((wire_reconf_mode_dec_eq[1] | wire_reconf_mode_dec_eq[5]) | wire_reconf_mode_dec_eq[6]),
		is_cmu = (((((mif_type_reg[0] & (~ is_tx_pcs)) & (~ is_rx_pcs)) & (~ is_tx_pma)) & (~ is_rx_pma)) & (((is_pll_reconfig & (~ is_central_pcs)) | is_global_clk_div_mode) | is_diff_mif)),
		is_cruclk_addr0 = ((wire_is_cru_idx0_aeb & is_tier_1) & is_rx_pma),
		is_diff_mif = 1'b0,
		is_do_dfe = 1'b0,
		is_do_eyemon = 1'b0,
		is_end_mif = end_mif_reg,
		is_global_clk_div_mode = wire_reconf_mode_dec_eq[2],
		is_illegal_reg_d = 1'b0,
		is_illegal_reg_out = 1'b0,
		is_mif_header = wire_is_special_address_aeb,
		is_mif_stage = mif_stage,
		is_offset_end = wire_dprio_addr_offset_cmpr_aeb,
		is_pll_address = is_cmu,
		is_pll_reconfig = (wire_reconf_mode_dec_eq[4] | wire_reconf_mode_dec_eq[5]),
		is_pll_reset_stage = 1'b0,
		is_pma_mif_type = (is_tx_pma | is_rx_pma),
		is_protected_bit = (((((((is_table_35 | is_table_37) | is_table_38) | is_table_42) | is_table_43) | is_table_44) | is_table_46) | is_table_47),
		is_rcxpat_chnl_en_ch = ((wire_is_rcxpat_chnl_en_ch_word_aeb & is_tier_1) & is_tx_pcs),
		is_rx_mif_type = (is_rx_pcs | is_rx_pma),
		is_rx_pcs = ((mif_type_reg[3] & (~ is_tx_pcs)) & ((is_channel_reconfig & (~ is_central_pcs)) | is_diff_mif)),
		is_rx_pma = ((((mif_type_reg[1] & (~ is_tx_pcs)) & (~ is_rx_pcs)) & (~ is_tx_pma)) & ((is_channel_reconfig & (~ is_central_pcs)) | is_diff_mif)),
		is_second_mif_header = wire_is_second_mif_header_address_aeb,
		is_table_33 = ((wire_is_table_33_idx_aeb & is_tier_1) & is_tx_pma),
		is_table_35 = (wire_is_table_35_cmp_aeb & is_tx_pma),
		is_table_37 = ((wire_is_table_37_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_38 = ((wire_is_table_38_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_42 = ((wire_is_table_42_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_43 = ((wire_is_table_43_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_44 = ((wire_is_table_44_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_46 = ((wire_is_table_46_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_47 = ((wire_is_table_47_cmp_aeb & is_tier_1) & is_rx_pma),
		is_table_59 = ((wire_is_table_59_idx_aeb & is_tier_1) & is_cmu),
		is_table_60 = ((wire_is_table_60_idx_aeb & is_tier_1) & is_cmu),
		is_table_61 = ((wire_is_table_61_idx_aeb & is_tier_1) & is_central_pcs),
		is_table_75 = ((wire_is_table_75_idx_aeb & is_tier_1) & is_central_pcs),
		is_table_76 = ((wire_is_table_76_idx_aeb & is_tier_1) & is_central_pcs),
		is_table_77 = ((wire_is_table_77_idx_aeb & is_tier_1) & is_central_pcs),
		is_tier_1 = (((((wire_reconf_mode_dec_eq[1] | wire_reconf_mode_dec_eq[6]) | wire_reconf_mode_dec_eq[4]) | wire_reconf_mode_dec_eq[5]) | wire_reconf_mode_dec_eq[7]) | is_global_clk_div_mode),
		is_tier_2 = 1'b0,
		is_tx_local_div_ctrl = wire_reconf_mode_dec_eq[3],
		is_tx_pcs = (mif_type_reg[4] & ((is_channel_reconfig & (~ is_central_pcs)) | is_diff_mif)),
		is_tx_pma = (((mif_type_reg[2] & (~ is_tx_pcs)) & (~ is_rx_pcs)) & ((is_channel_reconfig & (~ is_central_pcs)) | is_diff_mif)),
		legal_wr_mode_type = ((reconfig_mode_sel[2] | (((~ reconfig_mode_sel[2]) & reconfig_mode_sel[1]) & (~ reconfig_mode_sel[0]))) | (((~ reconfig_mode_sel[2]) & reconfig_mode_sel[0]) & (~ reconfig_mode_sel[1]))),
		load_mif_header = ((is_mif_header & (~ write_mif_word_done)) & is_tier_1),
		local_ch_dec = aeq_ch_done,
		logical_pll_sel_num = {1'b0, logical_pll_num_reg},
		merged_dprioin = {((((is_table_60 & (~ write_skip)) & ((((~ tx_pll_inclk_reg[1]) & (~ tx_pll_inclk_reg[0])) | (tx_pll_inclk_reg[3] & (~ tx_pll_inclk_reg[1]))) | ((tx_pll_inclk_reg[2] & tx_pll_inclk_reg[1]) & tx_pll_inclk_reg[0]))) | (((~ is_table_60) & (~ write_skip)) & reconfig_data_reg[15])) | (write_skip & dprio_dataout_reg[15])), ((((is_table_60 & (~ write_skip)) & (((((~ tx_pll_inclk_reg[3]) & (~ tx_pll_inclk_reg[2])) & tx_pll_inclk_reg[0]) | (tx_pll_inclk_reg[3] & (~ tx_pll_inclk_reg[1]))) | ((tx_pll_inclk_reg[2] & tx_pll_inclk_reg[1]) & (~ tx_pll_inclk_reg[0])))) | (((~ is_table_60) & (~ write_skip)) & reconfig_data_reg[14])) | (write_skip & dprio_dataout_reg[14])), ((((is_table_60 & (~ write_skip)) & ((tx_pll_inclk_reg[3] | tx_pll_inclk_reg[2]) | tx_pll_inclk_reg[1])) | (((~ is_table_60) & (~ write_skip)) & reconfig_data_reg[13])) | (write_skip & dprio_dataout_reg[13])), ((((is_table_60 & (~ write_skip)) & (((~ tx_pll_inclk_reg[1]) & tx_pll_inclk_reg[0]) | (tx_pll_inclk_reg[2] & tx_pll_inclk_reg[1]))) | (((~ is_table_60) & (~ write_skip)) & reconfig_data_reg[12])) | (write_skip & dprio_dataout_reg[12])), (({9{(~ write_skip)}} & reconfig_data_reg[11:3]) | ({9{write_skip}} & dprio_dataout_reg[11:3])), ((({2{(is_rcxpat_chnl_en_ch & (~ write_skip))}} & dprio_dataout_reg[2:1]) | ({2{((~ is_rcxpat_chnl_en_ch) & (~ write_skip))}} & reconfig_data_reg[2:1])) | ({2{write_skip}} & dprio_dataout_reg[2:1])), (((~ write_skip) & reconfig_data_reg[0]) | (write_skip & dprio_dataout_reg[0]))},
		mif_addr_cntr_data = wire_mif_addr_cntr_data_mux_result,
		mif_reconfig_done = ((((~ (((((mif_type_reg[4] | mif_type_reg[3]) | mif_type_reg[2]) | mif_type_reg[1]) & is_channel_reconfig) | (mif_type_reg[0] & (is_pll_reconfig | is_global_clk_div_mode)))) & write_done) & (~ is_central_pcs)) | ((is_central_pcs & is_offset_end) & dprio_pulse)),
		mif_rx_only = ((~ mif_type_reg[2]) & (~ mif_type_reg[4])),
		offset_cancellation_reset = 1'b0,
		pll_first_word_addr = wire_pll_first_word_mux_result,
		quad_address = {9{1'b0}},
		quad_address_out = address_pres_reg[11:3],
		rd_pulse = (((((~ dprio_pulse) & (~ write_done)) & (~ wr_rd_pulse_reg)) & (~ is_illegal_reg_d)) & (write_state & (((~ header_proc) & (~ reset_reconf_addr)) & ((~ is_tier_1) | (is_tier_1 & (((((is_rcxpat_chnl_en_ch | is_cruclk_addr0) | write_skip) | bonded_skip) | is_protected_bit) | is_global_clk_div_mode)))))),
		read_address = {16{1'b0}},
		read_reconfig_addr = {16{1'b0}},
		read_state = 1'b0,
		reconf_done_reg_out = reconfig_done_reg,
		reconfig_address_out = ((wire_mif_addr_cntr_q & {6{((~ mif_reconfig_done) & (~ is_end_mif))}}) & {6{is_tier_1}}),
		reconfig_datain = ((((((((((((((((({16{is_cruclk_addr0}} & cruclk_mux_data) | ({16{is_table_33}} & table_33_data)) | ({16{is_table_35}} & table_35_data)) | ({16{(is_table_59 | is_global_clk_div_mode)}} & table_59_data)) | ({16{is_table_61}} & table_61_data)) | ({16{is_table_75}} & table_75_data)) | ({16{is_table_76}} & table_76_data)) | ({16{is_table_77}} & table_77_data)) | ({16{is_table_37}} & table_37_data)) | ({16{is_table_38}} & table_38_data)) | ({16{is_table_42}} & table_42_data)) | ({16{is_table_43}} & table_43_data)) | ({16{is_table_44}} & table_44_data)) | ({16{is_table_46}} & table_46_data)) | ({16{is_table_47}} & table_47_data)) | (merged_dprioin & {16{(~ (((((((((((((((((is_table_33 | is_table_35) | is_table_59) | is_global_clk_div_mode) | is_table_61) | is_table_75) | is_table_76) | is_table_77) | is_table_37) | is_table_38) | is_table_42) | is_table_43) | is_table_44) | is_table_46) | is_table_47) | is_cruclk_addr0) | is_tx_local_div_ctrl) | is_pll_reset_stage))}})) | ({16{(is_tx_local_div_ctrl | is_pll_reset_stage)}} & dprio_dataout_reg)),
		reconfig_reset_all = 1'b0,
		reconfig_togxb = {wire_calibration_busy, wire_dprio_dprioload, wire_dprio_dpriodisable, wire_dprio_dprioin},
		reset_addr_done = 1'b0,
		reset_reconf_addr = 1'b0,
		reset_system = 1'b0,
		rx_pcs_max = 5'b10110,
		rx_pma_max = 5'b01100,
		rx_pma_minus_one = 5'b00001,
		rx_reconfig = 1'b1,
		s0_to_0 = write_done,
		s0_to_1 = (write_all_int & idle_state),
		s0_to_2 = ((idle_state & ((is_adce | is_do_eyemon) | is_do_dfe)) & ((write_all & ((~ is_bonded_reconfig) | (is_bonded_reconfig & (~ is_bonded_global_clk_div)))) | (is_bonded_reconfig & is_bonded_global_clk_div))),
		s2_to_0 = (adce_state & (~ ((adce_busy_state | eyemon_busy) | dfe_busy))),
		start = 1'b0,
		state_mc_reg_in = ((s0_to_2 | s0_to_1) | ((((~ s2_to_0) & (~ s0_to_1)) & (~ s0_to_0)) & state_mc_reg[0])),
		table_33_data = {((((~ write_skip) & (~ is_bonded_reconfig)) & tx_pll_sel_wire[1]) | ((write_skip | is_bonded_reconfig) & dprio_dataout_reg[15])), ((((~ write_skip) & (~ is_bonded_reconfig)) & ((tx_pll_sel_wire[1] & tx_pll_sel_wire[0]) | tx_pll_sel_wire[2])) | ((write_skip | is_bonded_reconfig) & dprio_dataout_reg[14])), (((((~ write_skip) & ((~ is_bonded_reconfig) | is_bonded_global_clk_div)) & tx_pll_sel_wire[0]) & (~ tx_pll_sel_wire[1])) | ((write_skip | (is_bonded_reconfig & (~ is_bonded_global_clk_div))) & dprio_dataout_reg[13])), (({13{(~ write_skip)}} & reconfig_data_reg[12:0]) | ({13{write_skip}} & dprio_dataout_reg[12:0]))},
		table_35_data = {dprio_dataout_reg[15:5], (((~ write_skip) & reconfig_data_reg[4]) | (write_skip & dprio_dataout_reg[4])), ((((~ write_skip) & (~ is_bonded_reconfig)) & ((tx_pll_sel_wire[1] & tx_pll_sel_wire[0]) | tx_pll_sel_wire[2])) | ((write_skip | is_bonded_reconfig) & dprio_dataout_reg[3])), (({3{(~ write_skip)}} & reconfig_data_reg[2:0]) | ({3{write_skip}} & dprio_dataout_reg[2:0]))},
		table_37_data = {(({4{(~ write_skip)}} & reconfig_data_reg[15:12]) | ({4{write_skip}} & dprio_dataout_reg[15:12])), dprio_dataout_reg[11:3], (({3{(~ write_skip)}} & reconfig_data_reg[2:0]) | ({3{write_skip}} & dprio_dataout_reg[2:0]))},
		table_38_data = {(({9{(~ write_skip)}} & reconfig_data_reg[15:7]) | ({9{write_skip}} & dprio_dataout_reg[15:7])), dprio_dataout_reg[6:5], (({5{(~ write_skip)}} & reconfig_data_reg[4:0]) | ({5{write_skip}} & dprio_dataout_reg[4:0]))},
		table_42_data = {dprio_dataout_reg[15:0]},
		table_43_data = {(({8{(~ write_skip)}} & reconfig_data_reg[15:8]) | ({8{write_skip}} & dprio_dataout_reg[15:8])), dprio_dataout_reg[7:0]},
		table_44_data = {(((~ write_skip) & reconfig_data_reg[15]) | (write_skip & dprio_dataout_reg[15])), dprio_dataout_reg[14:4], (({4{(~ write_skip)}} & reconfig_data_reg[3:0]) | ({4{write_skip}} & dprio_dataout_reg[3:0]))},
		table_46_data = {dprio_dataout_reg[15:10], (({10{(~ write_skip)}} & reconfig_data_reg[9:0]) | ({10{write_skip}} & dprio_dataout_reg[9:0]))},
		table_47_data = {dprio_dataout_reg[15:0]},
		table_59_data = {dprio_dataout_reg[15:14], (((((~ write_skip) & is_bonded_reconfig) & (is_channel_reconfig | is_global_clk_div_mode)) & tx_pll_sel_wire[0]) | (((write_skip | (~ is_bonded_reconfig)) | ((~ is_channel_reconfig) & (~ is_global_clk_div_mode))) & dprio_dataout_reg[13])), (({13{(((~ write_skip) & (is_pll_reconfig | is_global_clk_div_mode)) & is_bonded_reconfig)}} & reconfig_data_reg[12:0]) | ({13{((write_skip | ((~ is_pll_reconfig) & (~ is_global_clk_div_mode))) | (~ is_bonded_reconfig))}} & dprio_dataout_reg[12:0]))},
		table_61_data = {dprio_dataout_reg[15:4], (((~ write_skip) & reconfig_data_reg[3]) | (write_skip & dprio_dataout_reg[3])), dprio_dataout_reg[2:0]},
		table_75_data = {(((~ write_skip) & reconfig_data_reg[15]) | (write_skip & dprio_dataout_reg[15])), dprio_dataout_reg[14], (({2{(~ write_skip)}} & reconfig_data_reg[13:12]) | ({2{write_skip}} & dprio_dataout_reg[13:12])), dprio_dataout_reg[11], (({11{(~ write_skip)}} & reconfig_data_reg[10:0]) | ({11{write_skip}} & dprio_dataout_reg[10:0]))},
		table_76_data = {dprio_dataout_reg[15], (({9{(~ write_skip)}} & reconfig_data_reg[14:6]) | ({9{write_skip}} & dprio_dataout_reg[14:6])), dprio_dataout_reg[5:3], (({3{(~ write_skip)}} & reconfig_data_reg[2:0]) | ({3{write_skip}} & dprio_dataout_reg[2:0]))},
		table_77_data = {dprio_dataout_reg[15:14], (({14{(~ write_skip)}} & reconfig_data_reg[13:0]) | ({14{write_skip}} & dprio_dataout_reg[13:0]))},
		transceiver_init = 1'b0,
		tx_pcs_max = 5'b00011,
		tx_pll_sel_wire = tx_cmu_sel,
		tx_pma_first_pll = 6'b001001,
		tx_pma_max = 5'b00110,
		tx_pma_pcs_first_pll = 6'b001101,
		tx_reconfig = 1'b1,
		wr_pulse = ((((write_state & (~ dprio_pulse)) & (~ write_done)) & ((wr_rd_pulse_reg & ((~ is_tier_1) | ((is_tier_1 & (~ header_proc)) & (((((is_rcxpat_chnl_en_ch | is_cruclk_addr0) | write_skip) | bonded_skip) | is_protected_bit) | is_global_clk_div_mode)))) | ((is_tier_1 & (~ header_proc)) & ((((((~ is_rcxpat_chnl_en_ch) & (~ is_cruclk_addr0)) & (~ write_skip)) & (~ bonded_skip)) & (~ is_protected_bit)) & (~ is_global_clk_div_mode))))) & (~ is_illegal_reg_d)),
		write_address = {1'b0, address_pres_reg[2], channel_address_out, {2{1'b1}}, {6{1'b0}}, {4{1'b0}}},
		write_all_int = (((write_all & ((~ is_bonded_reconfig) | (is_bonded_reconfig & (~ is_bonded_global_clk_div)))) | (is_bonded_reconfig & is_bonded_global_clk_div)) & en_write_trigger),
		write_done = ((((((write_word_done & write_happened) & is_analog_control) | ((((delay_mif_head_out | delay_second_mif_head_out) | write_mif_word_done) | (is_diff_mif & is_end_mif)) | (reset_addr_done & is_tier_1))) | ((dprio_pulse & write_happened) & (is_tier_2 | is_tx_local_div_ctrl))) | (is_illegal_reg_out & write_state)) | reset_system),
		write_happened = wr_addr_inc_reg,
		write_mif_word_done = ((dprio_pulse & write_happened) & is_tier_1),
		write_reconfig_addr = {1'b0, address_pres_reg[2], (channel_address_out[1] | (is_central_pcs & (~ is_table_61))), ((channel_address_out[0] & (~ is_central_pcs)) | (is_table_61 & is_central_pcs)), ((((is_pma_mif_type | is_tx_local_div_ctrl) | is_cmu) & (~ is_central_pcs)) | (is_table_61 & is_central_pcs)), (((is_rx_mif_type & (~ is_cruclk_addr0)) | (is_cmu & (~ is_cent_clk_div))) & (~ is_central_pcs)), {5{1'b0}}, (({2{(~ is_cruclk_addr0)}} & dprio_addr_index[4:3]) & {2{(~ is_tx_local_div_ctrl)}}), ((is_cruclk_addr0 | ((~ is_cruclk_addr0) & dprio_addr_index[2])) | is_tx_local_div_ctrl), ((is_cruclk_addr0 | ((~ is_cruclk_addr0) & dprio_addr_index[1])) & (~ is_tx_local_div_ctrl)), (((~ is_cruclk_addr0) & (is_table_35 | dprio_addr_index[0])) | is_tx_local_div_ctrl)},
		write_skip = (((((is_tx_pcs | is_tx_pma) & (~ tx_reconfig)) | ((is_rx_pcs | is_rx_pma) & (~ rx_reconfig))) | (is_cmu & (~ tx_reconfig))) | ((is_diff_mif & (diff_mif_wr_rd_busy | diff_mif_reconfig_addr_ready)) & ((((~ is_pll_reconfig) & (~ is_global_clk_div_mode)) & is_cmu) | ((~ is_channel_reconfig) & (((is_tx_pcs | is_rx_pcs) | is_tx_pma) | is_rx_pma))))),
		write_state = state_mc_reg,
		write_word_64_67_data_valid = 1'b0,
		write_word_68_6B_data_valid = 1'b0,
		write_word_7c_7f_data_valid = 1'b0,
		write_word_7c_7f_inv_data_valid = 1'b0,
		write_word_done = 1'b0,
		write_word_preemp1t_data_valid = 1'b0,
		write_word_preemp1ta_data_valid = 1'b0,
		write_word_preemp1tb_data_valid = 1'b0,
		write_word_vodctrl_data_valid = 1'b0,
		write_word_vodctrla_data_valid = 1'b0;
endmodule // gxb_reconfig
