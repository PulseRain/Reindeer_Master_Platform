/*
###############################################################################
# Copyright (c) 2019, PulseRain Technology LLC 
#
# This program is distributed under a dual license: an open source license, 
# and a commercial license. 
# 
# The open source license under which this program is distributed is the 
# GNU Public License version 3 (GPLv3).
#
# And for those who want to use this program in ways that are incompatible
# with the GPLv3, PulseRain Technology LLC offers commercial license instead.
# Please contact PulseRain Technology LLC (www.pulserain.com) for more detail.
#
###############################################################################
*/

`timescale 1ns/1ps 

`include "file_compare.svh"
`include "common.vh"


parameter OSC_PERIOD = 20ns;  // 50MHz oscillator

module tb_RV #(parameter string TV = "") ();
    
    //========================================================================
    // signals
    //========================================================================
        logic                                   osc = 0;
        wire                                    all_done;
    
        wire  unsigned [11 : 0] #(2)            SDRAM_ADDR;
        wire  unsigned [1 : 0]  #(2)            SDRAM_BA;
        wire                    #(2)            SDRAM_CAS_N;
        wire                    #(2)            SDRAM_CKE;
        wire                    #(2)            SDRAM_CS_N;     
        wire  [15 : 0]          #(2)            SDRAM_DQ;
        wire  unsigned [1 : 0]  #(2)            SDRAM_DQM;
        wire                    #(2)            SDRAM_RAS_N;
        wire                    #(2)            SDRAM_WE_N;
        wire                    #(1)            SDRAM_CLK;
        
        wire                                    cmp_enable;
        integer                                 exe_to_cmp [0 : 33];        
        
    //========================================================================
    // UUT
    //========================================================================

            master_platform uut (
                    .osc_in (osc),
                                       
                    .RXD (1'b1),
                    .TXD (),
                                    
                    .LED (),
                    
                    .REG_LED1_R (),
                    .REG_LED1_G (),
                    .REG_LED1_B (),
                    
                    .REG_LED2_R (),
                    .REG_LED2_G (),
                    .REG_LED2_B (),
        
                    
                    .SEG_A (),
                    .SEG_B (),
                    .SEG_C (),
                    .SEG_D (),
                    .SEG_E (),
                    .SEG_F (),
                    .SEG_G (),
                    .SEG_DP (),
                    .SEG_DIG4 (),
                    .SEG_DIG3 (),
                    .SEG_DIG2 (),
                    .SEG_DIG1 (),
                    
                    .KEY1 (1'b0),
                    .KEY2 (1'b0),
                    .KEY3 (1'b0),
                    .KEY4 (1'b0),
                    .KEY5 (1'b0),
                    
                    .SW1 (1'b1),
                    .SW2 (1'b1),
                    .SW3 (1'b0),
                    .SW4 (1'b1),
                    .SW5 (1'b0),
                    .SW6 (1'b0),
                    .SW7 (1'b0),
                    .SW8 (1'b1),
                    
                    .SDRAM_ADDR (SDRAM_ADDR),
                    .SDRAM_BA (SDRAM_BA),
                    .SDRAM_CAS_N (SDRAM_CAS_N),
                    .SDRAM_CKE (SDRAM_CKE),
                    .SDRAM_CS_N (SDRAM_CS_N),
                    .SDRAM_DQ (SDRAM_DQ),
                    .SDRAM_DQM (SDRAM_DQM),
                    .SDRAM_RAS_N (SDRAM_RAS_N),
                    .SDRAM_WE_N (SDRAM_WE_N),     
                    .SDRAM_CLK (SDRAM_CLK)
            );

    //========================================================================
    // DRAM simulation model
    //========================================================================

            sdram_ISSI_SDRAM_test_component sdram_ISSI_SDRAM_test_component_i (
                       .clk (SDRAM_CLK),
                       .zs_addr (SDRAM_ADDR),
                       .zs_ba (SDRAM_BA),
                       .zs_cas_n (SDRAM_CAS_N),
                       .zs_cke (SDRAM_CKE),
                       .zs_cs_n (SDRAM_CS_N),
                       .zs_dqm (SDRAM_DQM),
                       .zs_ras_n (SDRAM_RAS_N),
                       .zs_we_n (SDRAM_WE_N),
                       .zs_dq (SDRAM_DQ)
             );
               
    //========================================================================
    // Test Vector compare
    //========================================================================
    
        assign cmp_enable = (TV == "") ? 1'b0 : 1'b1;
    
         genvar i;
         generate
            for (i = 1; i < 32; i = i + 1) begin
                assign exe_to_cmp[i + 2] = 'X;
            end
        
        endgenerate
        
        assign exe_to_cmp[0] = uut.PulseRain_Reindeer_MCU_i.PulseRain_Reindeer_core_i.Reindeer_execution_unit_i.PC_in;
        assign exe_to_cmp[1] = uut.PulseRain_Reindeer_MCU_i.PulseRain_Reindeer_core_i.Reindeer_execution_unit_i.IR_in;

        
        generate
            for (i = 0; i < ((TV == "") ? 0 : 1); i = i + 1) begin
                
                single_file_compare #( .NUM_OF_COLUMNS (34), 
                                        .NUM_OF_COLUMNS_TO_DISPLAY(2),
                                        .FILE_NAME({TV}), 
                                        .NUM_OF_LINES(0), 
                                        .BASE(16), 
                                        .LINES_TO_SKIP(0), 
                                        .VERBOSE(1),
                                        .PAUSE_ON_MISMATCH(1), 
                                        .WILDCARD_COMPARE(1),
                                        .CARRIAGE_RETURN(1) ) data_exe_cmp (
                         
                         .clk (uut.clk_100MHz),
                         .reset_n (1'b1),
                    
                        //====== data to compare
                        .data_to_cmp(exe_to_cmp),
                        .enable_in (uut.PulseRain_Reindeer_MCU_i.PulseRain_Reindeer_core_i.Reindeer_execution_unit_i.exe_enable & cmp_enable),
                        
                        .pass1_fail0 (), 
                        .all_done(all_done)
                        ); 
            end
        endgenerate
    
    //========================================================================
    // clock
    //========================================================================
    
        initial begin
            forever begin 
                #(OSC_PERIOD/2);
                
                if ((all_done) && (TV != "")) begin
                    break;
                end else begin
                    osc = (~osc);
                end
            end
        end
    
endmodule 
    