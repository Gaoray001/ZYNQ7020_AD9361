/*
note: 1. 该模块用于将AD9361的LVDS差分时钟输入转换为单端时钟输出，并根据参数选择使用BUFR或BUFG进行时钟缓冲。

  情况1：当ad9361的rx_clk_in_p/n 由CCIO进入

  CCIO -> IBUFGDS (差分输入缓冲器) - > BUFR/BUFG (时钟缓冲器) -> clk (单端时钟输出)

  情况2：当ad9361的rx_clk_in_p/n 由普通IO进入
  非CCIO -> IBUFDS (差分输入缓冲器) - > BUFR -> BUFG (时钟缓冲器) -> clk (单端时钟输出)

*/
`timescale 1ns/100ps





// module ad_lvds_clk (

//   clk_in_p,
//   clk_in_n,
//   clk);

//   parameter   BUFTYPE       = 0;
//   localparam  SERIES7       = 0;
//   localparam  VIRTEX6       = 1;

//   input     clk_in_p;
//   input     clk_in_n;
//   output    clk;

//   // wires

//   wire      clk_ibuf_s;
//   wire      clk_ibuf_d;

//   // instantiations

//     IBUFGDS  #(
//       .DIFF_TERM("TRUE"),    // Differential Termination
//       .IBUF_LOW_PWR("TRUE"),  // Low power="TRUE", Highest performance="FALSE" 
//       .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
//     ) i_rx_clk_ibuf (
//     .I (clk_in_p),
//     .IB (clk_in_n),
//     .O (clk_ibuf_d));


//   assign    clk_ibuf_s = clk_ibuf_d; 

//   generate
//   if (BUFTYPE == VIRTEX6) begin
//     BUFR #(.BUFR_DIVIDE("BYPASS")) i_clk_rbuf (
//       .CLR (1'b0),
//       .CE (1'b1),
//       .I (clk_ibuf_s),
//       .O (clk));
//   end 
//   else begin
//     BUFG i_clk_gbuf (
//       .I (clk_ibuf_s),
//       .O (clk));
//   end
//   endgenerate


// endmodule



module ad_lvds_clk #(
    parameter BUFTYPE = 0
)(
    input  wire clk_in_p,
    input  wire clk_in_n,
    output wire clk
);

    wire clk_ibuf;

    IBUFDS #(
        .DIFF_TERM("TRUE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD("LVDS")
    ) u_ibufds (
        .I  (clk_in_p),
        .IB (clk_in_n),
        .O  (clk_ibuf)
    );

    wire clk_obufr;

    BUFR #(
        .BUFR_DIVIDE("BYPASS"),
        .SIM_DEVICE("7SERIES")
    ) u_bufr (
        .I   (clk_ibuf),
        .CE  (1'b1),
        .CLR (1'b0),
        .O   (clk_obufr)
    );


    BUFG u_BUFG (
    .O                                  (clk                 ),// 1-bit output: Clock output
    .I                                  (clk_obufr                       ) // 1-bit input: Clock input
    );

endmodule