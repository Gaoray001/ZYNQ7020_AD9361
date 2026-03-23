`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: RK_ZY
// 
// Create Date: 2022/08/20 10:19:31
// Design Name: 
// Module Name: sync_block
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


(* dont_touch = "yes" *)
module reset_sync #(
    parameter INITIALISE = 1'b1,
    parameter DEPTH = 5         )
    (
        input       reset_in,
        input       clk,
        input       enable,
        output      reset_out
    );


    wire     reset_sync_reg0;
    wire     reset_sync_reg1;
    wire     reset_sync_reg2;
    wire     reset_sync_reg3;
    wire     reset_sync_reg4;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDPE #(
    .INIT (INITIALISE[0])
    ) reset_sync0 (
        .C  (clk),
        .CE (enable),
        .PRE(reset_in),
        .D  (1'b0),
        .Q  (reset_sync_reg0)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDPE #(
    .INIT (INITIALISE[0])
    ) reset_sync1 (
        .C  (clk),
        .CE (enable),
        .PRE(reset_in),
        .D  (reset_sync_reg0),
        .Q  (reset_sync_reg1)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDPE #(
    .INIT (INITIALISE[0])
    ) reset_sync2 (
        .C  (clk),
        .CE (enable),
        .PRE(reset_in),
        .D  (reset_sync_reg1),
        .Q  (reset_sync_reg2)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDPE #(
    .INIT (INITIALISE[0])
    ) reset_sync3 (
        .C  (clk),
        .CE (enable),
        .PRE(reset_in),
        .D  (reset_sync_reg2),
        .Q  (reset_sync_reg3)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDPE #(
    .INIT (INITIALISE[0])
    ) reset_sync4 (
        .C  (clk),
        .CE (enable),
        .PRE(reset_in),
        .D  (reset_sync_reg3),
        .Q  (reset_sync_reg4)
    );


    assign reset_out = reset_sync_reg4;


endmodule
