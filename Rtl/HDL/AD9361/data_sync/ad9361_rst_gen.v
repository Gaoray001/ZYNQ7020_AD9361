`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/06 09:35:28
// Design Name: 
// Module Name: ad9361_rst_gen
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


module ad9361_rst_gen(
        input  wire clk,
        input  wire rst_n_i,
        output wire rst_o
    );

    reg [31:0] clk_cnt;
    reg rst_n;
    always @ (posedge clk) begin
        if (!rst_n_i) begin
            clk_cnt <= 32'b0;
            rst_n   <= 1'b0;
        end
        else begin
            if (clk_cnt >= 32'd160_000_000) begin
                clk_cnt <= 32'd160_000_000;
                rst_n   <= 1'b1;
            end
            else begin
                clk_cnt <= clk_cnt + 1'b1;
                if ((clk_cnt > 32'd40_000_000) && (clk_cnt < 32'd160_000_000)) begin
                    rst_n <= 1'b0;
                end
                else begin
                    rst_n <= 1'b0;
                end
            end
        end
    end
 
    BUFG reset_BUFG (
    .I(rst_n),  // 1-bit input: Clock input
    .O(rst_o) // 1-bit output: Clock output
    );
    
        
endmodule
