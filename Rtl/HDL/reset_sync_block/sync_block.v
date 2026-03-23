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
module sync_block #(
    parameter INITIALISE = 1'b0,
    parameter DEPTH = 5
    )
    (
    input        clk,              // clock to be sync'ed to
    input        data_in,          // Data to be 'synced'
    output       data_out          // synced data
    );

    // Internal Signals
    wire   data_sync0;
    wire   data_sync1;
    wire   data_sync2;
    wire   data_sync3;
    wire   data_sync4;


    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDRE #(
        .INIT (INITIALISE[0])
    ) data_sync_reg0 (
        .C  (clk),
        .D  (data_in),
        .Q  (data_sync0),
        .CE (1'b1),
        .R  (1'b0)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDRE #(
    .INIT (INITIALISE[0])
    ) data_sync_reg1 (
        .C  (clk),
        .D  (data_sync0),
        .Q  (data_sync1),
        .CE (1'b1),
        .R  (1'b0)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDRE #(
    .INIT (INITIALISE[0])
    ) data_sync_reg2 (
        .C  (clk),
        .D  (data_sync1),
        .Q  (data_sync2),
        .CE (1'b1),
        .R  (1'b0)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDRE #(
    .INIT (INITIALISE[0])
        ) data_sync_reg3 (
        .C  (clk),
        .D  (data_sync2),
        .Q  (data_sync3),
        .CE (1'b1),
        .R  (1'b0)
    );

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    FDRE #(
    .INIT (INITIALISE[0])
    ) data_sync_reg4 (
        .C  (clk),
        .D  (data_sync3),
        .Q  (data_sync4),
        .CE (1'b1),
        .R  (1'b0)
    );

    assign data_out = data_sync4;

endmodule
