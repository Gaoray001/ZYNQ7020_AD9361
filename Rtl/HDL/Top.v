module Top (
    // ==========================================
    // Clock & Reset
    // ==========================================
    input           g_clock_in,

    // ==========================================
    // AD9361 Interface (Inputs to Top)
    // ==========================================
    input           i_rx_clk_in_p,
    input           i_rx_clk_in_n,
    input           i_rx_frame_in_p,
    input           i_rx_frame_in_n,
    input   [ 5:0]  i_rx_data_in_p,
    input   [ 5:0]  i_rx_data_in_n,
    input           i_fmc_spi_miso,

    // ==========================================
    // AD9361 Interface (Outputs from Top)
    // ==========================================
    output          o_tx_clk_out_p,
    output          o_tx_clk_out_n,
    output          o_tx_frame_out_p,
    output          o_tx_frame_out_n,
    output  [ 5:0]  o_tx_data_out_p,
    output  [ 5:0]  o_tx_data_out_n,
    output          o_gpio_txnrx,
    output          o_gpio_enable,
    output          o_gpio_resetb,
    output          o_gpio_en_agc,
    output  [ 3:0]  o_gpio_ctl,
    output          o_fmc_spi_cs_n,
    output          o_fmc_spi_clk,
    output          o_fmc_spi_mosi,


    // output wire       A_IF_ATT_SC1,
    // output wire       A_IF_ATT_LE1,
    // output wire       A_IF_ATT_SI1,
    // output wire       A_IF_ATT_SC2,
    // output wire       A_IF_ATT_LE2,
    // output wire       A_IF_ATT_SI2,
    // output wire       A_IF_ATT_A1 ,

    // output wire       B_IF_ATT_SC1,
    // output wire       B_IF_ATT_LE1,
    // output wire       B_IF_ATT_SI1,
    // output wire       B_IF_ATT_SC2,
    // output wire       B_IF_ATT_LE2,
    // output wire       B_IF_ATT_SI2,
    // output wire       B_IF_ATT_A1 ,

    output wire [1:0] F_DIR,
    // output wire [7:0] GP_out,
    
    input  wire rs232_uart_rxd, // J15 : 232 3
    output wire rs232_uart_txd // J15 : 232 1

    // input  wire debug_uart_rxd, // J14 : 422 1+ 2-
    // output wire debug_uart_txd  // J14 : 422 3+ 4-

);
    assign F_DIR[1:0] = 2'b10; // 设置F_DIR为输出


    localparam TRX_CLOCK_PERIOD = 32'd40_000_000;




    wire gb_rst; 
    assign gb_rst = 1'b0;
    
    wire ad_9361_data_clk_40mhz;
    wire g_clock_mmcm_locked;
    wire mb_clock;
    g_clock_mmcm g_clock_mmcm (
    .clk_in1                            (g_clock_in                ),//i
    .reset                              (gb_rst                    ),//i
    .locked                             (g_clock_mmcm_locked       ),//o
    .clk_out1                           (mb_clock                  ),//o 100MHz
    .clk_out2                           (ad_9361_data_clk_40mhz    ) //o 40MHz
    // .clk_out2 ( dly_clock           ) //o 200MHz
    );



    // ==========================================
    // usr_Interface 
    // ==========================================
    wire                                AD9361_clk_40Mhz                  ;
    wire                                AD9361_rst                  ;
    
    wire                                AD9361_Valid                ;
    wire                 [  31: 0]      AD9361_LoFreq_Rx            ;
    wire                 [  31: 0]      AD9361_LoFreq_Tx            ;
    wire                 [  15: 0]      AD9361_rxGain_CH0           ;
    wire                 [  15: 0]      AD9361_rxGain_CH1           ;
    wire                                AD9361_txATT_Valid          ;
    wire                 [  15: 0]      AD9361_txATT_CH0            ;
    wire                 [  15: 0]      AD9361_txATT_CH1            ;
    
    
    
    wire                 [  31: 0]      AD9361_Data_Rx_SYNC_CH1     ;
    wire                 [  31: 0]      AD9361_Data_Rx_SYNC_CH2     ;
    wire                 [  31: 0]      AD9361_Data_Tx_SYNC_CH1     ;
    wire                 [  31: 0]      AD9361_Data_Tx_SYNC_CH2     ;



    vio_0 your_instance_name (
    .clk                                (ad_9361_data_clk_40mhz          ),// input wire clk
    .probe_out0                         (AD9361_Valid              ),// output wire [0 : 0] probe_out0
    .probe_out1                         (AD9361_LoFreq_Tx          ),// output wire [31 : 0] probe_out1
    .probe_out2                         (AD9361_LoFreq_Rx          ),// output wire [31 : 0] probe_out2
    .probe_out3                         (AD9361_rxGain_CH0         ),// output wire [15 : 0] probe_out3
    .probe_out4                         (AD9361_rxGain_CH1          ) // output wire [15 : 0] probe_out4
    );


    AD9361_Top u_AD9361_Top (
    .clk_in                             (mb_clock                  ),
    .rst_n_in                           (g_clock_mmcm_locked       ),
    // AD9361 Interface
    .i_rx_clk_in_p                      (i_rx_clk_in_p             ),
    .i_rx_clk_in_n                      (i_rx_clk_in_n             ),
    .i_rx_frame_in_p                    (i_rx_frame_in_p           ),
    .i_rx_frame_in_n                    (i_rx_frame_in_n           ),
    .i_rx_data_in_p                     (i_rx_data_in_p            ),
    .i_rx_data_in_n                     (i_rx_data_in_n            ),
    .o_tx_clk_out_p                     (o_tx_clk_out_p            ),
    .o_tx_clk_out_n                     (o_tx_clk_out_n            ),
    .o_tx_frame_out_p                   (o_tx_frame_out_p          ),
    .o_tx_frame_out_n                   (o_tx_frame_out_n          ),
    .o_tx_data_out_p                    (o_tx_data_out_p           ),
    .o_tx_data_out_n                    (o_tx_data_out_n           ),
    .o_gpio_txnrx                       (o_gpio_txnrx              ),
    .o_gpio_enable                      (o_gpio_enable             ),
    .o_gpio_resetb                      (o_gpio_resetb             ),
    .o_gpio_en_agc                      (o_gpio_en_agc             ),
    .o_gpio_ctl                         (o_gpio_ctl                ),
    .o_fmc_spi_cs_n                     (o_fmc_spi_cs_n            ),
    .o_fmc_spi_clk                      (o_fmc_spi_clk             ),
    .o_fmc_spi_mosi                     (o_fmc_spi_mosi            ),
    .i_fmc_spi_miso                     (i_fmc_spi_miso            ),
    // usr_Interface
    .AD9361_UserClk_40M_i               (ad_9361_data_clk_40mhz   ),//i
    .ad_9361_data_clk_40mhz_rst         (g_clock_mmcm_locked       ),//i
    .AD9361_clk_40Mhz                   (AD9361_clk_40Mhz          ),//o
    .AD9361_rst                         (AD9361_rst                ),//o
    
    .AD9361_rx_data_clk_160Mhz          (AD9361_rx_data_clk_160Mhz ),

    // usr_Ctrl_Interface
    .AD9361_Valid                       (AD9361_Valid              ),
    .AD9361_LoFreq_Rx                   (AD9361_LoFreq_Rx          ),
    .AD9361_LoFreq_Tx                   (AD9361_LoFreq_Tx          ),
    .AD9361_rxGain_CH0                  (AD9361_rxGain_CH0         ),
    .AD9361_rxGain_CH1                  (AD9361_rxGain_CH1         ),
    .AD9361_txATT_Valid                 (AD9361_txATT_Valid        ),
    .AD9361_txATT_CH0                   (AD9361_txATT_CH0          ),
    .AD9361_txATT_CH1                   (AD9361_txATT_CH1          ),
    // usr_Data_Interface
    .AD9361_Data_Rx_SYNC_CH1            (AD9361_Data_Rx_SYNC_CH1   ),
    .AD9361_Data_Rx_SYNC_CH2            (AD9361_Data_Rx_SYNC_CH2   ),
    .AD9361_Data_Tx_SYNC_CH1            (AD9361_Data_Tx_SYNC_CH1   ),
    .AD9361_Data_Tx_SYNC_CH2            (AD9361_Data_Tx_SYNC_CH2   ) 
    );

    assign AD9361_Data_Tx_SYNC_CH1 = 32'h03FF_0000 ;
    assign AD9361_Data_Tx_SYNC_CH2 = 32'h03FF_0000 ;

    assign trx_clock = ad_9361_data_clk_40mhz;
    assign trx_rst   = ~g_clock_mmcm_locked      ;

    ila_64Xbit ila_rx_ad (
	.clk(ad_9361_data_clk_40mhz), // input wire clk

	.probe0({
        AD9361_Data_Rx_SYNC_CH1,
        AD9361_Data_Rx_SYNC_CH2
    }) // input wire [63:0] probe0
);


    //###########################################################
    //#####################  信号处理部分 ########################
    //###########################################################
    
    // ===================================================
    // Instantiate CSS_Modulator (调制器)
    // ===================================================


    wire        frame_bitIdle ;
    wire        frame_bitReady;
    wire [15:0] frame_bitCount;
    wire        frame_bitRequest;
    wire        frame_bitData;
    wire        frame_bitValid;

    wire frame_uart_rxd;
    assign frame_uart_rxd = rs232_uart_rxd;

    FramePackage_Recv #(
    .CLOCK_PEROID                       (TRX_CLOCK_PERIOD          ),
    .UART_BPS_RX                        (115200           )        ) 
    FramePackage_Recv (
    .clock                              (trx_clock                 ),//i
    .rst                                (trx_rst                   ),//i
    
    .uart_rxd                           (frame_uart_rxd            ),//i
    
    .frame_bitIdle                      (frame_bitIdle             ),//i
    .frame_bitReady                     (frame_bitReady            ),//O
    .frame_bitCount                     (frame_bitCount            ),//o

    .frame_bitRequest                   (frame_bitRequest          ),//i
    .frame_bitData                      (frame_bitData             ),//o
    .frame_bitValid                     (frame_bitValid            ) //o
    );


    wire          config_valid;
    wire  [7:0]   config_sfSel;   
    wire  [7:0]   config_bwSel;   
    wire  [15:0]  config_nfft;   
    wire  [15:0]  config_fftPoint;   

    
    wire  bb_moduSigValid;
    wire  [16*2-1:0]  bb_moduSigOut;

    CSS_Modulator #(
    .CLOCK_FREQUENCY_MHZ                (TRX_CLOCK_PERIOD/1000_000 ) 
    )CSS_Modulator (
    .clock                              (trx_clock                 ),//i
    .rst                                (trx_rst                   ),//i
    .config_valid                       (config_valid              ),//i
    .config_sfSel                       (config_sfSel              ),//i
    // .config_bwSel      ( config_bwSel       ),
    .frame_bitIdle                      (frame_bitIdle             ),//o 
    .frame_bitReady                     (frame_bitReady            ),//i
    .frame_bitCount                     (frame_bitCount            ),//i
    .frame_bitRequest                   (frame_bitRequest          ),//o
    .frame_bitData                      (frame_bitData             ),//i
    .frame_bitValid                     (frame_bitValid            ),//i
    
    .moduSigValid                       (bb_moduSigValid           ),//o
    .moduSigOut                         (bb_moduSigOut             ) //o
    );

    wire                                if_moduSigOutValid          ;
    wire                 [16*2-1: 0]    if_moduSigOut               ;

    Resample_Up #(
    .DWIDTH                             (16                        ),
    .CHANNEL                            (2                          )                     
    ) Resample_Up (
    .clock                              (trx_clock                 ),//i
    .rst                                (trx_rst                   ),//i
    .SampleIn_Dat                       (bb_moduSigOut             ),//i
    .SampleIn_Val                       (bb_moduSigValid           ),//i
    
    .SampleOut_Dat                      (if_moduSigOut             ),//o
    .SampleOut_Val                      (if_moduSigOutValid        ) //o
    );

    // assign AD9361_Data_Tx_SYNC_CH1 = if_moduSigOut;
    // assign AD9361_Data_Tx_SYNC_CH2 = if_moduSigOut;

    // ===================================================
    // Instantiate CSS_DeModulator (解调器)
    // ===================================================


    // #TAG CSS_DeModulator
    wire  [16*2-1:0]  if_moduSigIn;
    wire  if_moduSigInValid;

    Resample_Down #(
    .DWIDTH                             (16                        ),
    .CHANNEL                            (2  )                      ) 
    Resample_Down (
    .clock                              (trx_clock                 ),
    .rst                                (trx_rst                   ),
    .SampleIn_Dat                       (AD9361_Data_Rx_SYNC_CH1   ),
    .SampleIn_Val                       (1'b1                      ),
    
    .SampleOut_Dat                      (if_moduSigIn              ),
    .SampleOut_Val                      (if_moduSigInValid         ) 
    );

    wire [15:0] decode_dat;
    wire        decode_val;
    wire decode_end;

    wire frame_uart_txd;
    
    CSS_DeModulator #(
    .CLOCK_FREQUENCY_MHZ                (TRX_CLOCK_PERIOD/1000_000 )) 
    CSS_DeModulator (
    .clock                              (trx_clock                 ),//i
    .rst                                (trx_rst                   ),//i
    
    .sigInIQ                            (if_moduSigIn              ),//i
    .sigInVal                           (if_moduSigInValid         ),//i
    
    .config_valid                       (config_valid              ),//i
    .config_sfSel                       (config_sfSel              ),//i
    .config_nfft                        (config_nfft               ),//i
    .config_fftPoint                    (config_fftPoint           ),//i
    
    .decode_end                         (decode_end                ),//o
    .decode_dat                         (decode_dat                ),//o
    .decode_val                         (decode_val                ) //o
    );

    FramePackage_Send #(
    .CLOCK_PEROID                       (TRX_CLOCK_PERIOD          ),
    .UART_BPS_TX                        (115200                    ) 
    )FramePackage_Send (
    .clock                              (trx_clock                 ),//i
    .rst                                (trx_rst                   ),//i
    .config_valid                       (config_valid              ),//i
    .config_sfSel                       (config_sfSel              ),//i
    .config_bwSel                       (config_bwSel              ),//i
    
    .decode_end                         (decode_end                ),//i
    .decode_dat                         (decode_dat                ),//i
    .decode_val                         (decode_val                ),//i
    
    .uart_txd                           (frame_uart_txd            ) //o
    );
    
    assign rs232_uart_txd = frame_uart_txd;


    //###########################################################
    //#####################  控制部分    ########################
    //###########################################################






endmodule