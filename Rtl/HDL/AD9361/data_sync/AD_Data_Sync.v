`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/03/07 09:21:06
// Design Name: 
// Module Name: AD_Data_Sync
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


module AD_Data_Sync(
    input l_clk,
    input l_rst_ni,

    input AD9361_UserClk_40M_i,

    input  [31:0] AD9361_Data_Rx_CH1,
    input  [31:0] AD9361_Data_Rx_CH2,
    output [31:0] AD9361_Data_Tx_CH1,
    output [31:0] AD9361_Data_Tx_CH2,

    output [31:0] AD9361_User_Data_Rx_SYNC_CH1_o,
    output [31:0] AD9361_User_Data_Rx_SYNC_CH2_o,  
    input  [31:0] AD9361_User_Data_Tx_SYNC_CH1_i,
    input  [31:0] AD9361_User_Data_Tx_SYNC_CH2_i

    );

    reg [7:0] cnt;
    always @ (posedge l_clk)
    begin
        if(!l_rst_ni) begin
            cnt <= 8'd0;
        end
        else begin
            if(cnt >= 8'd3) begin
                cnt <= 8'd0;
            end
            else begin
                cnt <= cnt + 1'd1;
            end
        end
    end

    wire ad_sync_en;
    assign ad_sync_en = (cnt == 8'd2) ? 1'b1 : 1'b0;

    wire [31:0] AD9361_Data_Rx_SYNC_CH1_W;
    wire [31:0] AD9361_Data_Rx_SYNC_CH2_W;
    FIFO_Data_Sync Data_Rx_CH1_sync (
        .rst        ( ~l_rst_ni                  ),          // input wire rst
        .wr_clk     ( l_clk                     ),          // input wire wr_clk
        .rd_clk     ( AD9361_UserClk_40M_i              ),          // input wire rd_clk
        .din        ( AD9361_Data_Rx_CH1        ),          // input wire [31 : 0] din
        .wr_en      ( ad_sync_en                ),          // input wire wr_en
        .rd_en      ( 1'd1                      ),          // input wire rd_en
        .dout       ( AD9361_Data_Rx_SYNC_CH1_W ),          // output wire [31 : 0] dout
        .full       (                           ),          // output wire full
        .empty      (                           )           // output wire empty
    );    

    FIFO_Data_Sync Data_Rx_CH2_sync (
        .rst        ( ~l_rst_ni                  ),          // input wire rst
        .wr_clk     ( l_clk                     ),          // input wire wr_clk
        .rd_clk     ( AD9361_UserClk_40M_i              ),          // input wire rd_clk
        .din        ( AD9361_Data_Rx_CH2        ),          // input wire [31 : 0] din
        .wr_en      ( ad_sync_en                ),          // input wire wr_en
        .rd_en      ( 1'd1                      ),          // input wire rd_en
        .dout       ( AD9361_Data_Rx_SYNC_CH2_W ),          // output wire [31 : 0] dout
        .full       (                           ),          // output wire full
        .empty      (                           )           // output wire empty
    );

    FIFO_Data_Sync Data_Tx_CH1_sync (
        .rst        ( ~l_rst_ni                  ),          // input wire rst
        .wr_clk     ( AD9361_UserClk_40M_i              ),          // input wire wr_clk
        .rd_clk     ( l_clk                     ),          // input wire rd_clk
        .din        ( AD9361_User_Data_Tx_SYNC_CH1_i   ),        // input wire [31 : 0] din
        .wr_en      ( 1'b1                      ),          // input wire wr_en
        .rd_en      ( ad_sync_en                ),          // input wire rd_en
        .dout       ( AD9361_Data_Tx_CH1        ),          // output wire [31 : 0] dout
        .full       (                           ),          // output wire full
        .empty      (                           )           // output wire empty
    );

    FIFO_Data_Sync Data_Tx_CH2_sync (
        .rst        ( ~l_rst_ni                  ),          // input wire rst
        .wr_clk     ( AD9361_UserClk_40M_i              ),          // input wire wr_clk
        .rd_clk     ( l_clk                     ),          // input wire rd_clk
        .din        ( AD9361_User_Data_Tx_SYNC_CH2_i   ),        // input wire [31 : 0] din
        .wr_en      ( 1'b1                      ),          // input wire wr_en
        .rd_en      ( ad_sync_en                ),          // input wire rd_en
        .dout       ( AD9361_Data_Tx_CH2        ),          // output wire [31 : 0] dout
        .full       (                           ),          // output wire full
        .empty      (                           )           // output wire empty
    );

    assign AD9361_User_Data_Rx_SYNC_CH1_o = {{(4){AD9361_Data_Rx_SYNC_CH1_W[27]}},AD9361_Data_Rx_SYNC_CH1_W[27:16],
                                        {(4){AD9361_Data_Rx_SYNC_CH1_W[11]}},AD9361_Data_Rx_SYNC_CH1_W[11:0]};

    assign AD9361_User_Data_Rx_SYNC_CH2_o = {{(4){AD9361_Data_Rx_SYNC_CH2_W[27]}},AD9361_Data_Rx_SYNC_CH2_W[27:16],
                                        {(4){AD9361_Data_Rx_SYNC_CH2_W[11]}},AD9361_Data_Rx_SYNC_CH2_W[11:0]};

endmodule
