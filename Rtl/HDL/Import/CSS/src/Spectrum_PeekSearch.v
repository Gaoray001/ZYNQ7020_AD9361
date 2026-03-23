`timescale 1ns / 1ns

module Spectrum_PeekSearch (
    input  wire clock,
    input  wire rst,
    input  wire          spectrum_tvalid,
    input  wire [32-1:0] spectrum_tdata,
    input  wire [16-1:0] spectrum_tuser,
    input  wire          spectrum_tlast,

    output reg           peek_valid,
    output reg  [32-1:0] peek_ampSqrt,
    output reg  [16-1:0] peek_index

);


    localparam ST_IDLE  = 4'd0;
    localparam ST_START = 4'd1;
    localparam ST_END   = 4'd2;

    reg [3:0] curSta, nxtSta;

    reg [31:0] peek_r;
    reg [15:0] index_r;
    reg flag;

    always @(posedge clock) begin
        if(rst) begin
            curSta <= ST_IDLE;
        end
        else begin
            curSta <= nxtSta;
        end
    end

    always @(*) begin
        case(curSta)
            ST_IDLE : begin
                nxtSta = ST_START;
            end
            ST_START : begin
                if(spectrum_tvalid & spectrum_tlast) begin
                    nxtSta = ST_END;
                end
                else begin
                    nxtSta = ST_START;
                end
            end
            ST_END : begin
                nxtSta = ST_IDLE;
            end
            default : begin
                nxtSta = ST_IDLE;
            end
        endcase
    end


    always @(posedge clock) begin
        if(rst) begin
            peek_r  <= 32'b0;
            index_r <= 16'b0;
            flag <= 1'b0;
        end
        else begin
            case(curSta)
                ST_IDLE : begin
                    peek_r  <= 32'b0;
                    index_r <= 16'b0;
                    flag    <= 1'b0;
                end
                ST_START : begin
                    flag <= 1'b0;
                    if(spectrum_tvalid) begin
                        if(spectrum_tdata < peek_r) begin
                            peek_r  <= peek_r;
                            index_r <= index_r;
                        end
                        else begin
                            peek_r  <= spectrum_tdata;
                            index_r <= spectrum_tuser;
                        end
                    end
                end
                ST_END : begin
                    peek_r  <= peek_r;
                    index_r <= index_r;
                    flag    <= 1'b1;
                end
                default : begin
                    peek_r  <= 32'b0;
                    index_r <= 16'b0;
                    flag    <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            peek_valid <= 1'b0;
            peek_ampSqrt <= 32'b0;
            peek_index <= 16'b0;
        end
        else begin
            // peek_valid   <= flag;
            // peek_ampSqrt <= peek_r;
            // peek_index   <= index_r;
            if(curSta == ST_END) begin
                peek_valid   <= 1'b1;
                peek_ampSqrt <= peek_r;
                peek_index   <= index_r;
            end
            else begin
                peek_valid   <= 1'b0;
            end
        end
    end


endmodule