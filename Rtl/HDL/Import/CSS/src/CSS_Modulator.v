`timescale 1ns / 1ps
/* 

    B × T = 2^SF
        B : Chirp_BW
        T : Chirp_T

    Sample_Clock = 500e3 Hz
    B = Sample_Clock/2 = 250e3 Hz
    L = Sample_Clock / B = 2             2, 4, 8, 16, ...
    Chirp_T = T = 2^SF / B

    delta_f = B / Ticks = B / (T × Sample_Clock) = B / (2^SF/B × LB) = B / 2^(SF+log2(L))
    delta_pinc = delta_f / Sample_Clock * 2^16 = B / 2^(SF+log2(L)) / LB × 2^16 = 2^(16-SF-2log2(L))

    f = code × B / 2^SF
    pinc = f / fs × 2^16 = code × B / 2^SF / LB × 2^16 = code × 2^(16-(SF+log2(L)))

 */
module CSS_Modulator #(
    parameter CLOCK_FREQUENCY_MHZ = 32'd10,
    parameter INIT_FILE_PATH  = "dat.mem"

)(
    input  wire clock, // 10MHz
    input  wire rst,
    
    input  wire       config_valid,
    input  wire [7:0] config_sfSel, // SF : 8 - 12
    input  wire [7:0] config_bwSel, // BW : 125KHz 250KHz 500KHz 1MHz

    output wire        frame_bitIdle   ,
    input  wire        frame_bitReady  ,
    input  wire [15:0] frame_bitCount  ,
    output wire        frame_bitRequest,
    input  wire        frame_bitData   ,
    input  wire        frame_bitValid  ,

    output reg  [16*2-1:0] moduSigOut,
    output reg             moduSigValid
);
    localparam SAMPLE_RATE_KHZ  = 32'd250; // 基带数据采样率
    localparam BW_KHZ           = 32'd250; // 调制带宽
    localparam L                = SAMPLE_RATE_KHZ / BW_KHZ; // 采样率 / Chirp_BW
    localparam LL               = $clog2(L);

    localparam DDS_PHASE_WIDTH = 32'd32; // 调制DDS相位位宽

    localparam PREAMBLE_LEN = 16'd8; // Preamble 长度
    localparam SFD_LEN      = 16'd2; // SFD 长度
    localparam EFD_LEN      = 16'd1; // EFD 长度

    localparam MODULATE_PINC_UP_LIM   =  (1<<DDS_PHASE_WIDTH-$clog2(SAMPLE_RATE_KHZ/BW_KHZ)-1)-1; //;>> ($clog2(SAMPLE_RATE_KHZ/BW_KHZ)+1); // PINC调制上限
    localparam MODULATE_PINC_DOWN_LIM = -(1<<DDS_PHASE_WIDTH-$clog2(SAMPLE_RATE_KHZ/BW_KHZ)-1); // PINC调制下限

    localparam SAMPLE_CLOCK_DIV = CLOCK_FREQUENCY_MHZ*1000 / SAMPLE_RATE_KHZ -1; 




    // Global Signals 
    reg ready_to_convert;
    reg done_for_convert;
    reg ready_to_modulate;
    reg done_for_modulate;

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



    //-------------------------------------------------
    //---- 将调制极性标志(polarity)与基带Code数据拼接成符号数据
    //-------------------------------------------------
    localparam SYMBOL_FIFO_DEPTH             = 1024;
    localparam SYMBOL_FIFO_WR_DWIDTH         = 16;
    localparam SYMBOL_FIFO_WR_DATA_CNT_WIDTH = $clog2(SYMBOL_FIFO_DEPTH)+1;
    localparam SYMBOL_FIFO_RD_DWIDTH         = SYMBOL_FIFO_WR_DWIDTH;
    localparam SYMBOL_FIFO_RD_DATA_CNT_WIDTH = $clog2(SYMBOL_FIFO_DEPTH*SYMBOL_FIFO_WR_DWIDTH/SYMBOL_FIFO_RD_DWIDTH)+1;


    
    wire                                     symbol_fifo_wr_rst_busy  ;
    reg                                      symbol_fifo_wr_en        ;
    wire                                     symbol_fifo_wr_ack       ;
    reg  [SYMBOL_FIFO_WR_DWIDTH-1:0]         symbol_fifo_din          ;
    wire [SYMBOL_FIFO_WR_DATA_CNT_WIDTH-1:0] symbol_fifo_wr_data_count;
    wire                                     symbol_fifo_rd_rst_busy  ;
    wire                                     symbol_fifo_rd_en        ;
    wire                                     symbol_fifo_data_valid   ;
    wire [SYMBOL_FIFO_RD_DWIDTH-1:0]         symbol_fifo_dout         ;
    wire [SYMBOL_FIFO_RD_DATA_CNT_WIDTH-1:0] symbol_fifo_rd_data_count;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE   ("0"                   ), // String
        .ECC_MODE           ("no_ecc"              ), // String
        .FIFO_MEMORY_TYPE   ("auto"                ), // String
        .FIFO_READ_LATENCY  (1                     ), // DECIMAL
        .FIFO_WRITE_DEPTH   (SYMBOL_FIFO_DEPTH            ), // DECIMAL
        .FULL_RESET_VALUE   (0                     ), // DECIMAL
        .PROG_EMPTY_THRESH  (10                    ), // DECIMAL
        .PROG_FULL_THRESH   (10                    ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(SYMBOL_FIFO_RD_DATA_CNT_WIDTH), // DECIMAL
        .READ_DATA_WIDTH    (SYMBOL_FIFO_RD_DWIDTH        ), // DECIMAL
        .READ_MODE          ("std"                 ), // String
        .USE_ADV_FEATURES   ("1414"                ), // String
        .WAKEUP_TIME        (0                     ), // DECIMAL
        .WRITE_DATA_WIDTH   (SYMBOL_FIFO_WR_DWIDTH        ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(SYMBOL_FIFO_WR_DATA_CNT_WIDTH)  // DECIMAL
    )
    symbol_fifo (
        .rst          (rst                      ),
        .wr_clk       (clock                    ),
        .wr_rst_busy  (symbol_fifo_wr_rst_busy  ),
        .wr_en        (symbol_fifo_wr_en        ),
        .wr_ack       (                         ),
        .wr_data_count(symbol_fifo_wr_data_count),
        .din          (symbol_fifo_din          ),
        .injectdbiterr(1'b0                     ),
        .injectsbiterr(1'b0                     ),
        .overflow     (                         ),
        .almost_full  (                         ),
        .prog_full    (                         ),
        .full         (                         ),
        .sleep        (1'b0                     ),

        .rd_rst_busy  (symbol_fifo_rd_rst_busy  ),
        .rd_en        (symbol_fifo_rd_en        ),
        .dbiterr      (                         ),
        .sbiterr      (                         ),
        .underflow    (                         ),
        .almost_empty (                         ),
        .prog_empty   (                         ),
        .empty        (                         ),
        .data_valid   (symbol_fifo_data_valid   ),
        .dout         (symbol_fifo_dout         ),
        .rd_data_count(symbol_fifo_rd_data_count)

    );

    //-------------------------------------------------
    //---- 将符号数据转换为调制PINC码
    //-------------------------------------------------
    localparam PINC_FIFO_DEPTH             = 1024;
    localparam PINC_FIFO_WR_DWIDTH         = 64;
    localparam PINC_FIFO_WR_DATA_CNT_WIDTH = $clog2(PINC_FIFO_DEPTH)+1;
    localparam PINC_FIFO_RD_DWIDTH         = PINC_FIFO_WR_DWIDTH;
    localparam PINC_FIFO_RD_DATA_CNT_WIDTH = $clog2(PINC_FIFO_DEPTH*PINC_FIFO_WR_DWIDTH/PINC_FIFO_RD_DWIDTH)+1;


    
    wire                                   pinc_fifo_wr_rst_busy  ;
    reg                                    pinc_fifo_wr_en        ;
    wire                                   pinc_fifo_wr_ack       ;
    reg  [PINC_FIFO_WR_DWIDTH-1:0]         pinc_fifo_din          ; // {pinc_delta, pinc}
    wire [PINC_FIFO_WR_DATA_CNT_WIDTH-1:0] pinc_fifo_wr_data_count;
    wire                                   pinc_fifo_rd_rst_busy  ;
    wire                                   pinc_fifo_rd_en        ;
    wire                                   pinc_fifo_data_valid   ;
    wire [PINC_FIFO_RD_DWIDTH-1:0]         pinc_fifo_dout         ; // {pinc_delta, pinc}
    wire [PINC_FIFO_RD_DATA_CNT_WIDTH-1:0] pinc_fifo_rd_data_count;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE   ("0"                        ), // String
        .ECC_MODE           ("no_ecc"                   ), // String
        .FIFO_MEMORY_TYPE   ("auto"                     ), // String
        .FIFO_READ_LATENCY  (0                          ), // DECIMAL
        .FIFO_WRITE_DEPTH   (PINC_FIFO_DEPTH            ), // DECIMAL
        .FULL_RESET_VALUE   (0                          ), // DECIMAL
        .PROG_EMPTY_THRESH  (10                         ), // DECIMAL
        .PROG_FULL_THRESH   (10                         ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(PINC_FIFO_RD_DATA_CNT_WIDTH), // DECIMAL
        .READ_DATA_WIDTH    (PINC_FIFO_RD_DWIDTH        ), // DECIMAL
        .READ_MODE          ("fwft"                      ), // String
        .USE_ADV_FEATURES   ("1414"                     ), // String
        .WAKEUP_TIME        (0                          ), // DECIMAL
        .WRITE_DATA_WIDTH   (PINC_FIFO_WR_DWIDTH        ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(PINC_FIFO_WR_DATA_CNT_WIDTH)  // DECIMAL
    )
    pinc_fifo (
        .rst          (rst                    ),
        .wr_clk       (clock                  ),
        .wr_rst_busy  (pinc_fifo_wr_rst_busy  ),
        .wr_en        (pinc_fifo_wr_en        ),
        .wr_ack       (                       ),
        .wr_data_count(pinc_fifo_wr_data_count),
        .din          (pinc_fifo_din          ),
        .injectdbiterr(1'b0                   ),
        .injectsbiterr(1'b0                   ),
        .overflow     (                       ),
        .almost_full  (                       ),
        .prog_full    (                       ),
        .full         (                       ),
        .sleep        (1'b0                   ),

        .rd_rst_busy  (pinc_fifo_rd_rst_busy  ),
        .rd_en        (pinc_fifo_rd_en        ),
        .dbiterr      (                       ),
        .sbiterr      (                       ),
        .underflow    (                       ),
        .almost_empty (                       ),
        .prog_empty   (                       ),
        .empty        (                       ),
        .data_valid   (pinc_fifo_data_valid   ),
        .dout         (pinc_fifo_dout         ),
        .rd_data_count(pinc_fifo_rd_data_count)

    );



    localparam ST_IDLE        = 4'd0;
    localparam ST_PRE_SYMBOL  = 4'd1; // Preamble 符号
    localparam ST_SFD_SYMBOL  = 4'd2; // SFD 符号  -> Start Frame Delimiter
    localparam ST_REQ_BIT     = 4'd3; // 请求数据
    localparam ST_ACK_BIT     = 4'd4; // 数据响应（Std FIFO）
    localparam ST_COMB_SYMBOL = 4'd5; // 符号映射
    localparam ST_EFD_SYMBOL  = 4'd6; // EFD 符号  -> End Frame Delimiter
    localparam ST_DONE        = 4'd7; // 符号映射完成
    localparam ST_WAIT_MOD    = 4'd8; // 


    reg [3:0] curSta, nxtSta;

    reg [15:0] frame_bitNum_r ; // Bit数
    reg [15:0] reqCntr        ; // 请求次数
    reg [15:0] bitCntr        ; // 每符号bit计数
    reg [15:0] symbol_buffer  ; // 符号

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
                if(frame_bitReady) begin
                    nxtSta = ST_PRE_SYMBOL;
                end
                else begin
                    nxtSta = ST_IDLE;
                end
            end
            ST_PRE_SYMBOL : begin
                if(bitCntr == PREAMBLE_LEN -1) begin
                    nxtSta = ST_SFD_SYMBOL;
                end
                else begin
                    nxtSta = ST_PRE_SYMBOL;
                end
            end
            ST_SFD_SYMBOL : begin
                if(bitCntr == SFD_LEN -1) begin
                    nxtSta = ST_REQ_BIT;
                end
                else begin
                    nxtSta = ST_SFD_SYMBOL;
                end
            end
            
            ST_REQ_BIT : begin
                if(bitCntr == SF -1) begin
                    nxtSta = ST_ACK_BIT;
                end
                else begin
                    nxtSta = ST_REQ_BIT;
                end
            end
            ST_ACK_BIT : begin
                nxtSta = ST_COMB_SYMBOL;
            end
            ST_COMB_SYMBOL : begin
                if(reqCntr < frame_bitNum_r) begin
                    nxtSta = ST_REQ_BIT;
                end
                else begin
                    nxtSta = ST_EFD_SYMBOL;
                end
            end
            ST_EFD_SYMBOL : begin
                if(bitCntr == EFD_LEN -1) begin
                    nxtSta = ST_DONE;
                end
                else begin
                    nxtSta = ST_EFD_SYMBOL;
                end
            end
            ST_DONE : begin
                nxtSta = ST_WAIT_MOD;
            end
            ST_WAIT_MOD : begin
                if(done_for_convert) begin
                    nxtSta = ST_IDLE;
                end
                else begin
                    nxtSta = ST_WAIT_MOD;
                end
            end

            default : begin
                nxtSta = ST_IDLE;
            end
        endcase
    end

    always @(posedge clock) begin
        if(rst) begin
            frame_bitNum_r <= 16'b0;
        end
        else begin
            if(curSta == ST_IDLE) begin
                if(frame_bitReady) begin
                    frame_bitNum_r <= frame_bitCount;
                end
            end
        end
    end


    always @(posedge clock) begin
        if(rst) begin
            symbol_buffer <= 16'b0;
        end
        else begin
            case(curSta)
                ST_REQ_BIT     : begin
                    if(frame_bitValid) 
                        symbol_buffer <= {symbol_buffer[0+:15], frame_bitData};
                    else
                        symbol_buffer <= {symbol_buffer[0+:15], 1'b0};
                end
                ST_ACK_BIT     : begin
                    if(frame_bitValid) 
                        symbol_buffer <= {symbol_buffer[0+:15], frame_bitData};
                    else
                        symbol_buffer <= {symbol_buffer[0+:15], 1'b0};
                end
                ST_COMB_SYMBOL : symbol_buffer <= 16'b0;
                default        : symbol_buffer <= 16'b0;
            endcase
        end
    end



    always @(posedge clock) begin
        if(rst) begin
            bitCntr <= 16'b0;
        end
        else begin
            case(curSta)
                ST_PRE_SYMBOL : begin
                    if(bitCntr == PREAMBLE_LEN -1) begin
                        bitCntr <= 16'b0;
                    end
                    else begin
                        bitCntr <= bitCntr + 1'b1;
                    end
                end
                ST_SFD_SYMBOL : begin
                    if(bitCntr == SFD_LEN -1) begin
                        bitCntr <= 16'b0;
                    end
                    else begin
                        bitCntr <= bitCntr + 1'b1;
                    end
                end
                ST_REQ_BIT : begin
                    if(bitCntr == SF -1) begin
                        bitCntr <= 16'b0;
                    end
                    else begin
                        bitCntr <= bitCntr + 1'b1;
                    end
                end
                ST_EFD_SYMBOL : begin
                    if(bitCntr == EFD_LEN -1) begin
                        bitCntr <= 16'b0;
                    end
                    else begin
                        bitCntr <= bitCntr + 1'b1;
                    end
                end
                default : begin
                    bitCntr <= 16'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            reqCntr <= 16'b0;
        end
        else begin
            case(curSta)
                ST_IDLE    : reqCntr <= 16'b0;
                ST_REQ_BIT : reqCntr <= reqCntr + 1'b1;
            endcase
        end
    end


    always @(*) begin
        case(curSta)
            ST_IDLE        : symbol_fifo_wr_en = 1'b0;
            ST_PRE_SYMBOL  : symbol_fifo_wr_en = 1'b1;
            ST_SFD_SYMBOL  : symbol_fifo_wr_en = 1'b1;
            ST_COMB_SYMBOL : symbol_fifo_wr_en = 1'b1;
            ST_EFD_SYMBOL  : symbol_fifo_wr_en = 1'b1;
            default        : symbol_fifo_wr_en = 1'b0;
        endcase
    end

    always @(*) begin
        case(curSta)
            ST_IDLE        : symbol_fifo_din = 16'b0;
            ST_PRE_SYMBOL  : symbol_fifo_din = {1'b0, 15'b0}; // MSB: Polarity   0: UpChirp  1: DownChirp
            ST_SFD_SYMBOL  : symbol_fifo_din = {1'b1, 15'b0}; // MSB: Polarity   0: UpChirp  1: DownChirp
            ST_COMB_SYMBOL : symbol_fifo_din = {1'b0, symbol_buffer[0+:15]};
            ST_EFD_SYMBOL  : symbol_fifo_din = {1'b1, 15'b0}; // MSB: Polarity   0: UpChirp  1: DownChirp
            default        : symbol_fifo_din = 16'b0;
        endcase
    end

    assign frame_bitRequest = (curSta == ST_REQ_BIT);


    assign frame_bitIdle = (curSta == ST_IDLE);


    //#### Modulator

    reg [31:0] clkDivCntr; // 系统时钟分频系数， 用于产生基带数据采样时钟
    reg sample_clock_intr;
    reg sample_clock_intr_r;
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

    always @(posedge clock) begin 
        if(rst) begin
            sample_clock_intr_r <= 1'b0;
        end
        else begin
            sample_clock_intr_r <= sample_clock_intr;
        end
    end


    // reg ready_to_convert;
    always @(posedge clock) begin
        if(rst) begin
            ready_to_convert <= 1'b0;
        end
        else begin
            if(curSta == ST_DONE) begin
                ready_to_convert <= 1'b1;
            end
            else begin
                ready_to_convert <= 1'b0;
            end
        end
    end
    
    
    /* Symbol to PINC State Machine */
    localparam ST_STP_IDLE  = 4'd0;
    localparam ST_STP_START = 4'd1;
    localparam ST_STP_STOP  = 4'd2;
    localparam ST_STP_DONE  = 4'd3;
    localparam ST_STP_WAIT_MOD  = 4'd4;
    localparam ST_STP_MOD_DONE  = 4'd5;

    reg [3:0] stp_curSta, stp_nxtSta;
    reg [15:0] symbol_totalNum;
    reg [15:0] read_symbol_cntr;
    reg [31:0] stp_st_cntr;

    always @(posedge clock) begin
        if(rst) begin
            stp_curSta <= ST_STP_IDLE;
        end
        else begin
            stp_curSta <= stp_nxtSta;
        end
    end

    always @(*) begin
        case(stp_curSta)
            ST_STP_IDLE : begin
                if(ready_to_convert) begin
                    stp_nxtSta = ST_STP_START;
                end
                else begin
                    stp_nxtSta = ST_STP_IDLE;
                end
            end
            ST_STP_START : begin
                if(read_symbol_cntr + 1 < symbol_totalNum) begin
                    stp_nxtSta = ST_STP_START;
                end
                else begin
                    stp_nxtSta = ST_STP_STOP;
                end
            end
            ST_STP_STOP : begin
                if(stp_st_cntr > 32'd1) begin// fifo latency
                    stp_nxtSta = ST_STP_DONE;
                end
                else begin 
                    stp_nxtSta = ST_STP_STOP;
                end
            end
            ST_STP_DONE : begin
                stp_nxtSta = ST_STP_WAIT_MOD;
            end
            ST_STP_WAIT_MOD : begin
                if(done_for_modulate) begin
                    stp_nxtSta = ST_STP_MOD_DONE;
                end
                else begin
                    stp_nxtSta = ST_STP_WAIT_MOD;
                end
            end
            ST_STP_MOD_DONE : begin
                stp_nxtSta = ST_STP_IDLE;
            end
            default : begin
                stp_nxtSta = ST_STP_IDLE;
            end
        endcase
    end

    always @(posedge clock) begin
        if(rst) begin
            stp_st_cntr <= 32'b0;
        end
        else begin
            if(stp_curSta == ST_STP_STOP) begin
                if(stp_st_cntr > 32'd1) begin
                    stp_st_cntr <= 32'b0;
                end
                else begin
                    stp_st_cntr <= stp_st_cntr + 1'b1;
                end
            end
            else begin
                stp_st_cntr <= 32'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            symbol_totalNum <= 16'b0;
        end
        else begin
            if(ready_to_convert) begin
                symbol_totalNum <= symbol_fifo_rd_data_count;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            read_symbol_cntr <= 16'b0;
        end
        else begin
            if(stp_curSta == ST_STP_START) begin
                if(read_symbol_cntr + 1 < symbol_totalNum) begin
                    read_symbol_cntr <= read_symbol_cntr + 1'b1;
                end
                else begin
                    read_symbol_cntr <= 16'b0;
                end
            end
            else begin
                read_symbol_cntr <= 16'b0;
            end
        end
    end

    assign symbol_fifo_rd_en = (stp_curSta == ST_STP_START);

    always @(posedge clock) begin
        if(rst) begin
            pinc_fifo_wr_en <= 1'b0;
        end
        else begin
            pinc_fifo_wr_en <= symbol_fifo_data_valid;
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            pinc_fifo_din <= {PINC_FIFO_WR_DWIDTH{1'b0}};
        end
        else begin
            if(symbol_fifo_dout[15]) begin // 1 : Down-Chirp
                case(SF)
                    8'd8    : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-8)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd16711935); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-8)); // pinc_delta
                    end
                    8'd9    : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-9)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd8372256); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-9)); // pinc_delta
                    end
                    8'd10   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-10)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd4190212); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-10)); // pinc_delta
                    end
                    8'd11   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-11)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd2096128); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-11)); // pinc_delta
                    end
                    8'd12   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-12)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd1048320); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-12)); // pinc_delta
                    end
                    default : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_UP_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-8)); // pinc
                        pinc_fifo_din[32*1+:32] <= -$signed(32'd16711935); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= -$signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-8)); // pinc_delta
                    end
                endcase
            end
            else begin
                case(SF)
                    8'd8    : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-8)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd16711935); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-8)); // pinc_delta
                    end
                    8'd9    : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-9)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd8372256); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-9)); // pinc_delta
                    end
                    8'd10   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-10)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd4190212); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-10)); // pinc_delta
                    end
                    8'd11   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-11)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd2096128); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-11)); // pinc_delta
                    end
                    8'd12   : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-12)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd1048320); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-12)); // pinc_delta
                    end
                    default : begin
                        pinc_fifo_din[32*0+:32] <= MODULATE_PINC_DOWN_LIM + ({1'b0, symbol_fifo_dout[0+:15]} << (DDS_PHASE_WIDTH-LL-8)); // pinc
                        pinc_fifo_din[32*1+:32] <= $signed(32'd16711935); // pinc_delta
                        // pinc_fifo_din[32*1+:32] <= $signed(16'b1 << (DDS_PHASE_WIDTH-2*LL-8)); // pinc_delta
                    end
                endcase
            end
        end
    end



    always @(posedge clock) begin
        if(rst) begin
            done_for_convert <= 1'b0;
        end
        else begin
            done_for_convert <= (stp_curSta == ST_STP_MOD_DONE);
        end
    end


    // reg ready_to_modulate;
    always @(posedge clock) begin
        if(rst) begin
            ready_to_modulate <= 1'b0;
        end
        else begin
            if(stp_curSta == ST_STP_DONE) begin
                ready_to_modulate <= 1'b1;
            end
            else begin
                ready_to_modulate <= 1'b0;
            end
        end
    end
    
    localparam ST_MOD_IDLE  = 4'd0;
    localparam ST_MOD_START = 4'd1;
    localparam ST_MOD_PROC  = 4'd2;
    localparam ST_MOD_END   = 4'd3;

    reg [3:0] md_curSta, md_nxtSta;
    reg [31:0] md_st_cntr;

    reg [15:0] chirp_index;
    reg [15:0] chirp_num;

    always @(posedge clock) begin
        if(rst) begin
            md_curSta <= ST_MOD_IDLE;
        end
        else begin
            md_curSta <= md_nxtSta;
        end
    end

    always @(*) begin
        case(md_curSta)
            ST_MOD_IDLE : begin
                if(ready_to_modulate) begin
                    md_nxtSta = ST_MOD_START;
                end
                else begin
                    md_nxtSta = ST_MOD_IDLE;
                end
            end
            ST_MOD_START : begin
                if(sample_clock_intr) begin
                    if((md_st_cntr + 1 < Modu_T_Count) ||
                    (chirp_index + 1 < chirp_num) ) begin
                        md_nxtSta = ST_MOD_START;
                    end
                    else begin
                        md_nxtSta = ST_MOD_END;
                    end
                end
                else begin
                    md_nxtSta = ST_MOD_START;
                end
            end
            ST_MOD_END : begin
                md_nxtSta = ST_MOD_IDLE;
            end
            default : begin
                md_nxtSta = ST_MOD_IDLE;
            end
        endcase
    end


    always @(posedge clock) begin
        if(rst) begin
            md_st_cntr <= 32'b0;
        end
        else begin
            case(md_curSta)
                ST_MOD_IDLE : begin
                    md_st_cntr <= 32'b0;
                end
                ST_MOD_START : begin
                    if(sample_clock_intr) begin
                        if(md_st_cntr +1 < Modu_T_Count) begin
                            md_st_cntr <= md_st_cntr + 1'b1;
                        end
                        else begin
                            md_st_cntr <= 32'b0;
                        end
                    end
                end
                default : begin
                    md_st_cntr <= 32'b0;
                end
            endcase
        end
    end

    
    always @(posedge clock) begin
        if(rst) begin
            chirp_num <= 16'b0;
        end
        else begin
            if(ready_to_modulate) begin
                chirp_num <= pinc_fifo_rd_data_count;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            chirp_index <= 16'b0;
        end
        else begin
            if(md_curSta == ST_MOD_START) begin
                if(sample_clock_intr) begin
                    if(md_st_cntr + 1'b1 < Modu_T_Count) begin
                        chirp_index <= chirp_index;
                    end
                    else begin
                        if(chirp_index + 1'b1 < chirp_num) begin
                            chirp_index <= chirp_index + 1'b1;
                        end
                        else begin
                            chirp_index <= 16'b0;
                        end
                    end
                end
            end
            else begin
                chirp_index <= 16'b0;
            end
        end
    end


    reg               pinc_ctr;
    reg signed [DDS_PHASE_WIDTH-1:0] pinc; 
    reg signed [DDS_PHASE_WIDTH-1:0] pinc_delta;
    reg signed [DDS_PHASE_WIDTH-1:0] pinc_incr; // -fs/4 ~ fs/4
    // reg signed [(DDS_PHASE_WIDTH-2)-1:0] pinc_incr; // -fs/4 ~ fs/4

    always @(posedge clock) begin
        if(rst) begin
            pinc       <= {DDS_PHASE_WIDTH{1'b0}};
            pinc_delta <= {DDS_PHASE_WIDTH{1'b0}};
            pinc_incr  <= {DDS_PHASE_WIDTH{1'b0}};
            pinc_ctr   <= 1'b0;
        end
        else begin
            if(md_curSta == ST_MOD_START) begin
                if(sample_clock_intr) begin
                    pinc_ctr <= 1'b1;
                    if(md_st_cntr == 32'b0) begin
                        pinc       <= pinc_fifo_dout[32*0 +: DDS_PHASE_WIDTH];
                        pinc_delta <= pinc_fifo_dout[32*1+(32-DDS_PHASE_WIDTH) +: DDS_PHASE_WIDTH];
                        pinc_incr  <= pinc_fifo_dout[32*0 +: DDS_PHASE_WIDTH];
                        // pinc_incr  <= pinc_fifo_dout[32*0 +: 32] + pinc_fifo_dout[32*1 +: 32];
                    end
                    else begin
                        pinc <= $signed(pinc) + $signed(pinc_incr);
                        // pinc <= $signed(pinc) + $signed(pinc_incr[0+:(DDS_PHASE_WIDTH-1)]);
                        pinc_incr <= $signed(pinc_incr) + $signed(pinc_delta); // -fs/4 - fs/4
                    end
                end
                else begin
                    pinc_ctr <= 1'b0;
                end
            end
            else begin 
                pinc       <= {DDS_PHASE_WIDTH{1'b0}};
                pinc_delta <= {DDS_PHASE_WIDTH{1'b0}};
                pinc_incr  <= {DDS_PHASE_WIDTH{1'b0}};
                pinc_ctr   <= 1'b0;
            end
        end
    end

    assign pinc_fifo_rd_en = ((md_curSta == ST_MOD_START) && 
                                sample_clock_intr && 
                                (md_st_cntr == 32'd0));


    always @(posedge clock) begin
        if(rst) begin
            done_for_modulate <= 1'b0;
        end
        else begin
            done_for_modulate <= (md_curSta == ST_MOD_END);
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
            moduSigValid <= dds_valid;
            moduSigOut   <= dds_out;
        end
    end



    // ila_64bit css_modu_ila (
    //     .clk(clock), // input wire clk
    //     .probe0({
    //         'b0
    //         ,frame_bitIdle
    //         ,frame_bitReady
    //         ,frame_bitCount
    //         ,frame_bitRequest
    //         ,frame_bitData
    //         ,frame_bitValid
    //         ,moduSigOut[16*0+:16]
    //         ,moduSigOut[16*1+:16]
    //         ,moduSigValid
    //     }) // input wire [63:0] probe0
    // );

    
    integer fp;
    reg [31:0] count;
    initial begin
        count <= 32'b0;
        fp = $fopen("../../../../../Mat/fpga_css_modu.csv","wb");
        if(fp == 0) begin
            $display("Open failed !\n");
            $stop;
        end
        else begin
            // wait(~rst);
            @(negedge rst);
            #1000
            forever begin
                @(posedge clock) begin
                    if(moduSigValid) begin
                        // if(count < 512*32) begin
                            $fdisplay(fp,"%d,%d",
                                $signed(moduSigOut[(16*1)+:16]),// Q0
                                $signed(moduSigOut[(16*0)+:16]),// I0
                            );
                            count <= count +1;
                        // end
                        // else begin
                        //     // $fclose(fp);
                        //     // $display("Stop write data @ : %t ns", $time);
                        //     // $stop;
                        // end
                    end
                end
            end
        end
    end


endmodule
