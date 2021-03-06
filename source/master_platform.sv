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


`include "common.vh"
`include "debug_coprocessor.vh"
`include "config.vh"

`default_nettype none

module master_platform (

    //------------------------------------------------------------------------
    //  clock and reset
    //------------------------------------------------------------------------
    
        input   wire                    osc_in,     
        
    //------------------------------------------------------------------------
    //  UART
    //------------------------------------------------------------------------
        
        input   wire                    RXD,
        output  logic                   TXD,
        
         
    //------------------------------------------------------------------------
    //  Single Color LED
    //------------------------------------------------------------------------
        
        output  wire  unsigned [7 : 0]  LED,
    
    //------------------------------------------------------------------------
    //  RGB LED
    //------------------------------------------------------------------------

        output wire                     REG_LED1_R,
        output wire                     REG_LED1_G,
        output wire                     REG_LED1_B,

        output wire                     REG_LED2_R,
        output wire                     REG_LED2_G,
        output wire                     REG_LED2_B,

    //------------------------------------------------------------------------
    //  7 Segment Display
    //------------------------------------------------------------------------
        output  wire                    SEG_DIG1,
        output  wire                    SEG_DIG2,
        output  wire                    SEG_DIG3,
        output  wire                    SEG_DIG4,
        
        output  wire                    SEG_A,
        output  wire                    SEG_B,
        output  wire                    SEG_C,
        output  wire                    SEG_D,
        output  wire                    SEG_E,
        output  wire                    SEG_F,
        output  wire                    SEG_G,
        output  wire                    SEG_DP,
 
    //------------------------------------------------------------------------
    //  5 way navigation switch
    //------------------------------------------------------------------------
        input   wire                    KEY1,
        input   wire                    KEY2,
        input   wire                    KEY3,
        input   wire                    KEY4,
        input   wire                    KEY5,
    
    //------------------------------------------------------------------------
    //  DIP Switch
    //------------------------------------------------------------------------
        input   wire                    SW1,
        input   wire                    SW2,
        input   wire                    SW3,
        input   wire                    SW4,
        input   wire                    SW5,
        input   wire                    SW6,
        input   wire                    SW7,
        input   wire                    SW8,
    
    //------------------------------------------------------------------------
    //  SDRAM
    //------------------------------------------------------------------------
        
        output  wire  unsigned [11 : 0] SDRAM_ADDR,     
        output  wire  unsigned [1 : 0]  SDRAM_BA,       
        output  wire                    SDRAM_CAS_N,    
        output  wire                    SDRAM_CKE,       
        output  wire                    SDRAM_CS_N,     
        inout   wire  unsigned [15 : 0] SDRAM_DQ,       
        output  wire  unsigned [1 : 0]  SDRAM_DQM,      
        output  wire                    SDRAM_RAS_N,    
        output  wire                    SDRAM_WE_N,     
        output  wire                    SDRAM_CLK
);

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signal
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
        wire                                    clk_100MHz;
        wire                                    clk_100MHz_shift;
        wire                                    clk_12MHz;

        wire                                    pll_locked;
        
        wire                                    reset_n;        
                
        wire unsigned [21 : 0]                  sdram_slave_address;
        wire unsigned [1 : 0]                   sdram_slave_byteenable_n;
        wire                                    sdram_slave_chipselect;
        wire unsigned [15 : 0]                  sdram_slave_writedata;
        wire                                    sdram_slave_read_n;
        wire                                    sdram_slave_write_n;
        wire unsigned [15 : 0]                  sdram_slave_readdata;
        wire                                    sdram_slave_waitrequest;
        wire                                    sdram_slave_readdatavalid;
    
        wire                                    uart_tx_ocd;
        wire                                    uart_tx_cpu;
        
        wire                                    ocd_read_enable;
        wire                                    ocd_write_enable;

        wire  [`MEM_ADDR_BITS - 1 : 0]          ocd_rw_addr;
        wire  [`XLEN - 1 : 0]                   ocd_write_word;

        wire                                    ocd_mem_enable_out;
        wire  [`XLEN - 1 : 0]                   ocd_mem_word_out;      

        wire                                    debug_uart_tx_sel_ocd1_cpu0;
        wire                                    cpu_reset;
        wire  [`DEBUG_PRAM_ADDR_WIDTH - 3 : 0]  pram_read_addr;
        wire  [`DEBUG_PRAM_ADDR_WIDTH - 3 : 0]  pram_write_addr;
        
        wire                                    cpu_start;
        wire  [`XLEN - 1 : 0]                   cpu_start_addr;
       
        wire                                    processor_paused;
        
        logic unsigned [1 : 0]                  init_start = 0;
        
        logic                                   actual_cpu_start;
        logic unsigned [`XLEN - 1 : 0]          actual_start_addr;
        
        
        wire                                    dram_ack;
        wire  [`XLEN - 1 : 0]                   dram_mem_read_data;
        
        wire  [`MEM_ADDR_BITS - 1 : 0]          mcu_dram_mem_addr;
        wire                                    dram_mem_read_en;
        wire                                    mcu_dram_mem_write_en;
        wire  [`XLEN_BYTES - 1 : 0]             mcu_dram_mem_byte_enable;
        wire  [`XLEN - 1 : 0]                   mcu_dram_mem_write_data;
        
        wire [`MEM_ADDR_BITS - 1 : 0]           dram_mem_addr;
        wire                                    dram_mem_write_en;
        wire [`XLEN_BYTES - 1 : 0]              dram_mem_byte_enable;
        wire [`XLEN - 1 : 0]                    dram_mem_write_data;
        
        
        wire  unsigned [`NUM_OF_GPIOS - 1 : 0]  gpio_out;
        wire  unsigned [`NUM_OF_GPIOS - 1 : 0]  gpio_in;
        
        wire  [4 : 0]                           five_way_keys;
        wire  [4 : 0]                           five_way_keys_debounced;
        logic                                   int0;
      
        wire                                    sda_out;
        wire                                    scl_out;
              
              
        wire unsigned [`MEM_ADDR_BITS - 1 : 0]  loader_dram_mem_addr;
        wire                                    loader_dram_mem_write_en;
        wire unsigned [`XLEN_BYTES - 1 : 0]     loader_dram_mem_byte_enable;
        wire unsigned [`XLEN - 1 : 0]           loader_dram_mem_write_data;
        wire                                    loader_done;
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // PLL
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        assign reset_n = 1'b1;
        
        PLL pll_i (
            .areset(~reset_n),
            .inclk0 (osc_in),  // 50MHz clock in
            .c0 (clk_100MHz),
            .c1 (clk_100MHz_shift),
            .c2 (clk_12MHz),
            .locked (pll_locked));
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // DDIO
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        DDIO_OUT ddio_out_i (
            .datain_h (1'b1),
            .datain_l (1'b0),
            .outclock (clk_100MHz_shift),
            .dataout (SDRAM_CLK)
        );
        
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SDRAM, ISSI - IS42S16400J
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

            sdram sdram_i (
                    .clk_clk (clk_100MHz),
                    .reset_reset_n (pll_locked),
                    .sdram_addr (SDRAM_ADDR),
                    .sdram_ba (SDRAM_BA),
                    .sdram_cas_n (SDRAM_CAS_N),
                    .sdram_cke (SDRAM_CKE),
                    .sdram_cs_n (SDRAM_CS_N),
                    .sdram_dq (SDRAM_DQ),
                    .sdram_dqm (SDRAM_DQM),
                    .sdram_ras_n (SDRAM_RAS_N),
                    .sdram_we_n (SDRAM_WE_N),

                    .sdram_slave_address (sdram_slave_address),
                    .sdram_slave_byteenable_n (sdram_slave_byteenable_n),
                    .sdram_slave_chipselect (sdram_slave_chipselect),  
                    .sdram_slave_writedata (sdram_slave_writedata),
                    .sdram_slave_read_n (sdram_slave_read_n),
                    .sdram_slave_write_n (sdram_slave_write_n),
                    .sdram_slave_readdata (sdram_slave_readdata),
                    .sdram_slave_readdatavalid (sdram_slave_readdatavalid),
                    .sdram_slave_waitrequest (sdram_slave_waitrequest)
            );
           
            
            sdram_controller sdram_controller_i (
                //=====================================================================
                // clock and reset
                //=====================================================================
                    .clk (clk_100MHz),
                    .reset_n (pll_locked),
                    .sync_reset (1'b0),

                //=====================================================================
                // memory interface
                //=====================================================================
                    .mem_cs (dram_mem_read_en | dram_mem_write_en),
                    .mem_byteenable (dram_mem_byte_enable),
                    .mem_read0_write1 (dram_mem_write_en),
                    .mem_addr ({dram_mem_addr, 1'b0}),
                    .mem_write_data (dram_mem_write_data),

                    .mem_ack (dram_ack),
                    .mem_read_data (dram_mem_read_data),

                //=====================================================================
                // SDRAM Avalon Bus
                //=====================================================================
                    .sdram_av_readdata (sdram_slave_readdata),
                    .sdram_av_readdatavalid (sdram_slave_readdatavalid),
                    .sdram_av_waitrequest (sdram_slave_waitrequest), 

                    .sdram_av_address (sdram_slave_address),
                    .sdram_av_byteenable_n (sdram_slave_byteenable_n),
                    .sdram_av_chipselect (sdram_slave_chipselect),
                    .sdram_av_writedata (sdram_slave_writedata),
                    .sdram_av_read_n (sdram_slave_read_n),
                    .sdram_av_write_n (sdram_slave_write_n)
            );

    assign dram_mem_write_en    = mcu_dram_mem_write_en | loader_dram_mem_write_en;
    assign dram_mem_addr        = loader_dram_mem_write_en ? loader_dram_mem_addr        : mcu_dram_mem_addr;
    assign dram_mem_byte_enable = loader_dram_mem_write_en ? loader_dram_mem_byte_enable : mcu_dram_mem_byte_enable;
    assign dram_mem_write_data  = loader_dram_mem_write_en ? loader_dram_mem_write_data  : mcu_dram_mem_write_data;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SDRAM loader using SRAM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
         assign loader_dram_mem_write_en = 0;
         assign loader_done = 0;
        
 
        /*
        sdram_init_loader #(.ROM_SIZE_IN_BYTES (16 *1024)) sdram_init_loader_i (
            .clk (clk_100MHz),
            .reset_n (pll_locked),
            
            .dram_ack (dram_ack),
            .dram_mem_addr          (loader_dram_mem_addr),
            .dram_mem_write_en      (loader_dram_mem_write_en),
            .dram_mem_byte_enable   (loader_dram_mem_byte_enable),
            .dram_mem_write_data    (loader_dram_mem_write_data),
            .done                   (loader_done)
        );
*/
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // 5 way navigation switch
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        assign five_way_keys[0] = KEY1;
        assign five_way_keys[1] = KEY2;
        assign five_way_keys[2] = KEY3;
        assign five_way_keys[3] = KEY4;
        assign five_way_keys[4] = KEY5;
        
        genvar i;
        
        generate
            
            for (i = 0; i < 5; i = i + 1) begin: gen_keys
            
                
                switch_debouncer  #(.TIMER_VALUE (100000)) switch_debouncer_i (
                    .clk (clk_100MHz),
                    .reset_n (pll_locked),
            
                    .data_in (five_way_keys[i]),
                    .data_out (five_way_keys_debounced[i])
                );
                
            end 
            
        endgenerate
      
   
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // MCU
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk_100MHz, negedge pll_locked) begin
            if (!pll_locked) begin
                init_start <= 0;
                actual_cpu_start <= 0;
                actual_start_addr <= 0;
                
                int0 <= 0;

            end else begin
                init_start <= {init_start [$high(init_start) - 1 : 0], 1'b1};
                actual_cpu_start <= cpu_start | ((~init_start [$high(init_start)]) & init_start [$high(init_start) - 1]);
               // actual_cpu_start <= cpu_start | loader_done;
                if (cpu_start) begin
                    actual_start_addr <= cpu_start_addr;
                end else begin
                    actual_start_addr <= `DEFAULT_START_ADDR;
                end
                
                int0 <= ~(&five_way_keys_debounced);
            end
        end
     
        PulseRain_MCU PulseRain_Reindeer_MCU_i (
            .clk (clk_100MHz),
            .reset_n ((~cpu_reset) & pll_locked),
            .sync_reset (1'b0),
            
            .INTx ({1'b0, int0}),

            .ocd_read_enable (ocd_read_enable),
            .ocd_write_enable (ocd_write_enable),
            
            .ocd_rw_addr (ocd_rw_addr),
            .ocd_write_word (ocd_write_word),
            
            .ocd_mem_enable_out (ocd_mem_enable_out),
            .ocd_mem_word_out (ocd_mem_word_out),        
        
            .ocd_reg_read_addr (5'd2),
            .ocd_reg_we (cpu_start),
            .ocd_reg_write_addr (5'd2),
            .ocd_reg_write_data (`DEFAULT_STACK_ADDR),
        
            .RXD (RXD),
            .TXD (uart_tx_cpu),
            
            .GPIO_IN (gpio_in),
            .GPIO_OUT(gpio_out),

            .start (actual_cpu_start),
            .start_address (actual_start_addr),
        
            .processor_paused (processor_paused),
    
            .dram_ack             (dram_ack),
            .dram_mem_read_data   (dram_mem_read_data),
            
            .dram_mem_addr        (mcu_dram_mem_addr),
            .dram_mem_read_en     (dram_mem_read_en),
            .dram_mem_write_en    (mcu_dram_mem_write_en),
            .dram_mem_byte_enable (mcu_dram_mem_byte_enable),
            .dram_mem_write_data  (mcu_dram_mem_write_data),
    
            .peek_pc (),
            .peek_ir (),
            .peek_mem_write_en   (),
            .peek_mem_write_data (),
            .peek_mem_addr       ());

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // GPIO
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
        assign LED = gpio_out [31 : 24];
        
        assign SEG_A  = ~gpio_out [0];
        assign SEG_B  = ~gpio_out [1];
        assign SEG_C  = ~gpio_out [2];
        assign SEG_D  = ~gpio_out [3];
        assign SEG_E  = ~gpio_out [4];
        assign SEG_F  = ~gpio_out [5];
        assign SEG_G  = ~gpio_out [6];
        assign SEG_DP = ~gpio_out [7];
        
        assign SEG_DIG4 = gpio_out[8];
        assign SEG_DIG3 = gpio_out[9];
        assign SEG_DIG2 = gpio_out[10];
        assign SEG_DIG1 = gpio_out[11];
        
        assign REG_LED1_R = gpio_out [16];
        assign REG_LED1_G = gpio_out [17];
        assign REG_LED1_B = gpio_out [18];
        
        assign REG_LED2_R = gpio_out [20];
        assign REG_LED2_G = gpio_out [21];
        assign REG_LED2_B = gpio_out [22];
        
        assign gpio_in[4 : 0] = ~five_way_keys_debounced;
        assign gpio_in[15 : 8] = {SW8, SW7, SW6, SW5, SW4, SW3, SW2, SW1};
        assign gpio_in[$high(gpio_in) : 16] = 0;

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Hardware Loader
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        debug_coprocessor_wrapper #(.BAUD_PERIOD (108)) hw_loader_i (
                    .clk (clk_100MHz),
                    .reset_n (pll_locked),
                    
                    .RXD (RXD),
                    .TXD (uart_tx_ocd),
                        
                    .pram_read_enable_in (ocd_mem_enable_out),
                    .pram_read_data_in (ocd_mem_word_out),
                    
                    .pram_read_enable_out (ocd_read_enable),
                    .pram_read_addr_out (pram_read_addr),
                    
                    .pram_write_enable_out (ocd_write_enable),
                    .pram_write_addr_out (pram_write_addr),
                    .pram_write_data_out (ocd_write_word),
                    
                    .cpu_reset (cpu_reset),
                    
                    .cpu_start (cpu_start),
                    .cpu_start_addr (cpu_start_addr),        
                    
                    .debug_uart_tx_sel_ocd1_cpu0 (debug_uart_tx_sel_ocd1_cpu0));
                
    assign ocd_rw_addr = ocd_read_enable ? pram_read_addr [$high(ocd_rw_addr) : 0] : pram_write_addr [$high(ocd_rw_addr) : 0];        
    
    always_ff @(posedge clk_100MHz, negedge pll_locked) begin : uart_proc
        if (!pll_locked) begin
            TXD <= 0;
        end else if (!debug_uart_tx_sel_ocd1_cpu0) begin
            TXD <= uart_tx_cpu;
        end else begin
            TXD <= uart_tx_ocd;
        end
    end 

endmodule

`default_nettype wire
