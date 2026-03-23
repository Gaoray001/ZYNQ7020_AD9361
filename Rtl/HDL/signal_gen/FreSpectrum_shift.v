`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026年3月11日13:27:46
// Design Name: 
// Module Name: Signal_FixedFrequency
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


module Signal_FixedFrequency(
    input clock,
    input rst,
    input  [15:0] config_freCode,
    output [32-1:0] sigOut,
    output          sigOut_valid
    );

    reg [15:0] LoFreCode_r;
    always @(posedge clock) begin
        if(rst) begin
            LoFreCode_r <= 16'b0;
        end
        else begin
            LoFreCode_r <= config_freCode;
        end
    end
    // #### DDS Generator
    reg         s_axis_phase_tvalid;
    reg [15:0]  s_axis_phase_tdata ;
    always @(posedge clock) begin
        if(rst) begin
            s_axis_phase_tvalid <= 1'b0;
            s_axis_phase_tdata  <= 16'b0;
        end
        else begin
            s_axis_phase_tvalid <= 1'b1;
            s_axis_phase_tdata  <= s_axis_phase_tdata + LoFreCode_r;
        end
    end

    wire        dds_tvalid;
    wire [31:0] dds_tdata ;
    DDS_16X16 DDS_16X16 (
        .aclk               (clock              ), // input wire aclk
        .aresetn            (~rst               ), // input wire aresetn
        .s_axis_phase_tvalid(s_axis_phase_tvalid), // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata (s_axis_phase_tdata ), // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid (dds_tvalid         ), // output wire m_axis_data_tvalid
        .m_axis_data_tdata  (dds_tdata          )  // output wire [31 : 0] m_axis_data_tdata
    );

    assign sigOut       = dds_tdata;
    assign sigOut_valid = dds_tvalid;

endmodule
