-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;

-- Usage
-- ====================================
-- LIBRARY	PoC;
-- USE			PoC.Xilinx.ALL;

PACKAGE xil IS
	-- ChipScope
	-- ==========================================================================
	SUBTYPE	T_XIL_CHIPSCOPE_CONTROL IS STD_LOGIC_VECTOR(35 DOWNTO 0);
	TYPE		T_XIL_CHIPSCOPE_CONTROL_VECTOR IS ARRAY (NATURAL RANGE <>) OF T_XIL_CHIPSCOPE_CONTROL;

	-- Dynamic Reconfiguration Port (DRP)
	-- ==========================================================================
	SUBTYPE T_XIL_DRP_ADDRESS						IS T_SLV_16;
	SUBTYPE T_XIL_DRP_DATA							IS T_SLV_16;

	TYPE		T_XIL_DRP_ADDRESS_VECTOR						IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_ADDRESS;
	TYPE		T_XIL_DRP_DATA_VECTOR								IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_DATA;

	TYPE T_XIL_DRP_CONFIG IS RECORD
		Address														: T_XIL_DRP_ADDRESS;
		Mask															: T_XIL_DRP_DATA;
		Data															: T_XIL_DRP_DATA;
	END RECORD;
	
	-- define array indices
	CONSTANT C_XIL_DRP_MAX_CONFIG_COUNT		: POSITIVE	:= 8;
	SUBTYPE T_XIL_DRP_CONFIG_INDEX			IS INTEGER RANGE 0 TO C_XIL_DRP_MAX_CONFIG_COUNT - 1;
	TYPE		T_XIL_DRP_CONFIG_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_CONFIG;
	
	TYPE T_XIL_DRP_CONFIG_SET IS RECORD
		Configs														: T_XIL_DRP_CONFIG_VECTOR(T_XIL_DRP_CONFIG_INDEX);
		LastIndex													: T_XIL_DRP_CONFIG_INDEX;
	END RECORD;
	
	TYPE T_XIL_DRP_CONFIG_ROM						IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_CONFIG_SET;
	
	CONSTANT C_XIL_DRP_CONFIG_EMPTY			: T_XIL_DRP_CONFIG				:= (
		Address =>	(OTHERS => '0'),
		Data =>			(OTHERS => '0'),
		Mask =>			(OTHERS => '0')
	);

	CONSTANT C_XIL_DRP_CONFIG_SET_EMPTY	: T_XIL_DRP_CONFIG_SET		:= (
		Configs		=> (OTHERS => C_XIL_DRP_CONFIG_EMPTY),
		LastIndex	=> 0
	);

	component xil_ChipScopeICON_1 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_2 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_3 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_4 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_5 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_6 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_7 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_8 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_9 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_10 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_11 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control10						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_12 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control10						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control11						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_13 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control10						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control11						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control12						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;

	component xil_ChipScopeICON_14 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control10						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control11						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control12						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control13						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;
	
	component xil_ChipScopeICON_15 is
		port (
			control0						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control1						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control2						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control3						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control4						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control5						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control6						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control7						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control8						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control9						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control10						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control11						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control12						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control13						: inout	T_XIL_CHIPSCOPE_CONTROL;
			control14						: inout	T_XIL_CHIPSCOPE_CONTROL
		);
	end component;
	
	COMPONENT xil_SystemMonitor_Virtex6 IS
		PORT (
			Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
			
			Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
			Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
			Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
			VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
			VN									: IN	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT xil_SystemMonitor_Series7 IS
		PORT (
			Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
			
			Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
			Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
			Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
			VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
			VN									: IN	STD_LOGIC
		);
	END COMPONENT;
END;


PACKAGE BODY xil IS

END PACKAGE BODY;
