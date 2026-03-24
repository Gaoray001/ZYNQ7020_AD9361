`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/05 16:09:00
// Design Name: 
// Module Name: AD9361_Top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AD9361_Top(
    input           clk_in,
    input           rst_n_in,
// AD9361 Interface
    input           i_rx_clk_in_p       ,
    input           i_rx_clk_in_n       ,
    input           i_rx_frame_in_p     ,
    input           i_rx_frame_in_n     ,
    input  [ 5:0]   i_rx_data_in_p      ,
    input  [ 5:0]   i_rx_data_in_n      ,

    output          o_tx_clk_out_p      ,
    output          o_tx_clk_out_n      ,
    output          o_tx_frame_out_p    ,
    output          o_tx_frame_out_n    ,
    output [ 5:0]   o_tx_data_out_p     ,
    output [ 5:0]   o_tx_data_out_n     ,

    output          o_gpio_txnrx        ,
    output          o_gpio_enable       ,
    output          o_gpio_resetb       ,
    output          o_gpio_en_agc       ,
    output [ 3:0]   o_gpio_ctl          ,

    output          o_fmc_spi_cs_n      ,
    output          o_fmc_spi_clk       ,
    output          o_fmc_spi_mosi      ,
    input           i_fmc_spi_miso      ,
    
//usr_Interface 
    input  wire    AD9361_UserClk_40M_i       ,
    input  wire    AD9361_UserClk_40M_rst_i   ,
//usr_Ctrl_Interface 
    input           AD9361_User_Valid_i        ,       //AD9361接口控制触发标志
    input [31:0]    AD9361_User_LoFreq_Rx_i    ,       //AD9361接口控制-接收本振   KHz
    input [31:0]    AD9361_User_LoFreq_Tx_i    ,       //AD9361接口控制-发送本振   KHz
    input [15:0]    AD9361_User_rxGain_CH0_i   ,       //AD9361接口控制-接收增益通道0
    input [15:0]    AD9361_User_rxGain_CH1_i   ,       //AD9361接口控制-接收增益通道1
    // input [15:0]    AD9361_txATT_CH0    ,    //AD9361接口控制-发送衰减通道0  db
    // input [15:0]    AD9361_txATT_CH1    ,    //AD9361接口控制-发送衰减通道1  db

    input           AD9361_User_txATT_Valid_i  ,
    input [15:0]    AD9361_User_txATT_CH0_i    ,       //AD9361接口控制-发送衰减通道0  db
    input [15:0]    AD9361_User_txATT_CH1_i    ,       //AD9361接口控制-发送衰减通道1  db

//usr_Data_Interface 

    output [31:0]   AD9361_User_Data_RxSYNC_CH1_o,
    output [31:0]   AD9361_User_Data_RxSYNC_CH2_o,  
    input  [31:0]   AD9361_User_Data_TxSYNC_CH1_i,
    input  [31:0]   AD9361_User_Data_TxSYNC_CH2_i
    );

    localparam CLK_PARAM = 10_000_000 ;

//////////////////AD_PLL///////////////////
    wire clk_48M;
    wire clk_10M;
    wire clk_200M;
    wire clk_50M;
    wire AD_rstn;
    AD_CLK_PLL AD_CLK_PLL
    (
    .clk_in1     (clk_in                    ),// Clock in ports
    
    .resetn      (rst_n_in                  ),// input resetn
    .locked      (AD_rstn                   ),// output locked
    
    .clk_out1    (                          ),// output clk_out1
    .clk_out2    (clk_48M                   ),// output clk_out2
    .clk_out3    (clk_10M                   ),// output clk_out3
    .clk_out4    (clk_200M                  ),// output clk_out4
    .clk_out5    (                          ) // output clk_out5
    );




    wire l_clk;
    wire l_clk_bufin;   
    // BUFG BUFG_inst ( 
    //     .O                  (       l_clk               ), // 1-bit output: Clock output
    //     .I                  (       l_clk_bufin         )  // 1-bit input: Clock input
    // ); 
    assign l_clk = l_clk_bufin;
    // assign AD9361_rx_data_clk_160Mhz = l_clk;






    assign  o_gpio_txnrx  = 1'b0;
    assign  o_gpio_enable = 1'b1;
    assign  o_gpio_resetb = AD_rstn;
    assign  o_gpio_en_agc = 1'b0;
    assign  o_gpio_ctl    = 4'h0;



    wire            adc_enable_i0   ;
    wire            adc_valid_i0    ;
    wire  [15:0]    adc_data_i0     ;
    wire            adc_enable_q0   ;
    wire            adc_valid_q0    ;
    wire  [15:0]    adc_data_q0     ;    
    wire            adc_enable_i1   ;
    wire            adc_valid_i1    ;
    wire  [15:0]    adc_data_i1     ;
    wire            adc_enable_q1   ;
    wire            adc_valid_q1    ;
    wire  [15:0]    adc_data_q1     ;

    wire            dac_enable_i0   ;
    wire            dac_valid_i0    ;
    wire  [15:0]    dac_data_i0     ;
    wire            dac_enable_q0   ;
    wire            dac_valid_q0    ;
    wire  [15:0]    dac_data_q0     ;
    wire            dac_enable_i1   ;
    wire            dac_valid_i1    ;
    wire  [15:0]    dac_data_i1     ;
    wire            dac_enable_q1   ;
    wire            dac_valid_q1    ;
    wire  [15:0]    dac_data_q1     ;


    wire  [111:0]  dev_dbg_data  ;
    wire  [ 61:0]  dev_l_dbg_data;  
    axi_ad9361 u_axi_ad9361(
          // physical interface (receive)
        .rx_clk_in_p        (       i_rx_clk_in_p       ),
        .rx_clk_in_n        (       i_rx_clk_in_n       ),
        .rx_frame_in_p      (       i_rx_frame_in_p     ),
        .rx_frame_in_n      (       i_rx_frame_in_n     ),
        .rx_data_in_p       (       i_rx_data_in_p      ),
        .rx_data_in_n       (       i_rx_data_in_n      ),        

        // physical interface (transmit)
        .tx_clk_out_p       (       o_tx_clk_out_p      ),
        .tx_clk_out_n       (       o_tx_clk_out_n      ),
        .tx_frame_out_p     (       o_tx_frame_out_p    ),
        .tx_frame_out_n     (       o_tx_frame_out_n    ),
        .tx_data_out_p      (       o_tx_data_out_p     ),
        .tx_data_out_n      (       o_tx_data_out_n     ),

        .dac_sync_in        (       1'b0                ),
        .dac_sync_out       (                           ),       

        // clock (common to both receive and transmit)
        .delay_clk          (       clk_200M            ),         
        .clk                (       l_clk               ),//in
        .l_clk              (       l_clk_bufin         ),//out

        // receive data path interface
        .adc_enable_i0      (       adc_enable_i0       ), // all output
        .adc_valid_i0       (       adc_valid_i0        ),
        .adc_data_i0        (       adc_data_i0         ),
        .adc_enable_q0      (       adc_enable_q0       ),
        .adc_valid_q0       (       adc_valid_q0        ),
        .adc_data_q0        (       adc_data_q0         ),
        .adc_enable_i1      (       adc_enable_i1       ),
        .adc_valid_i1       (       adc_valid_i1        ),
        .adc_data_i1        (       adc_data_i1         ),
        .adc_enable_q1      (       adc_enable_q1       ),
        .adc_valid_q1       (       adc_valid_q1        ),
        .adc_data_q1        (       adc_data_q1         ),
        .adc_dovf           (       1'b0                ), // in
        .adc_dunf           (       1'b0                ), // in

        // transmit data path interface
        .dac_enable_i0      (       dac_enable_i0       ), // out
        .dac_valid_i0       (       dac_valid_i0        ), // out
        .dac_data_i0        (       dac_data_i0         ), // in
        .dac_enable_q0      (       dac_enable_q0       ),
        .dac_valid_q0       (       dac_valid_q0        ),
        .dac_data_q0        (       dac_data_q0         ),
        .dac_enable_i1      (       dac_enable_i1       ),
        .dac_valid_i1       (       dac_valid_i1        ),
        .dac_data_i1        (       dac_data_i1         ),
        .dac_enable_q1      (       dac_enable_q1       ),
        .dac_valid_q1       (       dac_valid_q1        ),
        .dac_data_q1        (       dac_data_q1         ),
        .dac_dovf           (       1'b0                ),
        .dac_dunf           (       1'b0                ),

        .s_axi_aclk         (       clk_48M             ),
        .s_axi_aresetn      (       AD_rstn             ),
        .s_axi_awvalid      (       1'b0                ),
        .s_axi_awaddr       (       32'h0               ),
        .s_axi_awprot       (       3'h0                ),  // not used
        .s_axi_awready      (                           ),
        .s_axi_wvalid       (       1'b0                ),
        .s_axi_wdata        (       32'h0               ),
        .s_axi_wstrb        (       4'h0                ),
        .s_axi_wready       (                           ),
        .s_axi_bvalid       (                           ),
        .s_axi_bresp        (                           ),
        .s_axi_bready       (       1'b1                ),
        .s_axi_arvalid      (       1'b0                ),
        .s_axi_araddr       (       32'h0               ),
        .s_axi_arprot       (       3'h0                ),  // not used
        .s_axi_arready      (                           ),
        .s_axi_rvalid       (                           ),
        .s_axi_rdata        (                           ),
        .s_axi_rresp        (                           ),
        .s_axi_rready       (       1'b1                ),

        .up_dac_gpio_in     (       32'h0               ),
        .up_dac_gpio_out    (                           ),
        .up_adc_gpio_in     (       32'h0               ),
        .up_adc_gpio_out    (                           ),

        // chipscope signals
        .dev_dbg_data       (       dev_dbg_data        ),
        .dev_l_dbg_data     (       dev_l_dbg_data      )
    );


    //-----------------------------------------------------------------------------//
    // clk_40Mhz
    //-----------------------------------------------------------------------------//
    wire l_clk_div4;
    clk_div4  u_ad9361_clk(
     .l_clk              ( l_clk_bufin    ),//i
     .i_rst_n            ( AD_rstn        ),//i
     .clk_div4           ( l_clk_div4      ) //o
    );

    wire l_clk_div4_rst_n;
    ad9361_rst_gen  u_ad9361_rst_gen (
        .clk              ( l_clk_div4     ),
        .rst_n_i          ( AD_rstn          ),

        .rst_o          ( l_clk_div4_rst_n     )
    );


    // assign AD9361_clk_40Mhz = l_clk_div4;
    // assign AD9361_rst = l_clk_div4_rst_n;

    //-----------------------------------------------------------------------------//
    // AD_Data_Sync
    //-----------------------------------------------------------------------------//
    wire                 [  31: 0]      AD9361_Data_Tx_CH1          ;
    wire                 [  31: 0]      AD9361_Data_Tx_CH2          ;
    AD_Data_Sync u_AD_Data_Sync(
    .l_clk                              (l_clk_bufin               ),
    .l_rst_ni                           (l_clk_div4_rst_n          ),
    .AD9361_Data_Rx_CH1                 ({adc_data_q0,adc_data_i0} ),//i
    .AD9361_Data_Rx_CH2                 ({adc_data_q1,adc_data_i1} ),//i
    .AD9361_Data_Tx_CH1                 (AD9361_Data_Tx_CH1        ),//o
    .AD9361_Data_Tx_CH2                 (AD9361_Data_Tx_CH2        ),//o

    .AD9361_UserClk_40M_i               (AD9361_UserClk_40M_i    ),
    .AD9361_User_Data_Rx_SYNC_CH1_o     (AD9361_User_Data_RxSYNC_CH1_o   ),//O
    .AD9361_User_Data_Rx_SYNC_CH2_o     (AD9361_User_Data_RxSYNC_CH2_o   ),//O
    .AD9361_User_Data_Tx_SYNC_CH1_i     (AD9361_User_Data_TxSYNC_CH1_i   ),//i
    .AD9361_User_Data_Tx_SYNC_CH2_i     (AD9361_User_Data_TxSYNC_CH2_i   ) //i
    );


    assign dac_data_i0 = AD9361_Data_Tx_CH1[15: 0];
    assign dac_data_q0 = AD9361_Data_Tx_CH1[31:16];
    assign dac_data_i1 = AD9361_Data_Tx_CH2[15: 0];
    assign dac_data_q1 = AD9361_Data_Tx_CH2[31:16];



    ila_64Xbit ila_txafter_data (
	.clk(l_clk_bufin), // input wire clk
	.probe0({
        AD9361_Data_Tx_CH1,
        AD9361_Data_Tx_CH2
    }) // input wire [63:0] probe0
);

    ila_64Xbit ila_txpre_data (
	.clk(AD9361_UserClk_40M_i), // input wire clk
	.probe0({
        AD9361_User_Data_TxSYNC_CH1_i,
        AD9361_User_Data_TxSYNC_CH2_i
    }) // input wire [63:0] probe0
);

    //-----------------------------------------------------------------------------//
    // AD9361_InterFace 9361控制接口
    //-----------------------------------------------------------------------------//
    wire          AD9361_Ctrl_Enable;
    wire  [3: 0]  Rx_VcoDivider;
    wire  [3: 0]  Tx_VcoDivider;
    wire  [10:0]  Rx_FreqInteger;
    wire  [22:0]  Rx_FreqFractional;
    wire  [10:0]  Tx_FreqInteger;
    wire  [22:0]  Tx_FreqFractional;   

    wire          TX_ATT_Valid;
    wire  [15:0]  Tx0_ATT_data;
    wire  [15:0]  Tx1_ATT_data; 
        
    AD9361_InterFace u_AD9361_InterFace(
    .clk                                (AD9361_UserClk_40M_i      ),
    .rst                                (AD9361_UserClk_40M_rst_i  ),
    
    .AD9361_Valid                       (AD9361_User_Valid_i       ),
    .AD9361_LoFreq_Rx                   (AD9361_User_LoFreq_Rx_i   ),
    .AD9361_LoFreq_Tx                   (AD9361_User_LoFreq_Tx_i   ),
    .AD9361_rxGain_CH0                  (AD9361_User_rxGain_CH0_i  ),
    .AD9361_rxGain_CH1                  (AD9361_User_rxGain_CH1_i  ),
    
    .AD9361_txATT_Valid                 (AD9361_User_txATT_Valid_i ),
    .AD9361_txATT_CH0                   (AD9361_User_txATT_CH0_i   ),
    .AD9361_txATT_CH1                   (AD9361_User_txATT_CH1_i   ),
    
    .AD9361_Ctrl_Enable                 (AD9361_Ctrl_Enable        ),
    .Rx_VcoDivider                      (Rx_VcoDivider             ),
    .Tx_VcoDivider                      (Tx_VcoDivider             ),
    .Rx_FreqInteger                     (Rx_FreqInteger            ),
    .Rx_FreqFractional                  (Rx_FreqFractional         ),
    .Tx_FreqInteger                     (Tx_FreqInteger            ),
    .Tx_FreqFractional                  (Tx_FreqFractional         ),
    
    .TX_ATT_Valid                       (TX_ATT_Valid              ),
    .Tx0_ATT_data                       (Tx0_ATT_data              ),
    .Tx1_ATT_data                       (Tx1_ATT_data              ) 
    );


    //-----------------------------------------------------------------------------//
    // ad9361_spi_drv SPI写AD9361寄存器
    //-----------------------------------------------------------------------------//
    ad9361_spi_drv #(
        .CLK_PARAM              ( CLK_PARAM             )
    )
    u_ad9361_spi_drv(
        .clk                    ( clk_10M               ),
        .rstn                   ( AD_rstn               ),

        .mdio_sclk              ( o_fmc_spi_clk         ),
        .mdio_sdi               ( o_fmc_spi_mosi        ),
        .mdio_csb               ( o_fmc_spi_cs_n        ),
        .mdio_sdo               ( i_fmc_spi_miso        ),

        .AD9361_Ctrl_Enable     ( AD9361_Ctrl_Enable    ),                  
        .Rx_VcoDivider          ( Rx_VcoDivider         ),              
        .Tx_VcoDivider          ( Tx_VcoDivider         ),              
        .Rx_FreqInteger         ( Rx_FreqInteger        ),              
        .Rx_FreqFractional      ( Rx_FreqFractional     ),                  
        .Tx_FreqInteger         ( Tx_FreqInteger        ),              
        .Tx_FreqFractional      ( Tx_FreqFractional     ),

        .TX_ATT_Valid           ( TX_ATT_Valid          ),
        .Tx0_ATT_data           ( Tx0_ATT_data          ),
        .Tx1_ATT_data           ( Tx1_ATT_data          )                  
    );

// ila_128Xbit ila_9361_rx (
// 	.clk(l_clk_div4), // input wire clk
// 	.probe0({'d0
//             ,l_clk_div4_rst_n
//             ,AD9361_Valid
//             ,AD9361_LoFreq_Rx
//             ,AD9361_Data_Rx_SYNC_CH1
//             ,AD9361_Data_Rx_SYNC_CH2
//     }) // input wire [127:0] probe0
// );
endmodule
