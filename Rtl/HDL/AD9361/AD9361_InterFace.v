`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/30 13:46:28
// Design Name: 
// Module Name: AD9361_InterFace
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


module AD9361_InterFace(
    input           clk,
    input           rst,
    input           AD9361_Valid,           //AD9361接口控制触发标志

    input [31:0]    AD9361_LoFreq_Rx,       //AD9361接口控制-接收本振   KHz
    input [31:0]    AD9361_LoFreq_Tx,       //AD9361接口控制-发送本振   KHz

    input [15:0]    AD9361_rxGain_CH0,      //AD9361接口控制-接收增益通道0
    input [15:0]    AD9361_rxGain_CH1,      //AD9361接口控制-接收增益通道1

    input           AD9361_txATT_Valid,
    input [15:0]    AD9361_txATT_CH0,       //AD9361接口控制-发送衰减通道0  db
    input [15:0]    AD9361_txATT_CH1,       //AD9361接口控制-发送衰减通道1  db

    output                  AD9361_Ctrl_Enable,
    output reg  [3: 0]      Rx_VcoDivider,
    output reg  [3: 0]      Tx_VcoDivider,
    output reg  [10:0]      Rx_FreqInteger,
    output reg  [22:0]      Rx_FreqFractional,
    output reg  [10:0]      Tx_FreqInteger,
    output reg  [22:0]      Tx_FreqFractional,

    output wire             TX_ATT_Valid    ,
    output wire [15:0]      Tx0_ATT_data    ,
    output wire [15:0]      Tx1_ATT_data
    );

    localparam  CLK_US = 40;
    localparam  FREQ_LO_COE = 1000;
    localparam  TXATT_COE   = 100;  
    localparam  HALF_COE    = 40_000_000;
    localparam  RFPLL_FREQ  = 80_000_000;
    localparam  ATT_RATE    = 25;


    reg [7:0] AD9361_Valid_buf;
    always @ (posedge clk)
    begin
        if(rst) begin
            AD9361_Valid_buf <= 8'b0;
        end else begin
            AD9361_Valid_buf <= {AD9361_Valid_buf[6:0],AD9361_Valid};
        end 
    end

    wire AD9361_Valid_r2;
    assign AD9361_Valid_r2 = AD9361_Valid_buf[7:7];

    reg [33:0] Rx_freq      ;
    reg [33:0] Tx_freq      ;
    reg [15:0] rxGain_CH0   ;
    reg [15:0] rxGain_CH1   ;
    reg [15:0] txATT_CH0    ;
    reg [15:0] txATT_CH1    ;
    always @ (posedge clk)
    begin
        if(rst) begin
            Rx_freq     <= 34'd1_800_000_000;
            Tx_freq     <= 34'd1_800_000_000;
            rxGain_CH0  <= 16'h1C;
            rxGain_CH1  <= 16'h1C;
            // txATT_CH0   <= 16'b0;
            // txATT_CH1   <= 16'b0;
        end else if(AD9361_Valid) begin
            Rx_freq     <= AD9361_LoFreq_Rx * FREQ_LO_COE;
            Tx_freq     <= AD9361_LoFreq_Tx * FREQ_LO_COE;
            rxGain_CH0  <= AD9361_rxGain_CH0;
            rxGain_CH1  <= AD9361_rxGain_CH1;
            // txATT_CH0   <= AD9361_txATT_CH0 * TXATT_COE;
            // txATT_CH1   <= AD9361_txATT_CH1 * TXATT_COE;      
        end else begin
            Rx_freq     <= Rx_freq    ;
            Tx_freq     <= Tx_freq    ;
            rxGain_CH0  <= rxGain_CH0 ;
            rxGain_CH1  <= rxGain_CH1 ;
            // txATT_CH0   <= txATT_CH0  ;
            // txATT_CH1   <= txATT_CH1  ;
        end
    end

    // reg [3:0] Rx_VcoDivider;
    always @(posedge clk ) 
    begin
        if ( (Rx_freq >= 34'd46875000) && (Rx_freq < 34'd93750000) )            //  70MHz~93.75MHz
             Rx_VcoDivider <= 3'd6;
        else if ( (Rx_freq >= 34'd93750000  ) && (Rx_freq < 34'd187500000  ) )  //  93.75MHz~187.5MHz
             Rx_VcoDivider <= 3'd5;
        else if ( (Rx_freq >= 34'd187500000 ) && (Rx_freq < 34'd375000000  ) )  //  187.5MHz~375MHz
             Rx_VcoDivider <= 3'd4;
        else if ( (Rx_freq >= 34'd375000000 ) && (Rx_freq < 34'd750000000  ) )  //  375MHz~750MHz
             Rx_VcoDivider <= 3'd3;
        else if ( (Rx_freq >= 34'd750000000 ) && (Rx_freq < 34'd1500000000 ) )  //  750MHz~1500MHz
             Rx_VcoDivider <= 3'd2;
        else if ( (Rx_freq >= 34'd1500000000) && (Rx_freq < 34'd3000000000 ) )  //  1500MHz~3000MHz
             Rx_VcoDivider <= 3'd1;
        else if ( (Rx_freq >= 34'd3000000000) && (Rx_freq <= 34'd6000000000) )  //  3000MHz~6000MHz
             Rx_VcoDivider <= 3'd0;
        else                                                                    //  illegal value
             Rx_VcoDivider <= 3'd7; 
    end 

    // reg [3:0] Tx_VcoDivider;
    always @(posedge clk ) 
    begin
        if ( (Tx_freq >= 34'd46875000) && (Tx_freq < 34'd93750000) )            //  70MHz~93.75MHz
            Tx_VcoDivider <= 3'd6;
        else if ( (Tx_freq >= 34'd93750000  ) && (Tx_freq < 34'd187500000  ) )  //  93.75MHz~187.5MHz
            Tx_VcoDivider <= 3'd5;
        else if ( (Tx_freq >= 34'd187500000 ) && (Tx_freq < 34'd375000000  ) )  //  187.5MHz~375MHz
            Tx_VcoDivider <= 3'd4;
        else if ( (Tx_freq >= 34'd375000000 ) && (Tx_freq < 34'd750000000  ) )  //  375MHz~750MHz
            Tx_VcoDivider <= 3'd3;
        else if ( (Tx_freq >= 34'd750000000 ) && (Tx_freq < 34'd1500000000 ) )  //  750MHz~1500MHz
            Tx_VcoDivider <= 3'd2;
        else if ( (Tx_freq >= 34'd1500000000) && (Tx_freq < 34'd3000000000 ) )  //  1500MHz~3000MHz
            Tx_VcoDivider <= 3'd1;
        else if ( (Tx_freq >= 34'd3000000000) && (Tx_freq <= 34'd6000000000) )  //  3000MHz~6000MHz
            Tx_VcoDivider <= 3'd0;
        else                                                                    //  illegal value
            Tx_VcoDivider <= 3'd7;
    end    

    reg     [33:0]  Rx_dividend1;
    always @ (posedge clk)
    begin
        case(Rx_VcoDivider)
            3'd0   : Rx_dividend1 <= {Rx_freq,1'b0};
            3'd1   : Rx_dividend1 <= {Rx_freq,2'b0};
            3'd2   : Rx_dividend1 <= {Rx_freq,3'b0};
            3'd3   : Rx_dividend1 <= {Rx_freq,4'b0};
            3'd4   : Rx_dividend1 <= {Rx_freq,5'b0};
            3'd5   : Rx_dividend1 <= {Rx_freq,6'b0};
            3'd6   : Rx_dividend1 <= {Rx_freq,7'b0};
            default: Rx_dividend1 <= 34'b0;
        endcase
    end
    
    reg     [33:0]  Tx_dividend1;
    always @ (posedge clk)
    begin
        case(Tx_VcoDivider)
            3'd0   : Tx_dividend1 <= {Tx_freq,1'b0};
            3'd1   : Tx_dividend1 <= {Tx_freq,2'b0};
            3'd2   : Tx_dividend1 <= {Tx_freq,3'b0};
            3'd3   : Tx_dividend1 <= {Tx_freq,4'b0};
            3'd4   : Tx_dividend1 <= {Tx_freq,5'b0};
            3'd5   : Tx_dividend1 <= {Tx_freq,6'b0};
            3'd6   : Tx_dividend1 <= {Tx_freq,7'b0};
            default: Tx_dividend1 <= 34'b0;
        endcase
    end

    wire Rx_dividend1_tvalid_sub;
    wire [65:0] Rx_dividend1_data_sub;
    div_idendFreq u_div_idendFreq_Rx (
        .aclk(clk),                                                 // input wire aclk
        .s_axis_divisor_tvalid      (AD9361_Valid_r2        ),      // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata       (RFPLL_FREQ             ),      // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid     (AD9361_Valid_r2        ),      // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata      (Rx_dividend1           ),      // input wire [39 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid         (Rx_dividend1_tvalid_sub),      // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata          (Rx_dividend1_data_sub  )       // output wire [71 : 0] m_axis_dout_tdata
    );

    wire Tx_dividend1_tvalid_sub;
    wire [65:0] Tx_dividend1_data_sub;
    div_idendFreq u_div_idendFreq_Tx (
        .aclk(clk),                                                 // input wire aclk
        .s_axis_divisor_tvalid      (AD9361_Valid_r2        ),      // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata       (RFPLL_FREQ             ),      // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid     (AD9361_Valid_r2        ),      // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata      (Tx_dividend1           ),      // input wire [39 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid         (Tx_dividend1_tvalid_sub),      // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata          (Tx_dividend1_data_sub  )       // output wire [71 : 0] m_axis_dout_tdata
    );

    reg Rx_dividend1_tvalid_sub_r;
    always @ (posedge clk)
    begin
        if(rst) begin
            Rx_dividend1_tvalid_sub_r <= 'b0;
        end else begin
            Rx_dividend1_tvalid_sub_r <= Rx_dividend1_tvalid_sub;
        end
    end

    // reg [10:0] Rx_FreqInteger;
    reg [55:0] Rx_dividend2;
    always @ (posedge clk)
    begin
        if(rst) begin
            Rx_FreqInteger <= 'b0;
            Rx_dividend2   <= 'b0;
        end else if(Rx_dividend1_tvalid_sub) begin
            Rx_FreqInteger <= Rx_dividend1_data_sub[42:32];
            Rx_dividend2   <= {Rx_dividend1_data_sub[31:0],23'b0} + Rx_dividend1_data_sub[31:0] - {Rx_dividend1_data_sub[31:0],4'b0};
        end else begin
            Rx_FreqInteger <= Rx_FreqInteger;
            Rx_dividend2   <= Rx_dividend2  ;
        end
    end

    reg Tx_dividend1_tvalid_sub_r;
    always @ (posedge clk)
    begin
        if(rst) begin
            Tx_dividend1_tvalid_sub_r <= 'b0;
        end else begin
            Tx_dividend1_tvalid_sub_r <= Tx_dividend1_tvalid_sub;
        end
    end
    // reg [10:0] Tx_FreqInteger;
    reg [55:0] Tx_dividend2;
    always @ (posedge clk)
    begin
        if(rst) begin
            Tx_FreqInteger <= 'b0;
            Tx_dividend2   <= 'b0;
        end else if(Tx_dividend1_tvalid_sub) begin
            Tx_FreqInteger <= Tx_dividend1_data_sub[42:32];
            Tx_dividend2   <= {Tx_dividend1_data_sub[31:0],23'b0} + Tx_dividend1_data_sub[31:0] - {Tx_dividend1_data_sub[31:0],4'b0};
        end else begin
            Tx_FreqInteger <= Tx_FreqInteger;
            Tx_dividend2   <= Tx_dividend2  ;
        end
    end   


    wire [55:0] Rx_qut ;
    wire [31:0] Rx_remain ;
    div_calfreq U_div_calfreq_rx(
        .aclk                   (clk),
        .s_axis_divisor_tvalid  (Rx_dividend1_tvalid_sub_r),
        .s_axis_divisor_tdata   (RFPLL_FREQ[31:0]),
        .s_axis_dividend_tvalid (Rx_dividend1_tvalid_sub_r),
        .s_axis_dividend_tdata  (Rx_dividend2[55:0]) ,
        .m_axis_dout_tvalid     (RX_RDY),
        .m_axis_dout_tdata      ({Rx_qut,Rx_remain})
    );
    
    wire [55:0] Tx_qut ;
    wire [31:0] Tx_remain ;
    
    div_calfreq U_div_calfreq_Tx(
        .aclk                   (clk),
        .s_axis_divisor_tvalid  (Tx_dividend1_tvalid_sub_r),
        .s_axis_divisor_tdata   (RFPLL_FREQ[31:0]),
        .s_axis_dividend_tvalid (Tx_dividend1_tvalid_sub_r),
        .s_axis_dividend_tdata  (Tx_dividend2[49:0]) ,
        .m_axis_dout_tvalid     (TX_RDY),
        .m_axis_dout_tdata      ({Tx_qut,Tx_remain})
    );

    // reg [22:0] Rx_FreqFractional;
    always @(posedge clk)begin
        if (RX_RDY)
        begin
              if(Rx_remain[31:0] >= HALF_COE)
                Rx_FreqFractional <= Rx_qut + 56'b1; 
            else 
                Rx_FreqFractional <= Rx_qut ;                         
        end  
        else 
            ; 
    end 

    // reg [22:0] Tx_FreqFractional;
    always @(posedge clk)begin
        if (TX_RDY)
        begin 
              if(Tx_remain[31:0] >= HALF_COE)
                Tx_FreqFractional <= Tx_qut + 56'b1;
            else    
                Tx_FreqFractional <= Tx_qut; 
         end  
        else 
            ;
    end
   
    reg [15:0] time_cnt;
    reg AD9361_Ctrl_Enable_r;
    always @(posedge clk)begin
        if(rst)
            AD9361_Ctrl_Enable_r <= 1'b0;
        else if (RX_RDY) 
            AD9361_Ctrl_Enable_r <= 1'd1;
        else if(time_cnt >= CLK_US)
           AD9361_Ctrl_Enable_r <= 1'd0;
        else 
            AD9361_Ctrl_Enable_r <= AD9361_Ctrl_Enable_r;
    end
    assign AD9361_Ctrl_Enable = AD9361_Ctrl_Enable_r;

    always @(posedge clk)begin
        if(rst) 
            time_cnt <= 16'd0;
        else if(AD9361_Ctrl_Enable_r) 
            time_cnt <= time_cnt + 1'd1;
        else 
            time_cnt <= 16'd0;
    end  



///////////////AD9361_ATT
    reg AD9361_txATT_Valid_r;
    always @ (posedge clk)
    begin
        if(rst) begin
            AD9361_txATT_Valid_r <= 'b0;
        end
        else begin
            AD9361_txATT_Valid_r <= AD9361_txATT_Valid;
        end 
    end

    always @ (posedge clk)
    begin
        if(rst) begin
            txATT_CH0   <= 16'b0;
            txATT_CH1   <= 16'b0;
        end
        else if(AD9361_txATT_Valid) begin
            txATT_CH0   <= AD9361_txATT_CH0 * TXATT_COE;
            txATT_CH1   <= AD9361_txATT_CH1 * TXATT_COE;      
        end
        else begin
            txATT_CH0   <= txATT_CH0  ;
            txATT_CH1   <= txATT_CH1  ;
        end 
    end 

    wire ATT_CH0_Valid;
    wire [31:0] ATT_CH0_Data;
    DIV_ATT AD_ATT_CH0 (
      .aclk(clk),                                      // input wire aclk
      .s_axis_divisor_tvalid(AD9361_txATT_Valid_r),    // input wire s_axis_divisor_tvalid
      .s_axis_divisor_tdata(ATT_RATE),      // input wire [15 : 0] s_axis_divisor_tdata
      .s_axis_dividend_tvalid(AD9361_txATT_Valid_r),  // input wire s_axis_dividend_tvalid
      .s_axis_dividend_tdata(txATT_CH0),    // input wire [15 : 0] s_axis_dividend_tdata
      .m_axis_dout_tvalid(ATT_CH0_Valid),          // output wire m_axis_dout_tvalid
      .m_axis_dout_tdata(ATT_CH0_Data)            // output wire [31 : 0] m_axis_dout_tdata
    );

    wire ATT_CH1_Valid;
    wire [31:0] ATT_CH1_Data;
    DIV_ATT AD_ATT_CH1 (
      .aclk(clk),                                      // input wire aclk
      .s_axis_divisor_tvalid(AD9361_txATT_Valid_r),    // input wire s_axis_divisor_tvalid
      .s_axis_divisor_tdata(ATT_RATE),      // input wire [15 : 0] s_axis_divisor_tdata
      .s_axis_dividend_tvalid(AD9361_txATT_Valid_r),  // input wire s_axis_dividend_tvalid
      .s_axis_dividend_tdata(txATT_CH1),    // input wire [15 : 0] s_axis_dividend_tdata
      .m_axis_dout_tvalid(ATT_CH1_Valid),          // output wire m_axis_dout_tvalid
      .m_axis_dout_tdata(ATT_CH1_Data)            // output wire [31 : 0] m_axis_dout_tdata
    );


    reg [15:0] att_time_cnt;
    reg ATT_CH0_Valid_r;
    always @(posedge clk)begin
        if(rst)
            ATT_CH0_Valid_r <= 1'b0;
        else if (ATT_CH0_Valid) 
            ATT_CH0_Valid_r <= 1'd1;
        else if(att_time_cnt >= CLK_US)
            ATT_CH0_Valid_r <= 1'd0;
        else 
            ATT_CH0_Valid_r <= ATT_CH0_Valid_r;
    end

    always @(posedge clk)begin
        if(rst) 
            att_time_cnt <= 16'd0;
        else if(ATT_CH0_Valid_r) 
            att_time_cnt <= att_time_cnt + 1'd1;
        else 
            att_time_cnt <= 16'd0;
    end  


    assign TX_ATT_Valid = ATT_CH0_Valid_r;
    assign Tx0_ATT_data = ATT_CH0_Data[31:16];
    assign Tx1_ATT_data = ATT_CH1_Data[31:16];

    // ila_256Xbit ila_face (
	// .clk(clk), // input wire clk

	// .probe0({
    //     'b0,
    //     AD9361_txATT_Valid,
    //     ATT_CH0_Valid_r,
    //     ATT_CH0_Valid,
    //     Tx0_ATT_data,
    //     Tx1_ATT_data,
    //     AD9361_txATT_CH1,
    //     AD9361_txATT_CH0,
    //     txATT_CH0,
    //     txATT_CH1,
    //     TX_ATT_Valid
    // })); // input wire [255:0] probe0

    // ila_256Xbit ila_face (
	// .clk(clk), // input wire clk

	// .probe0({
    //     'b0,
    //     AD9361_Valid,      
    //     AD9361_LoFreq_Rx,  
    //     AD9361_LoFreq_Tx,  
    //     Rx_freq,
    //     Tx_freq
    // })); // input wire [255:0] probe0

 
endmodule
