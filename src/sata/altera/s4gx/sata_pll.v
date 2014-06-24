
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

module sata_pll (
	inclk,
	reconf_clk,
	reset,
	sata_gen,
	reconfig,
	busy,
	outclk,
	locked);

	input inclk;
	input reconf_clk;
	input reset;
	input [1:0] sata_gen;
	input reconfig;
	output busy;
	output outclk;
	output locked;

	wire reconf_busy;
	wire pll_areset;
	wire pll_scanclk;
	wire pll_scanclkena;
	wire pll_scandata;
	wire pll_scandone;
	wire pll_configupdate;
	wire [9:0] pll_clk_bus;
	wire [2:0] counter_param;
	wire [8:0] data_in;
	wire write_param;

	reg [1:0] sata_genreg;
	reg [6:0] state;

	parameter IDLE           = 7'b0000001;
	parameter SET_C0_LOW     = 7'b0000010;
	parameter WAIT_C0_LOW    = 7'b0000100;
	parameter SET_C0_HIGH    = 7'b0001000;
	parameter WAIT_C0_HIGH   = 7'b0010000;
	parameter START_RECONFIG = 7'b0100000;
	parameter WAIT_RECONFIG  = 7'b1000000;

	assign outclk = pll_clk_bus[0];
	assign busy = (state != IDLE);

	assign data_in = sata_genreg[1] ? 9'b000000010 : sata_genreg[0] ? 9'b000000100 : 9'b000001000;
	assign counter_param = (state == SET_C0_LOW) ? 3'b001 :  3'b000;
	assign write_param = (state == SET_C0_LOW) | (state == SET_C0_HIGH);

	// PLL re-configuration state machine
	initial state <= IDLE;
	always @ (posedge reconf_clk)
	begin
		case (state)
			IDLE:           if (reconfig) begin sata_genreg <= sata_gen; state <= SET_C0_LOW; end
			SET_C0_LOW:     state <= WAIT_C0_LOW;
			WAIT_C0_LOW:    if (~reconf_busy) state <= SET_C0_HIGH;
			SET_C0_HIGH:    state <= WAIT_C0_HIGH;
			WAIT_C0_HIGH:   if (~reconf_busy) state <= START_RECONFIG;
			START_RECONFIG: state <= WAIT_RECONFIG;
			WAIT_RECONFIG:  if (~reconf_busy) state <= IDLE;
		endcase
	end

	altpll pll (
		.inclk ({1'b0,inclk}),
		.clk (pll_clk_bus),
		.locked (locked),
		.activeclock (),
		.areset (pll_areset),
		.clkbad (),
		.clkena (6'b111111),
		.clkloss (),
		.clkswitch (1'b0),
		.configupdate (pll_configupdate),
		.enable0 (),
		.enable1 (),
		.extclk (),
		.extclkena (4'b1111),
		.fbin (1'b1),
		.fbmimicbidir (),
		.fbout (),
		.fref (),
		.icdrclk (),
		.pfdena (1'b1),
		.phasecounterselect (4'b1111),
		.phasedone (),
		.phasestep (1'b1),
		.phaseupdown (1'b1),
		.pllena (1'b1),
		.scanaclr (1'b0),
		.scanclk (pll_scanclk),
		.scanclkena (pll_scanclkena),
		.scandata (pll_scandata),
		.scandone (pll_scandone),
		.sclkout0 (),
		.sclkout1 (),
		.vcooverrange (),
		.vcounderrange ());
	defparam
		pll.bandwidth_type = "HIGH",
		pll.clk0_divide_by = 1,
		pll.clk0_duty_cycle = 50,
		pll.clk0_multiply_by = 1,
		pll.clk0_phase_shift = "0",
		pll.compensate_clock = "CLK0",
		pll.inclk0_input_frequency = 6666,
		pll.intended_device_family = "Stratix IV",
		pll.lpm_hint = "CBX_MODULE_PREFIX=sata_pll",
		pll.lpm_type = "altpll",
		pll.operation_mode = "NORMAL",
		pll.pll_type = "Left_Right",
		pll.port_activeclock = "PORT_UNUSED",
		pll.port_areset = "PORT_USED",
		pll.port_clkbad0 = "PORT_UNUSED",
		pll.port_clkbad1 = "PORT_UNUSED",
		pll.port_clkloss = "PORT_UNUSED",
		pll.port_clkswitch = "PORT_UNUSED",
		pll.port_configupdate = "PORT_USED",
		pll.port_fbin = "PORT_UNUSED",
		pll.port_inclk0 = "PORT_USED",
		pll.port_inclk1 = "PORT_UNUSED",
		pll.port_locked = "PORT_USED",
		pll.port_pfdena = "PORT_UNUSED",
		pll.port_phasecounterselect = "PORT_UNUSED",
		pll.port_phasedone = "PORT_UNUSED",
		pll.port_phasestep = "PORT_UNUSED",
		pll.port_phaseupdown = "PORT_UNUSED",
		pll.port_pllena = "PORT_UNUSED",
		pll.port_scanaclr = "PORT_UNUSED",
		pll.port_scanclk = "PORT_USED",
		pll.port_scanclkena = "PORT_USED",
		pll.port_scandata = "PORT_USED",
		pll.port_scandataout = "PORT_UNUSED",
		pll.port_scandone = "PORT_USED",
		pll.port_scanread = "PORT_UNUSED",
		pll.port_scanwrite = "PORT_UNUSED",
		pll.port_clk0 = "PORT_USED",
		pll.port_clk1 = "PORT_UNUSED",
		pll.port_clk2 = "PORT_UNUSED",
		pll.port_clk3 = "PORT_UNUSED",
		pll.port_clk4 = "PORT_UNUSED",
		pll.port_clk5 = "PORT_UNUSED",
		pll.port_clk6 = "PORT_UNUSED",
		pll.port_clk7 = "PORT_UNUSED",
		pll.port_clk8 = "PORT_UNUSED",
		pll.port_clk9 = "PORT_UNUSED",
		pll.port_clkena0 = "PORT_UNUSED",
		pll.port_clkena1 = "PORT_UNUSED",
		pll.port_clkena2 = "PORT_UNUSED",
		pll.port_clkena3 = "PORT_UNUSED",
		pll.port_clkena4 = "PORT_UNUSED",
		pll.port_clkena5 = "PORT_UNUSED",
		pll.using_fbmimicbidir_port = "OFF",
		pll.width_clock = 10,
		pll.scan_chain_mif_file = "sata_pll.mif";

	sata_pll_reconfig reconf (
		.clock(reconf_clk),
		.counter_param(counter_param),
		.counter_type(4'b0100),
		.data_in(data_in),
		.pll_scanclk(pll_scanclk),
		.pll_scanclkena(pll_scanclkena),
		.pll_scandata(pll_scandata),
		.pll_scandone(pll_scandone),
		.pll_configupdate(pll_configupdate),
		.pll_areset(pll_areset),
		.pll_areset_in(reset),
		.reconfig((state == START_RECONFIG)),
		.write_param(write_param),
		.busy(reconf_busy));

endmodule
