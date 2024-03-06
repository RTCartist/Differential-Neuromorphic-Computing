# Copyright (C) 2020  Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions 
# and other software and tools, and any partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License 
# Subscription Agreement, the Intel Quartus Prime License Agreement,
# the Intel FPGA IP License Agreement, or other applicable license
# agreement, including, without limitation, that your use is for
# the sole purpose of programming logic devices manufactured by
# Intel and sold by Intel or its authorized distributors.  Please
# refer to the applicable agreement for further details, at
# https://fpgasoftware.intel.com/eula.

# Quartus Prime Version 20.1.0 Build 711 06/05/2020 SJ Lite Edition
# File: F:\shengbowang_v3\repo\Differential-Neuromorphic-Computing\Tactile\Hardware\Configuration\mem_frame_1ch.tcl
# Generated on: Sun Mar 03 16:25:18 2024

package require ::quartus::project

set_location_assignment PIN_E6 -to ADC_RST_o
set_location_assignment PIN_D4 -to CONVST_o
set_location_assignment PIN_C3 -to adc_sclk_o
set_location_assignment PIN_B13 -to adc_sdi_i
set_location_assignment PIN_D5 -to adc_sdo_o
set_location_assignment PIN_A13 -to RVS_i
set_location_assignment PIN_R12 -to dac_data_o[0]
set_location_assignment PIN_T13 -to dac_data_o[1]
set_location_assignment PIN_T14 -to dac_data_o[2]
set_location_assignment PIN_N6 -to dac_data_o[3]
set_location_assignment PIN_M8 -to dac_data_o[4]
set_location_assignment PIN_L9 -to dac_data_o[6]
set_location_assignment PIN_P8 -to dac_data_o[5]
set_location_assignment PIN_M9 -to dac_data_o[7]
set_location_assignment PIN_L10 -to dac_clk_o
set_location_assignment PIN_M1 -to rst_n_i
set_location_assignment PIN_E1 -to clk_i
set_location_assignment PIN_F8 -to ctrl_switch_o[0]
set_location_assignment PIN_E7 -to ctrl_switch_o[1]
set_location_assignment PIN_C6 -to ctrl_switch_o[2]
set_location_assignment PIN_D6 -to ctrl_switch_o[3]
set_location_assignment PIN_A12 -to piezo_col_o[0]
set_location_assignment PIN_A11 -to piezo_col_o[1]
set_location_assignment PIN_B12 -to piezo_row_o[0]
set_location_assignment PIN_B11 -to piezo_row_o[1]
set_location_assignment PIN_K9 -to sel_d1_o
set_location_assignment PIN_N8 -to sel_d0_o
set_location_assignment PIN_R13 -to sel_a_o
set_location_assignment PIN_R14 -to sel_b_o
set_location_assignment PIN_P6 -to sel_c_o
set_location_assignment PIN_E9 -to mem_out_en0_o
set_location_assignment PIN_D9 -to mem_out_en1_o
set_location_assignment PIN_C8 -to mem_out_sel_o[0]
set_location_assignment PIN_D8 -to mem_out_sel_o[1]
set_location_assignment PIN_E8 -to mem_out_sel_o[2]
set_location_assignment PIN_T7 -to FIFOadr_o[1]
set_location_assignment PIN_R7 -to FIFOadr_o[0]
set_location_assignment PIN_T11 -to cy_empty_i
set_location_assignment PIN_R11 -to cy_full_i
set_location_assignment PIN_T10 -to pktend_o
set_location_assignment PIN_R6 -to slcs_o
set_location_assignment PIN_R10 -to sloe_o
set_location_assignment PIN_R9 -to slrwr_o
set_location_assignment PIN_T6 -to USB_data[0]
set_location_assignment PIN_R5 -to USB_data[1]
set_location_assignment PIN_T5 -to USB_data[2]
set_location_assignment PIN_R4 -to USB_data[3]
set_location_assignment PIN_T4 -to USB_data[4]
set_location_assignment PIN_T9 -to USB_data[5]
set_location_assignment PIN_R8 -to USB_data[6]
set_location_assignment PIN_T8 -to USB_data[7]
set_location_assignment PIN_P9 -to dac_data_o[8]
set_location_assignment PIN_N9 -to dac_data_o[9]
set_location_assignment PIN_M7 -to TX
