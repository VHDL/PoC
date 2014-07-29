
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

//synthesis_resources = lpm_add_sub 1 lpm_compare 3 lpm_counter 1 lpm_decode 1 lut 1 reg 110 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"{-to addr_shift_reg[31]} DPRIO_INTERFACE_REG=ON;{-to wr_out_data_shift_reg[31]} DPRIO_INTERFACE_REG=ON;{-to rd_out_data_shift_reg[13]} DPRIO_INTERFACE_REG=ON;{-to in_data_shift_reg[0]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[0]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[1]} DPRIO_INTERFACE_REG=ON;{-to startup_cntr[2]} DPRIO_INTERFACE_REG=ON"} *)
module  gxb_reconfig_alt_dprio
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
	is_pcs_address,
	quad_address,
	rden,
	status_out,
	wren,
	wren_data);

	input   [7:0]  address;
	output   busy;
	input   [15:0]  datain;
	output   [15:0]  dataout;
	input   dpclk;
	output   dpriodisable;
	output   dprioin;
	output   dprioload;
	input   dprioout;
	input   is_pcs_address;
	input   [5:0]  quad_address;
	input   rden;
	output   [3:0]  status_out;
	input   wren;
	input   wren_data;

	wire	[31:0]	addr_shift_reg_d;
	wire	[31:0]	addr_shift_reg_asdata;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[31:0]	addr_shift_reg;
	wire	[31:0]	addr_shift_reg_sload;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	in_data_shift_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	rd_out_data_shift_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[7:0]	real_address;
	wire	[2:0]	startup_cntr_d;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	startup_cntr;
	wire	startup_cntr_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	state_mc_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[31:0]	wr_out_data_shift_reg;
	wire  [7:0]   odd_addr_trans_result;
	wire  pre_amble_cmpr_aeb;
	wire  pre_amble_cmpr_agb;
	wire  rd_data_output_cmpr_ageb;
	wire  rd_data_output_cmpr_alb;
	wire  state_mc_cmpr_aeb;
	wire  [5:0]   state_mc_counter_q;
	wire  [7:0]   state_mc_decode_eq;
	wire	dprioin_mux_dataout;
	wire  [7:0]  address_in;
	wire  busy_state;
	wire  idle_state;
	wire  rd_addr_done;
	wire  rd_addr_state;
	wire  rd_data_done;
	wire  rd_data_input_state;
	wire  rd_data_output_state;
	wire  rd_data_state;
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
		addr_shift_reg = 32'b00000000000000000000000000000000;
	// synopsys translate_on
	always @ ( posedge dpclk ) begin
		if (addr_shift_reg_sload[0]) addr_shift_reg[0] <= addr_shift_reg_asdata[0];
		else addr_shift_reg[0] <= addr_shift_reg_d[0];
		if (addr_shift_reg_sload[1]) addr_shift_reg[1] <= addr_shift_reg_asdata[1];
		else addr_shift_reg[1] <= addr_shift_reg_d[1];
		if (addr_shift_reg_sload[2]) addr_shift_reg[2] <= addr_shift_reg_asdata[2];
		else addr_shift_reg[2] <= addr_shift_reg_d[2];
		if (addr_shift_reg_sload[3]) addr_shift_reg[3] <= addr_shift_reg_asdata[3];
		else addr_shift_reg[3] <= addr_shift_reg_d[3];
		if (addr_shift_reg_sload[4]) addr_shift_reg[4] <= addr_shift_reg_asdata[4];
		else addr_shift_reg[4] <= addr_shift_reg_d[4];
		if (addr_shift_reg_sload[5]) addr_shift_reg[5] <= addr_shift_reg_asdata[5];
		else addr_shift_reg[5] <= addr_shift_reg_d[5];
		if (addr_shift_reg_sload[6]) addr_shift_reg[6] <= addr_shift_reg_asdata[6];
		else addr_shift_reg[6] <= addr_shift_reg_d[6];
		if (addr_shift_reg_sload[7]) addr_shift_reg[7] <= addr_shift_reg_asdata[7];
		else addr_shift_reg[7] <= addr_shift_reg_d[7];
		if (addr_shift_reg_sload[8]) addr_shift_reg[8] <= addr_shift_reg_asdata[8];
		else addr_shift_reg[8] <= addr_shift_reg_d[8];
		if (addr_shift_reg_sload[9]) addr_shift_reg[9] <= addr_shift_reg_asdata[9];
		else addr_shift_reg[9] <= addr_shift_reg_d[9];
		if (addr_shift_reg_sload[10]) addr_shift_reg[10] <= addr_shift_reg_asdata[10];
		else addr_shift_reg[10] <= addr_shift_reg_d[10];
		if (addr_shift_reg_sload[11]) addr_shift_reg[11] <= addr_shift_reg_asdata[11];
		else addr_shift_reg[11] <= addr_shift_reg_d[11];
		if (addr_shift_reg_sload[12]) addr_shift_reg[12] <= addr_shift_reg_asdata[12];
		else addr_shift_reg[12] <= addr_shift_reg_d[12];
		if (addr_shift_reg_sload[13]) addr_shift_reg[13] <= addr_shift_reg_asdata[13];
		else addr_shift_reg[13] <= addr_shift_reg_d[13];
		if (addr_shift_reg_sload[14]) addr_shift_reg[14] <= addr_shift_reg_asdata[14];
		else addr_shift_reg[14] <= addr_shift_reg_d[14];
		if (addr_shift_reg_sload[15]) addr_shift_reg[15] <= addr_shift_reg_asdata[15];
		else addr_shift_reg[15] <= addr_shift_reg_d[15];
		if (addr_shift_reg_sload[16]) addr_shift_reg[16] <= addr_shift_reg_asdata[16];
		else addr_shift_reg[16] <= addr_shift_reg_d[16];
		if (addr_shift_reg_sload[17]) addr_shift_reg[17] <= addr_shift_reg_asdata[17];
		else addr_shift_reg[17] <= addr_shift_reg_d[17];
		if (addr_shift_reg_sload[18]) addr_shift_reg[18] <= addr_shift_reg_asdata[18];
		else addr_shift_reg[18] <= addr_shift_reg_d[18];
		if (addr_shift_reg_sload[19]) addr_shift_reg[19] <= addr_shift_reg_asdata[19];
		else addr_shift_reg[19] <= addr_shift_reg_d[19];
		if (addr_shift_reg_sload[20]) addr_shift_reg[20] <= addr_shift_reg_asdata[20];
		else addr_shift_reg[20] <= addr_shift_reg_d[20];
		if (addr_shift_reg_sload[21]) addr_shift_reg[21] <= addr_shift_reg_asdata[21];
		else addr_shift_reg[21] <= addr_shift_reg_d[21];
		if (addr_shift_reg_sload[22]) addr_shift_reg[22] <= addr_shift_reg_asdata[22];
		else addr_shift_reg[22] <= addr_shift_reg_d[22];
		if (addr_shift_reg_sload[23]) addr_shift_reg[23] <= addr_shift_reg_asdata[23];
		else addr_shift_reg[23] <= addr_shift_reg_d[23];
		if (addr_shift_reg_sload[24]) addr_shift_reg[24] <= addr_shift_reg_asdata[24];
		else addr_shift_reg[24] <= addr_shift_reg_d[24];
		if (addr_shift_reg_sload[25]) addr_shift_reg[25] <= addr_shift_reg_asdata[25];
		else addr_shift_reg[25] <= addr_shift_reg_d[25];
		if (addr_shift_reg_sload[26]) addr_shift_reg[26] <= addr_shift_reg_asdata[26];
		else addr_shift_reg[26] <= addr_shift_reg_d[26];
		if (addr_shift_reg_sload[27]) addr_shift_reg[27] <= addr_shift_reg_asdata[27];
		else addr_shift_reg[27] <= addr_shift_reg_d[27];
		if (addr_shift_reg_sload[28]) addr_shift_reg[28] <= addr_shift_reg_asdata[28];
		else addr_shift_reg[28] <= addr_shift_reg_d[28];
		if (addr_shift_reg_sload[29]) addr_shift_reg[29] <= addr_shift_reg_asdata[29];
		else addr_shift_reg[29] <= addr_shift_reg_d[29];
		if (addr_shift_reg_sload[30]) addr_shift_reg[30] <= addr_shift_reg_asdata[30];
		else addr_shift_reg[30] <= addr_shift_reg_d[30];
		if (addr_shift_reg_sload[31]) addr_shift_reg[31] <= addr_shift_reg_asdata[31];
		else addr_shift_reg[31] <= addr_shift_reg_d[31];
	end
	assign
		addr_shift_reg_asdata = {{2{{2{1'b0}}}}, {4{1'b0}}, quad_address, 2'b10, 8'b10000000, address_in},
		addr_shift_reg_d = {addr_shift_reg[30:8], real_address[7], address_in};
	assign
		addr_shift_reg_sload = {{24{pre_amble_cmpr_aeb}}, {8{1'b0}}};
	// synopsys translate_off
	initial
		in_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk )
		if (rd_data_input_state) in_data_shift_reg <= {in_data_shift_reg[14:0], dprioout};
	// synopsys translate_off
	initial
		rd_out_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk )
		if (pre_amble_cmpr_aeb) rd_out_data_shift_reg <= {{2{1'b0}}, {2{1'b1}}, {4{1'b0}}, quad_address, 2'b10};
		else rd_out_data_shift_reg <= {rd_out_data_shift_reg[14:0], 1'b0};
	// synopsys translate_off
	initial
		real_address = 0;
	// synopsys translate_on
	always @ ( posedge dpclk )
		if (pre_amble_cmpr_aeb) real_address <= (({8{is_pcs_address}} & odd_addr_trans_result) | ({8{(~ is_pcs_address)}} & addr_shift_reg[7:0]));
		else real_address <= {real_address[6:0], 1'b0};
	// synopsys translate_off
	initial
		startup_cntr = 3'b000;
	// synopsys translate_on
	always @ ( posedge dpclk)
		if (startup_cntr_ena) startup_cntr <= startup_cntr_d;
	assign
		startup_cntr_d = {(startup_cntr[2] ^ (startup_cntr[1] & startup_cntr[0])), (startup_cntr[0] ^ startup_cntr[1]), (~ startup_cntr[0])};
	assign
		startup_cntr_ena = (((rden | wren) | (~ startup_idle)) & (~ startup_done));
	// synopsys translate_off
	initial
		state_mc_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk )
		state_mc_reg <= {(s2_to_1 | (((~ s2_to_0) & (~ s2_to_1)) & state_mc_reg[2])), (s1_to_1 | (((~ s1_to_0) & (~ s1_to_1)) & state_mc_reg[1])), (s0_to_1 | (((~ s0_to_0) & (~ s0_to_1)) & state_mc_reg[0]))};
	// synopsys translate_off
	initial
		wr_out_data_shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge dpclk )
		if (pre_amble_cmpr_aeb) wr_out_data_shift_reg <= {{2{1'b0}}, 2'b01, {4{1'b0}}, quad_address, 2'b10, datain};
		else wr_out_data_shift_reg <= {wr_out_data_shift_reg[30:0], 1'b0};

	lpm_add_sub   odd_addr_trans
	( 
	.add_sub(is_pcs_address),
	.cout(),
	.dataa(addr_shift_reg[7:0]),
	.datab(8'b00000001),
	.overflow(),
	.result(odd_addr_trans_result)
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
		odd_addr_trans.lpm_width = 8,
		odd_addr_trans.lpm_type = "lpm_add_sub",
		odd_addr_trans.lpm_hint = "ONE_INPUT_IS_CONSTANT=YES";
	
	lpm_compare   pre_amble_cmpr
	( 
	.aeb(pre_amble_cmpr_aeb),
	.agb(pre_amble_cmpr_agb),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(state_mc_counter_q),
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
	.ageb(rd_data_output_cmpr_ageb),
	.alb(rd_data_output_cmpr_alb),
	.aleb(),
	.aneb(),
	.dataa(state_mc_counter_q),
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
	.aeb(state_mc_cmpr_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(state_mc_counter_q),
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
	.q(state_mc_counter_q)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.sclr(1'b0),
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
	.eq(state_mc_decode_eq)
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
	
	or(dprioin_mux_dataout, ((((((wr_addr_state | rd_addr_state) & addr_shift_reg[31]) & pre_amble_cmpr_agb) | ((~ pre_amble_cmpr_agb) & (wr_addr_state | rd_addr_state))) | (((wr_data_state & wr_out_data_shift_reg[31]) & pre_amble_cmpr_agb) | ((~ pre_amble_cmpr_agb) & wr_data_state))) | (((rd_data_output_state & rd_out_data_shift_reg[15]) & pre_amble_cmpr_agb) | ((~ pre_amble_cmpr_agb) & rd_data_output_state))), ~(((write_state | rd_addr_state) | rd_data_output_state)));

	assign
		address_in = address,
		busy = busy_state,
		busy_state = (write_state | read_state),
		dataout = in_data_shift_reg,
		dpriodisable = (~ (startup_cntr[2] & (startup_cntr[0] | startup_cntr[1]))),
		dprioin = dprioin_mux_dataout,
		dprioload = (~ ((startup_cntr[0] ^ startup_cntr[1]) & (~ startup_cntr[2]))),
		idle_state = state_mc_decode_eq[0],
		rd_addr_done = (rd_addr_state & state_mc_cmpr_aeb),
		rd_addr_state = (state_mc_decode_eq[5] & startup_done),
		rd_data_done = (rd_data_state & state_mc_cmpr_aeb),
		rd_data_input_state = (rd_data_output_cmpr_ageb & rd_data_state),
		rd_data_output_state = (rd_data_output_cmpr_alb & rd_data_state),
		rd_data_state = (state_mc_decode_eq[7] & startup_done),
		read_state = (rd_addr_state | rd_data_state),
		s0_to_0 = ((wr_data_state & wr_data_done) | (rd_data_state & rd_data_done)),
		s0_to_1 = (((idle_state & (wren | ((~ wren) & (rden | wren_data)))) | (wr_addr_state & wr_addr_done)) | (rd_addr_state & rd_addr_done)),
		s1_to_0 = (((wr_data_state & wr_data_done) | (rd_data_state & rd_data_done)) | (idle_state & (wren | (((~ wren) & (~ wren_data)) & rden)))),
		s1_to_1 = (((idle_state & ((~ wren) & wren_data)) | (wr_addr_state & wr_addr_done)) | (rd_addr_state & rd_addr_done)),
		s2_to_0 = ((((wr_addr_state & wr_addr_done) | (wr_data_state & wr_data_done)) | (rd_data_state & rd_data_done)) | (idle_state & (wren | wren_data))),
		s2_to_1 = ((idle_state & (((~ wren) & (~ wren_data)) & rden)) | (rd_addr_state & rd_addr_done)),
		startup_done = ((startup_cntr[2] & (~ startup_cntr[0])) & startup_cntr[1]),
		startup_idle = ((~ startup_cntr[0]) & (~ (startup_cntr[2] ^ startup_cntr[1]))),
		status_out = {rd_data_done, rd_addr_done, wr_data_done, wr_addr_done},
		wr_addr_done = (wr_addr_state & state_mc_cmpr_aeb),
		wr_addr_state = (state_mc_decode_eq[1] & startup_done),
		wr_data_done = (wr_data_state & state_mc_cmpr_aeb),
		wr_data_state = (state_mc_decode_eq[3] & startup_done),
		write_state = (wr_addr_state | wr_data_state);
endmodule //gxb_reconfig_alt_dprio

//synthesis_resources = lpm_add_sub 2 lpm_compare 9 lpm_counter 2 lpm_decode 2 lut 2 reg 164 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"{-to address_pres_reg[7]} DPRIO_CHANNEL_NUM=7;{-to address_pres_reg[6]} DPRIO_CHANNEL_NUM=6;{-to address_pres_reg[5]} DPRIO_CHANNEL_NUM=5;{-to address_pres_reg[4]} DPRIO_CHANNEL_NUM=4;{-to address_pres_reg[3]} DPRIO_CHANNEL_NUM=3;{-to address_pres_reg[2]} DPRIO_CHANNEL_NUM=2;{-to address_pres_reg[1]} DPRIO_CHANNEL_NUM=1;{-to address_pres_reg[0]} DPRIO_CHANNEL_NUM=0;{-to cru_num_reg[2]} DPRIO_CRUCLK_NUM=2;{-to cru_num_reg[1]} DPRIO_CRUCLK_NUM=1;{-to cru_num_reg[0]} DPRIO_CRUCLK_NUM=0;{-to le6} IMPLEMENT_AS_CLOCK_ENABLE = ON;{-to tx_cmu_sel[0]}  DPRIO_TX_PLL_NUM=0"} *)
module gxb_reconfig
	( 
	busy,
	reconfig_address_out,
	reconfig_clk,
	reconfig_data,
	reconfig_fromgxb,
	reconfig_mode_sel,
	reconfig_togxb,
	write_all);
	output   busy;
	output   [4:0]  reconfig_address_out;
	input   reconfig_clk;
	input   [15:0]  reconfig_data;
	input   [0:0]  reconfig_fromgxb;
	input   [2:0]  reconfig_mode_sel;
	output   [2:0]  reconfig_togxb;
	input   write_all;

	wire  dprio_busy;
	wire  [15:0]   dprio_dataout;
	wire  [3:0]   dprio_status_out;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON"} *)
	reg	[7:0]	address_pres_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	cru_num_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	delay_mif_head;
	wire	delay_mif_head_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	dprio_dataout_reg;
	wire	dprio_dataout_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	dprio_pulse_reg;
	wire	dprio_pulse_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	mif_stage;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[2:0]	reconf_mode_sel_reg;
	wire	reconf_mode_sel_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[15:0]	reconfig_data_reg;
	wire	reconfig_data_reg_ena;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	[0:0]	state_mc_reg;
	(* ALTERA_ATTRIBUTE = {"PRESERVE_REGISTER=ON; PRESERVE_FANOUT_FREE_NODE=ON;POWER_UP_LEVEL=LOW"} *)
	reg	[0:0]	tx_cmu_sel;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	wr_addr_inc_reg;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
	reg	wr_rd_pulse_reg;
	wire	wr_rd_pulse_reg_ena;
	wire  [5:0]   mif_addr_trans_result;
	wire  cmpr_mif_sec_agb;
	wire  is_cru_idx0_aeb;
	wire  is_cru_idx1_aeb;
	wire  is_end_mif_word_aeb;
	wire  is_end_mif_word_agb;
	wire  is_rcxpat_chnl_en_ch_word_aeb;
	wire  is_special_address_aeb;
	wire  [4:0]   mif_addr_cntr_q;
	wire  [7:0]   reconf_mode_dec_eq;
	wire  [7:0]  a2gr_dprio_addr;
	wire  [15:0]  a2gr_dprio_data;
	wire  a2gr_dprio_rden;
	wire  a2gr_dprio_wren;
	wire  a2gr_dprio_wren_data;
	wire  [1:0]  channel_address;
	wire  [1:0]  channel_address_out;
	wire  [2:0]  cruclk_addr1_msb_in;
	wire  [15:0]  cruclk_mux_data;
	wire  delay_mif_head_out;
	wire  delay_second_mif_head_out;
	wire  [15:0]  dprio_datain;
	wire  dprio_pulse;
	wire  dprio_wr_done;
	wire  en_mif_addr_cntr;
	wire  en_write_trigger;
	wire  header_proc;
	wire  idle_state;
	wire  is_analog_control;
	wire  is_ch_reconf_end;
	wire  is_cruclk_addr0;
	wire  is_cruclk_addr1;
	wire  is_diff_mif;
	wire  is_do_dfe;
	wire  is_end_mif;
	wire  is_mif_header;
	wire  is_pll_addr;
	wire  is_pll_reset_stage;
	wire  is_pma;
	wire  is_rcxpat_chnl_en_ch;
	wire  is_tier_1;
	wire  is_tx_local_div_ctrl;
	wire  legal_wr_mode_type;
	wire  load_mif_header;
	wire  [15:0]  merged_dprioin;
	wire  [5:0]  mif_dec_datab;
	wire  [7:0]  pll_reset_addr;
	wire  [5:0]  quad_address;
	wire  [5:0]  quad_address_out;
	wire  rd_pulse;
	wire  [15:0]  reconfig_datain;
	wire  s0_to_0;
	wire  s0_to_1;
	wire  [0:0]  state_mc_reg_in;
	wire  [4:0]  tx_switch_rate_addr;
	wire  wr_pulse;
	wire  [7:0]  write_address;
	wire  write_all_int;
	wire  write_done;
	wire  write_happened;
	wire  write_mif_word_done;
	wire  [7:0]  write_reconfig_addr;
	wire  write_state;

	gxb_reconfig_alt_dprio dprio
	( 
	.address(a2gr_dprio_addr),
	.busy(dprio_busy),
	.datain(a2gr_dprio_data),
	.dataout(dprio_dataout),
	.dpclk(reconfig_clk),
	.dprioin(reconfig_togxb[0]),
	.dpriodisable(reconfig_togxb[1]),
	.dprioload(reconfig_togxb[2]),
	.dprioout(reconfig_fromgxb),
	.is_pcs_address(((~ is_pma) & (~ is_analog_control))),
	.quad_address(quad_address_out),
	.rden(a2gr_dprio_rden),
	.status_out(dprio_status_out),
	.wren(a2gr_dprio_wren),
	.wren_data(a2gr_dprio_wren_data));

	// synopsys translate_off
	initial
		address_pres_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		address_pres_reg <= {quad_address, channel_address};
	// synopsys translate_off
	initial
		cru_num_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (load_mif_header) cru_num_reg <= reconfig_data_reg[15:13];
	// synopsys translate_off
	initial
		delay_mif_head = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (delay_mif_head_ena) delay_mif_head <= (is_mif_header & is_tier_1);
	assign
		delay_mif_head_ena = (((write_state & (~ write_mif_word_done))));
	// synopsys translate_off
	initial
		dprio_dataout_reg = 16'b0000000000000000;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (dprio_dataout_reg_ena) dprio_dataout_reg <= dprio_dataout;
	assign
		dprio_dataout_reg_ena = (dprio_pulse & (~ idle_state));
	// synopsys translate_off
	initial
		dprio_pulse_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (dprio_pulse_reg_ena) dprio_pulse_reg <= dprio_busy;
	assign
		dprio_pulse_reg_ena = write_state;
	// synopsys translate_off
	initial
		mif_stage = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if  (is_tier_1) 
			mif_stage <= (((~ mif_stage) & is_mif_header) | ((~ (is_mif_header & dprio_pulse)) & mif_stage));
	// synopsys translate_off
	initial
		reconf_mode_sel_reg = 3'b000;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (reconf_mode_sel_reg_ena) reconf_mode_sel_reg <= reconfig_mode_sel;
	assign
		reconf_mode_sel_reg_ena = (idle_state & (~ mif_stage));
	// synopsys translate_off
	initial
		reconfig_data_reg = 16'b0000000000000000;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (reconfig_data_reg_ena) reconfig_data_reg <= reconfig_data;
	assign
		reconfig_data_reg_ena = (idle_state & write_all);
	// synopsys translate_off
	initial
		state_mc_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		state_mc_reg <= state_mc_reg_in;
	// synopsys translate_off
	initial
		tx_cmu_sel = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if ((is_cruclk_addr1 & (~ write_mif_word_done)) | (reconf_mode_dec_eq[4] & is_mif_header))
			tx_cmu_sel <= (((~ reconf_mode_dec_eq[4]) & reconfig_data_reg[13]) | (reconf_mode_dec_eq[4] & reconfig_data_reg[6]));
	// synopsys translate_off
	initial
		wr_addr_inc_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		wr_addr_inc_reg <= (wr_pulse | (((~ wr_pulse) & (~ rd_pulse)) & wr_addr_inc_reg));
	// synopsys translate_off
	initial
		wr_rd_pulse_reg = 0;
	// synopsys translate_on
	always @ ( posedge reconfig_clk )
		if (wr_rd_pulse_reg_ena) 
			wr_rd_pulse_reg <= (~ wr_rd_pulse_reg);
	assign
		wr_rd_pulse_reg_ena = ((dprio_pulse & ((~ is_tier_1) | (is_tier_1 & (((is_end_mif & (~ write_done)) | is_mif_header) | is_pll_addr)))));

	lpm_add_sub   mif_addr_trans
	( 
	.add_sub(is_pma),
	.cout(),
	.dataa({{1{1'b0}}, (({5{is_tx_local_div_ctrl}} & tx_switch_rate_addr) | ({5{(~ is_tx_local_div_ctrl)}} & mif_addr_cntr_q))}),
	.datab(mif_dec_datab),
	.overflow(),
	.result(mif_addr_trans_result)
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
		mif_addr_trans.lpm_width = 6,
		mif_addr_trans.lpm_type = "lpm_add_sub";

	lpm_compare   cmpr_mif_sec
	( 
	.aeb(),
	.agb(cmpr_mif_sec_agb),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa((({5{is_tx_local_div_ctrl}} & tx_switch_rate_addr) | ({5{(~ is_tx_local_div_ctrl)}} & mif_addr_cntr_q))),
	.datab(5'b10000)
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
		cmpr_mif_sec.lpm_width = 5,
		cmpr_mif_sec.lpm_type = "lpm_compare";

	lpm_compare   is_cru_idx0
	( 
	.aeb(is_cru_idx0_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(mif_addr_cntr_q),
	.datab(5'b10110)
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

	lpm_compare   is_cru_idx1
	( 
	.aeb(is_cru_idx1_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(mif_addr_cntr_q),
	.datab(5'b10100)
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
		is_cru_idx1.lpm_width = 5,
		is_cru_idx1.lpm_type = "lpm_compare";

	lpm_compare   is_end_mif_word
	( 
	.aeb(is_end_mif_word_aeb),
	.agb(is_end_mif_word_agb),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(mif_addr_cntr_q),
	.datab(5'b11011)
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
		is_end_mif_word.lpm_width = 5,
		is_end_mif_word.lpm_type = "lpm_compare";

	lpm_compare   is_rcxpat_chnl_en_ch_word
	( 
	.aeb(is_rcxpat_chnl_en_ch_word_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(mif_addr_cntr_q),
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
		is_rcxpat_chnl_en_ch_word.lpm_width = 5,
		is_rcxpat_chnl_en_ch_word.lpm_type = "lpm_compare";

	lpm_compare   is_special_address
	( 
	.aeb(is_special_address_aeb),
	.agb(),
	.ageb(),
	.alb(),
	.aleb(),
	.aneb(),
	.dataa(mif_addr_cntr_q),
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
		is_special_address.lpm_width = 5,
		is_special_address.lpm_type = "lpm_compare";

	lpm_counter   mif_addr_cntr
	( 
	.clock(reconfig_clk),
	.cnt_en(((en_mif_addr_cntr | ((is_mif_header & write_state) & (~ dprio_pulse))) & is_tier_1)),
	.cout(),
	.eq(),
	.q(mif_addr_cntr_q),
	.sclr((is_ch_reconf_end & dprio_wr_done))
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.aclr(1'b0),
	.aload(1'b0),
	.aset(1'b0),
	.cin(1'b1),
	.clk_en(1'b1),
	.data({5{1'b0}}),
	.sload(1'b0),
	.sset(1'b0),
	.updown(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		mif_addr_cntr.lpm_modulus = 28,
		mif_addr_cntr.lpm_port_updown = "PORT_UNUSED",
		mif_addr_cntr.lpm_width = 5,
		mif_addr_cntr.lpm_type = "lpm_counter";

	lpm_decode   reconf_mode_dec
	( 
	.data(reconf_mode_sel_reg),
	.enable(((~ idle_state) | mif_stage)),
	.eq(reconf_mode_dec_eq)
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

	assign
		a2gr_dprio_addr = (((write_address & {8{is_analog_control}}) | ({8{(~ is_analog_control)}} & write_reconfig_addr)) & {8{write_state}}),
		a2gr_dprio_data = dprio_datain,
		a2gr_dprio_rden = rd_pulse,
		a2gr_dprio_wren = wr_pulse,
		a2gr_dprio_wren_data = 1'b0,
		busy = write_state,
		channel_address = {2{1'b0}},
		channel_address_out = address_pres_reg[1:0],
		cruclk_addr1_msb_in = {reconfig_data_reg[15:14], tx_cmu_sel},
		cruclk_mux_data = {(((cru_num_reg & {3{(~ (cru_num_reg[1] & cru_num_reg[2]))}}) & {3{is_cruclk_addr0}}) | (cruclk_addr1_msb_in & {3{(~ is_cruclk_addr0)}})), reconfig_data_reg[12:2], (((~ (cru_num_reg[2] & cru_num_reg[1])) & is_cruclk_addr1) | ((~ is_cruclk_addr1) & reconfig_data_reg[1])), (((~ ((cru_num_reg[2] & cru_num_reg[1]) & (~ cru_num_reg[0]))) & is_cruclk_addr1) | ((~ is_cruclk_addr1) & reconfig_data_reg[0]))},
		delay_mif_head_out = delay_mif_head,
		delay_second_mif_head_out = 1'b0,
		dprio_datain = {16{(is_tier_1 | is_tx_local_div_ctrl)}} & reconfig_datain,
		dprio_pulse = ((dprio_pulse_reg ^ dprio_busy) & (~ dprio_busy)),
		dprio_wr_done = dprio_status_out[1],
		en_mif_addr_cntr = (((write_state & dprio_wr_done) & write_happened)),
		en_write_trigger = legal_wr_mode_type,
		header_proc = ((((delay_mif_head | is_mif_header) | delay_second_mif_head_out)) & is_tier_1),
		idle_state = (~ state_mc_reg),
		is_analog_control = reconf_mode_dec_eq[0],
		is_ch_reconf_end = (is_end_mif & (reconf_mode_dec_eq[1] | reconf_mode_dec_eq[6])),
		is_cruclk_addr0 = (is_cru_idx0_aeb & is_tier_1),
		is_cruclk_addr1 = (is_cru_idx1_aeb & is_tier_1),
		is_diff_mif = 1'b0,
		is_end_mif = (is_end_mif_word_aeb & is_tier_1),
		is_mif_header = is_special_address_aeb,
		is_pll_addr = (is_end_mif_word_agb & is_tier_1),
		is_pll_reset_stage = 1'b0,
		is_pma = cmpr_mif_sec_agb,
		is_rcxpat_chnl_en_ch = (is_rcxpat_chnl_en_ch_word_aeb & is_tier_1),
		is_tier_1 = (((reconf_mode_dec_eq[1] | reconf_mode_dec_eq[6]) | reconf_mode_dec_eq[4]) | reconf_mode_dec_eq[5]),
		is_tx_local_div_ctrl = reconf_mode_dec_eq[3],
		legal_wr_mode_type = ((reconfig_mode_sel[2] & (~ (reconfig_mode_sel[1] & reconfig_mode_sel[0]))) | (((~ reconfig_mode_sel[2]) & reconfig_mode_sel[0]) & (~ reconfig_mode_sel[1]))),
		load_mif_header = ((is_mif_header & (~ write_mif_word_done)) & is_tier_1),
		merged_dprioin = {(({4{is_end_mif}} & dprio_dataout_reg[15:12]) | ({4{(~ is_end_mif)}} & reconfig_data_reg[15:12])), reconfig_data_reg[11:5], ((is_rcxpat_chnl_en_ch & dprio_dataout_reg[4]) | ((~ is_rcxpat_chnl_en_ch) & reconfig_data_reg[4])), (((is_rcxpat_chnl_en_ch | is_end_mif) & dprio_dataout_reg[3]) | (((~ is_rcxpat_chnl_en_ch) & (~ is_end_mif)) & reconfig_data_reg[3])), ((is_end_mif & dprio_dataout_reg[2]) | ((~ is_end_mif) & reconfig_data_reg[2])), reconfig_data_reg[1:0]},
		mif_dec_datab = {1'b0, {2{is_pll_addr}}, is_pma, (is_pma & (~ is_pll_addr)), 1'b1},
		pll_reset_addr = 8'b10010100,
		quad_address = {6{1'b0}},
		quad_address_out = address_pres_reg[7:2],
		rd_pulse = (((((~ dprio_pulse) & (~ write_done)) & (~ wr_rd_pulse_reg))) & (write_state & (((~ header_proc)) & (((~ is_tier_1) | is_end_mif) | is_pll_addr)))),
		reconfig_address_out = mif_addr_cntr_q,
		reconfig_datain = ((({16{(is_cruclk_addr0 | is_cruclk_addr1)}} & cruclk_mux_data) | (({16{(~ is_tx_local_div_ctrl)}} & merged_dprioin) & {16{(~ ((is_cruclk_addr0 | is_cruclk_addr1) | is_pll_reset_stage))}})) | ({16{(is_tx_local_div_ctrl | is_pll_reset_stage)}} & dprio_dataout_reg)),
		s0_to_0 = write_done,
		s0_to_1 = (write_all_int & idle_state),
		state_mc_reg_in = (s0_to_1 | ((((~ s0_to_1)) & (~ s0_to_0)) & state_mc_reg[0])),
		tx_switch_rate_addr = 5'b10100,
		wr_pulse = ((((write_state & (~ dprio_pulse)) & (~ write_done)) & ((wr_rd_pulse_reg & (((~ is_tier_1) | is_end_mif) | is_pll_addr)) | ((((is_tier_1 & (~ header_proc))) & (~ is_end_mif)) & (~ is_pll_addr))))),
		write_address = {{6{1'b0}}, channel_address_out},
		write_all_int = (write_all & en_write_trigger),
		write_done = ((((((((delay_mif_head_out | delay_second_mif_head_out) | write_mif_word_done) | (is_diff_mif & is_end_mif)))) | ((dprio_pulse & write_happened) & is_tx_local_div_ctrl)))),
		write_happened = wr_addr_inc_reg,
		write_mif_word_done = ((dprio_pulse & write_happened) & is_tier_1),
		write_reconfig_addr = {(({6{((((is_tier_1 & (~ is_mif_header)) & (~ is_pll_reset_stage))) | is_tx_local_div_ctrl)}} & mif_addr_trans_result[5:0]) | ({6{is_pll_reset_stage}} & pll_reset_addr[7:2])), ((({2{(~ is_pll_addr)}} & channel_address_out) | ({2{(is_pll_addr & (~ is_pll_reset_stage))}} & mif_addr_cntr_q[1:0])) | ({2{is_pll_reset_stage}} & pll_reset_addr[1:0]))},
		write_state = state_mc_reg;
endmodule //gxb_reconfig
