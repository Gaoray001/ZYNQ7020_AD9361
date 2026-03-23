`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/14 15:06:40
// Design Name: 
// Module Name: FreSpectrum_shift
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


module FreSpectrum_shift(
    input clock,
    input rst,
    input  [15:0] config_freCode,
    input  [32-1:0] sigIn,
    input           sigIn_valid,
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
            if(sigIn_valid) begin
                s_axis_phase_tvalid <= 1'b1;
                s_axis_phase_tdata  <= s_axis_phase_tdata + LoFreCode_r;
            end
            else begin
                s_axis_phase_tvalid <= 1'b0;
                s_axis_phase_tdata  <= s_axis_phase_tdata;
            end
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

    reg [31:0] dds_tdata_r;
    reg        dds_tvalid_r;
    always @(posedge clock) begin
        if(rst) begin
            dds_tdata_r <= 32'b0;
        end
        else begin
            dds_tdata_r[0 +:16] <= dds_tdata[ 0+:16];
            dds_tdata_r[16+:16] <= ~dds_tdata[16+:16] + 1'b1;
            dds_tvalid_r        <= dds_tvalid;
        end
    end


    // #### Frequency Mixer
    wire cmpy_out_valid;
    wire [79:0] cmpy_out;
    reg  [15:0] CMult_i;
    reg  [15:0] CMult_q;
    reg         CMult_valid;

    cmpy_16X16 cmpy_16X16 (
        .aclk              (clock         ), // input wire aclk
        .aresetn           (~rst          ), // input wire aresetn
        .s_axis_a_tvalid   (sigIn_valid   ), // input wire s_axis_a_tvalid
        .s_axis_a_tdata    (dds_tdata_r   ), // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid   (sigIn_valid   ), // input wire s_axis_b_tvalid
        .s_axis_b_tdata    (sigIn         ), // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(cmpy_out_valid), // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata (cmpy_out      )  // output wire [79 : 0] m_axis_dout_tdata
    );

    always @(posedge clock) begin
        if(rst) begin
            CMult_i <= 16'b0;
        end
        else begin
            if(cmpy_out[39]) begin // cmpy_out[i][39:0] < 0 
                CMult_i <= cmpy_out[30-:16] + 1'b1;
            end
            else begin
                CMult_i <= cmpy_out[30-:16];
            end
        end
    end
    always @(posedge clock) begin
        if(rst) begin
            CMult_q <= 16'b0;
        end
        else begin
            if(cmpy_out[79]) begin // cmpy_out[i][79:0] < 0 
                CMult_q <= cmpy_out[70-:16] + 1'b1;
            end
            else begin
                CMult_q <= cmpy_out[70-:16];
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            CMult_valid <= 1'b0;
        end
        else begin
            CMult_valid <= cmpy_out_valid;
        end
    end

    assign sigOut       = {CMult_q,CMult_i};
    assign sigOut_valid = CMult_valid;

endmodule
