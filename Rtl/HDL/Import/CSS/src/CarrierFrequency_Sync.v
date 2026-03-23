`timescale 1ns / 1ns

module CarrierFrequency_Sync(
    input  wire clock, // 10MHz
    input  wire rst,
    
    input  wire        config_valid   ,
    input  wire [7:0]  config_sfSel   , // SF : 8 - 12

    input  wire          offset_ctrl,
    input  wire          offset_clear,
    input  wire [16-1:0] offset,

    input  wire [16*2-1:0] sigInIQ,
    input  wire            sigInVal,

    output wire [16*2-1:0] sigOutIQ,
    output wire            sigOutVal
);



    reg [7:0] SF;
    always @(posedge clock) begin // Sample Clock Ticks
        if(rst) begin
            SF <= 8'd8;
        end
        else begin
            if(config_valid) begin
                if(config_sfSel < 8) begin
                    SF <= 8'd8;
                end
                else if(config_sfSel > 12) begin
                    SF <= 8'd12;
                end
                else begin
                    SF <= config_sfSel;
                end
            end
        end
    end

    reg [15:0] freCode_t;

    always @(posedge clock) begin
        if(rst) begin
            freCode_t <= 16'b0;
        end
        else begin
            if(offset_ctrl) begin
                if(offset_clear) begin
                    freCode_t <= 16'b0;
                end
                else begin
                    case(SF)
                        8'd8    : freCode_t <= {{8{offset[8-1]}}, offset[0+:8 ]} << (16-8) ;
                        8'd9    : freCode_t <= {{7{offset[8-1]}}, offset[0+:9 ]} << (16-9) ;
                        8'd10   : freCode_t <= {{6{offset[8-1]}}, offset[0+:10]} << (16-10);
                        8'd11   : freCode_t <= {{5{offset[8-1]}}, offset[0+:11]} << (16-11);
                        8'd12   : freCode_t <= {{4{offset[8-1]}}, offset[0+:12]} << (16-12);
                        default : freCode_t <= {{8{offset[8-1]}}, offset[0+:8 ]} << (16-8) ;
                    endcase
                end
            end
        end
    end

    // reg [15:0] freCode_t;
    FreSpectrum_shift FreSpectrum_shift (
        .clock             ( clock ),
        .rst               ( rst   ),
        .config_freCode    ( freCode_t ),
        .sigIn_valid       ( sigInVal  ),
        .sigIn             ( sigInIQ   ),

        .sigOut_valid      ( sigOutVal ),
        .sigOut            ( sigOutIQ  )
    );







endmodule