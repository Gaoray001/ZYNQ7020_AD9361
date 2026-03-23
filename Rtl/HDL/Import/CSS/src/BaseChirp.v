// `default_nettype none
`timescale 1ns / 1ns

module BaseChirp #(
    parameter CLOCK_FREQUENCY_MHZ = 32'd10,
    parameter CHIRP_DIR           = 0, // 0: UpChirp  1: DownChirp
    parameter INIT_FILE_PATH  = "dat.mem"
)(
    input wire clock,
    input wire rst,
    input  wire       config_valid,
    input  wire [7:0] config_sfSel, // SF : 8 - 12
    // input  wire [7:0] config_bwSel, // BW : 125KHz 250KHz 500KHz 1MHz
    input wire [16-1:0] offset,

    output reg  [16*2-1:0] moduSigOut,
    output reg             moduSigValid
    
);  

    // localparam SAMPLE_RATE_KHZ  = 32'd500; // 基带数据采样率
    localparam SAMPLE_RATE_KHZ  = 32'd250; // 基带数据采样率
    localparam BW_KHZ = 32'd250; // 调制带宽
    localparam L = SAMPLE_RATE_KHZ / BW_KHZ; // 采样率 / Chirp_BW
    localparam LL = $clog2(L);

    localparam SAMPLE_CLOCK_DIV = CLOCK_FREQUENCY_MHZ*1000 / SAMPLE_RATE_KHZ -1; 

    localparam DDS_PHASE_WIDTH = 32'd32; // 调制DDS相位位宽

    // localparam MODULATE_PINC_UP_LIM   =   1<<(DDS_PHASE_WIDTH-$clog2(SAMPLE_RATE_KHZ/BW_KHZ)-1); //;>> ($clog2(SAMPLE_RATE_KHZ/BW_KHZ)+1); // PINC调制上限
    // localparam MODULATE_PINC_DOWN_LIM = -MODULATE_PINC_UP_LIM; // PINC调制下限


    localparam MODULATE_PINC_UP_LIM   =  (1<<DDS_PHASE_WIDTH-$clog2(SAMPLE_RATE_KHZ/BW_KHZ)-1)-1; //;>> ($clog2(SAMPLE_RATE_KHZ/BW_KHZ)+1); // PINC调制上限
    localparam MODULATE_PINC_DOWN_LIM = -(1<<DDS_PHASE_WIDTH-$clog2(SAMPLE_RATE_KHZ/BW_KHZ)-1); // PINC调制下限


    
    reg [7:0] SF;
    reg [31:0] Modu_T_Count;
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

    always @(posedge clock) begin // Ticks = T × Sample_Clock = 2^SF/B × LB = 2^(SF+log2(L))
        if(rst) begin
            Modu_T_Count <= 32'b0;
        end
        else begin
            case(SF)
                8'd8    : Modu_T_Count <= 1'b1 << (8+LL);
                8'd9    : Modu_T_Count <= 1'b1 << (9+LL);
                8'd10   : Modu_T_Count <= 1'b1 << (10+LL);
                8'd11   : Modu_T_Count <= 1'b1 << (11+LL);
                8'd12   : Modu_T_Count <= 1'b1 << (12+LL);
                default : Modu_T_Count <= 1'b1 << (8+LL);
            endcase
        end
    end



    reg [31:0] clkDivCntr; // 系统时钟分频系数， 用于产生基带数据采样时钟
    reg sample_clock_intr;

    always @(posedge clock) begin
        if(rst) begin
            clkDivCntr <= 32'b0;
        end
        else begin
            if(clkDivCntr < SAMPLE_CLOCK_DIV) begin
                clkDivCntr <= clkDivCntr + 1'b1;
            end
            else begin
                clkDivCntr <= 32'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            sample_clock_intr <= 1'b0;
        end
        else begin
            if(clkDivCntr < SAMPLE_CLOCK_DIV) begin
                sample_clock_intr <= 1'b0;
            end
            else begin
                sample_clock_intr <= 1'b1;
            end
        end
    end


    reg [31:0] cntr;
    always @(posedge clock) begin
        if(rst) begin
            cntr <= 32'b0;
        end
        else begin
            if(sample_clock_intr) begin
                if(cntr + 1 < Modu_T_Count) begin
                    cntr <= cntr + 1'b1;
                end
                else begin
                    cntr <= 32'b0;
                end
            end
        end
    end


    reg signed [DDS_PHASE_WIDTH-1:0] pinc_init; 
    reg signed [DDS_PHASE_WIDTH-1:0] pinc_delta;

    always @(posedge clock) begin
        if(rst) begin
            pinc_init  <= {DDS_PHASE_WIDTH{1'b0}};
            pinc_delta <= {DDS_PHASE_WIDTH{1'b0}};
        end
        else begin
            if(CHIRP_DIR == 0) begin // UpChirp
                pinc_init <= MODULATE_PINC_DOWN_LIM;
                case(SF)
                    8'd8    : pinc_delta <= $signed(32'd16711935); // 2^32/(2^8+1)
                    8'd9    : pinc_delta <= $signed(32'd8372256 ); // 2^32/(2^9+1)
                    8'd10   : pinc_delta <= $signed(32'd4190212 ); // 2^32/(2^10+1)
                    8'd11   : pinc_delta <= $signed(32'd2096128 ); // 2^32/(2^11+1)
                    8'd12   : pinc_delta <= $signed(32'd1048320 ); // 2^32/(2^12+1)
                    default : pinc_delta <= $signed(32'd16711935); // 2^32/(2^8+1)
                endcase
            end
            else begin // DownChirp
                pinc_init <= MODULATE_PINC_UP_LIM;
                case(SF)
                    8'd8    : pinc_delta <= -$signed(32'd16711935); // 2^32/(2^8+1)
                    8'd9    : pinc_delta <= -$signed(32'd8372256 ); // 2^32/(2^9+1)
                    8'd10   : pinc_delta <= -$signed(32'd4190212 ); // 2^32/(2^10+1)
                    8'd11   : pinc_delta <= -$signed(32'd2096128 ); // 2^32/(2^11+1)
                    8'd12   : pinc_delta <= -$signed(32'd1048320 ); // 2^32/(2^12+1)
                    default : pinc_delta <= -$signed(32'd16711935); // 2^32/(2^8+1)
                endcase
            end
        end
    end


    // reg [DDS_PHASE_WIDTH-1:0] pinc_start;
    // always @(posedge clock) begin
    //     if(rst) begin
    //         pinc_start <= {DDS_PHASE_WIDTH{1'b0}};
    //     end
    //     else begin
    //         pinc_start <= pinc_init + offset;
    //     end
    // end


    reg                              pinc_ctr ;
    reg signed [DDS_PHASE_WIDTH-1:0] pinc     ;
    reg signed [(DDS_PHASE_WIDTH-LL)-1:0] pinc_incr;

    always @(posedge clock) begin
        if(rst) begin
            pinc       <= {DDS_PHASE_WIDTH{1'b0}};
            pinc_incr  <= {(DDS_PHASE_WIDTH-LL){1'b0}};
            pinc_ctr   <= 1'b0;
        end
        else begin
            if(sample_clock_intr) begin
                pinc_ctr  <= 1'b1;
                if(cntr == 32'b0) begin
                    // pinc      <= pinc_start;
                    // pinc_incr <= pinc_start + pinc_delta;
                    pinc      <= pinc_init;
                    pinc_incr <= pinc_init + pinc_delta;
                end
                else begin
                    pinc      <= pinc + pinc_incr;
                    // pinc      <= pinc + {pinc_incr[(DDS_PHASE_WIDTH-LL)-1], pinc_incr};
                    pinc_incr <= pinc_incr + pinc_delta; // -fs/4 - fs/4
                end
            end
            else begin 
                pinc_ctr   <= 1'b0;
            end
        end
    end


    wire dds_valid;
    wire [31:0] dds_out;

    DDS_16X16 DDS_16X16 (
        .aclk               (clock             ), // input wire aclk
        .aresetn            (~rst              ), // input wire aresetn
        .s_axis_phase_tvalid(pinc_ctr          ), // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata (pinc[(DDS_PHASE_WIDTH-1)-:16] ), // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid (dds_valid         ), // output wire m_axis_data_tvalid
        .m_axis_data_tdata  (dds_out           )  // output wire [31 : 0] m_axis_data_tdata
    );


    // user_rom #(
    //     .DEPTH          ( 65536 ),    
    //     .DATA_WIDTH     ( 32    ),    
    //     .ADDR_WIDTH     ( 16    ),    
    //     .INIT_FILE_PATH ( INIT_FILE_PATH ))    
    // user_rom (
    //     .clock             ( clock   ),      
    //     .rst               ( rst     ),      
    //     .rd_en             ( pinc_ctr),      
    //     .addr              ( pinc[(DDS_PHASE_WIDTH-1)-:16] ),      
    //     .data_valid        ( dds_valid),
    //     .data              ( dds_out  )
    // );


    always @(posedge clock) begin
        if(rst) begin
            moduSigValid <= 1'b0;
            moduSigOut   <= 32'b0;
        end
        else begin
            if(dds_valid) begin
                moduSigValid <= dds_valid;
                moduSigOut   <= dds_out;
            end
            else begin
                moduSigValid <= 1'b0;
            end
        end
    end

    wire [15:0] moduSig_Q_t; // For Sim
    wire [15:0] moduSig_I_t; // For Sim

    assign moduSig_Q_t = moduSigOut[16*1+:16];
    assign moduSig_I_t = moduSigOut[16*0+:16];


endmodule