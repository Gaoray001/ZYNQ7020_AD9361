`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/06 09:36:53
// Design Name: 
// Module Name: clk_div4
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


module clk_div4(
    input         l_clk,
    input         i_rst_n,
    output        clk_div4
    );


    reg    [3:0]     clk_div4_cnt;
    reg              clk_div4_over_reg;    

    always@(posedge l_clk or negedge i_rst_n)                  //四分之一DATA_CLK时钟，等于AD9361采样率
    begin
        if(!i_rst_n) begin
             clk_div4_cnt<= 0;
        end
        else begin
            if(clk_div4_cnt < 2) begin
                clk_div4_cnt <= clk_div4_cnt + 1'b1;
                clk_div4_over_reg <= clk_div4_over_reg;
            end
            else begin
                clk_div4_over_reg <= ~clk_div4_over_reg;
                clk_div4_cnt <= 1;
            end 
        end
    end
            
    assign clk_div4 = clk_div4_over_reg;

endmodule
