module FramePackage_Send #(
    parameter CLOCK_PEROID = 32'd100_000_000,
    parameter UART_BPS_TX  = 32'd115_200
)(
    input wire clock,
    input wire rst,

        
    input  wire       config_valid,
    input  wire [7:0] config_sfSel, // SF : 8 - 12
    input  wire [7:0] config_bwSel, // BW : 125KHz 250KHz 500KHz 1MHz

    // input wire decode_start,
    input wire decode_end,

    input wire [15:0] decode_dat,
    input wire        decode_val,

    output wire uart_txd

);

    localparam T_PROTOCOL_HEAD    = 16'hfeef;
    localparam T_PROTOCOL_LEN     = 16'hffff;
    localparam T_PROTOCOL_CMD     = 16'h0001; // Frame of TransData
    localparam T_PROTOCOL_SRCID   = 8'h02;
    localparam T_PROTOCOL_DSTID   = 8'h01;


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

    
    reg [15:0] decode_dat_r;
    reg        decode_val_r;

    always @(posedge clock) begin
        if(rst) begin
            decode_dat_r <= 16'b0;
            decode_val_r <= 1'b0;
        end
        else begin
            case(SF)
                8'd8    : decode_dat_r <= {{decode_dat[0+:8 ]}, 8'b0};
                8'd9    : decode_dat_r <= {{decode_dat[0+:9 ]}, 7'b0};
                8'd10   : decode_dat_r <= {{decode_dat[0+:10]}, 6'b0};
                8'd11   : decode_dat_r <= {{decode_dat[0+:11]}, 5'b0};
                8'd12   : decode_dat_r <= {{decode_dat[0+:12]}, 4'b0};
                default : decode_dat_r <= {{decode_dat[0+:8 ]}, 8'b0};
            endcase
            // decode_dat_r <= decode_dat;
            decode_val_r <= decode_val;
        end
    end



    //-------------------------------------------------
    //---- 按位写入数据，并根据SF重新映射成Code (MSB)
    //-------------------------------------------------

    localparam FIFO_DEPTH             = 1024;
    localparam FIFO_WR_DWIDTH         = 1;
    localparam FIFO_WR_DATA_CNT_WIDTH = $clog2(FIFO_DEPTH)+1;
    localparam FIFO_RD_DWIDTH         = 8;
    localparam FIFO_RD_DATA_CNT_WIDTH = $clog2(FIFO_DEPTH*FIFO_WR_DWIDTH/FIFO_RD_DWIDTH)+1;


    
    reg                               fifo_rst          ;
    wire                              fifo_wr_rst_busy  ;
    wire                              fifo_wr_en        ;
    wire                              fifo_wr_ack       ;
    wire [FIFO_WR_DWIDTH-1:0]         fifo_din          ;
    wire [FIFO_WR_DATA_CNT_WIDTH-1:0] fifo_wr_data_count;
    wire                              fifo_rd_rst_busy  ;
    wire                              fifo_rd_en        ;
    wire                              fifo_data_valid   ;
    wire [FIFO_RD_DWIDTH-1:0]         fifo_dout         ;
    wire [FIFO_RD_DATA_CNT_WIDTH-1:0] fifo_rd_data_count;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE   ("0"                   ), // String
        .ECC_MODE           ("no_ecc"              ), // String
        .FIFO_MEMORY_TYPE   ("auto"                ), // String
        .FIFO_READ_LATENCY  (1                     ), // DECIMAL
        .FIFO_WRITE_DEPTH   (FIFO_DEPTH            ), // DECIMAL
        .FULL_RESET_VALUE   (0                     ), // DECIMAL
        .PROG_EMPTY_THRESH  (10                    ), // DECIMAL
        .PROG_FULL_THRESH   (10                    ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(FIFO_RD_DATA_CNT_WIDTH), // DECIMAL
        .READ_DATA_WIDTH    (FIFO_RD_DWIDTH        ), // DECIMAL
        .READ_MODE          ("std"                 ), // String
        .USE_ADV_FEATURES   ("1414"                ), // String
        .WAKEUP_TIME        (0                     ), // DECIMAL
        .WRITE_DATA_WIDTH   (FIFO_WR_DWIDTH        ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(FIFO_WR_DATA_CNT_WIDTH)  // DECIMAL
    )
    xpm_fifo_sync_inst (
        .rst          (fifo_rst          ),
        .wr_clk       (clock             ),
        .wr_rst_busy  (fifo_wr_rst_busy  ),
        .wr_en        (fifo_wr_en        ),
        .wr_ack       (fifo_wr_ack       ),
        .wr_data_count(fifo_wr_data_count),
        .din          (fifo_din          ),
        .injectdbiterr(1'b0              ),
        .injectsbiterr(1'b0              ),
        .overflow     (                  ),
        .almost_full  (                  ),
        .prog_full    (                  ),
        .full         (                  ),
        .sleep        (1'b0              ),

        .rd_rst_busy  (fifo_rd_rst_busy  ),
        .rd_en        (fifo_rd_en        ),
        .dbiterr      (                  ),
        .sbiterr      (                  ),
        .underflow    (                  ),
        .almost_empty (                  ),
        .prog_empty   (                  ),
        .empty        (                  ),
        .data_valid   (fifo_data_valid   ),
        .dout         (fifo_dout         ),
        .rd_data_count(fifo_rd_data_count)

    );


    localparam SYMB_ST_IDLE = 4'd0;
    localparam SYMB_ST_CLEAR = 4'd1;
    localparam SYMB_ST_WRITE_READY = 4'd2;
    localparam SYMB_ST_WRITE = 4'd3;

    reg [3:0] symb_curSt, symb_nxtSt;

    reg [31:0] symb_cntr;

    always @(posedge clock) begin
        if(rst) begin
            symb_curSt <= SYMB_ST_IDLE;
        end
        else begin
            symb_curSt <= symb_nxtSt;
        end
    end

    always @(*) begin
        case(symb_curSt)
            SYMB_ST_IDLE : begin
                symb_nxtSt = SYMB_ST_CLEAR;
            end
            SYMB_ST_CLEAR : begin
                if(symb_cntr < 20) begin
                    symb_nxtSt = SYMB_ST_CLEAR;
                end
                else begin
                    symb_nxtSt = SYMB_ST_WRITE_READY;
                end
            end
            SYMB_ST_WRITE_READY : begin
                if(decode_val_r) begin
                    symb_nxtSt = SYMB_ST_WRITE;
                end
                else begin
                    symb_nxtSt = SYMB_ST_WRITE_READY;
                end
            end
            SYMB_ST_WRITE : begin
                if(symb_cntr == SF - 1) begin
                    symb_nxtSt = SYMB_ST_WRITE_READY;
                end
                else begin
                    symb_nxtSt = SYMB_ST_WRITE;
                end
            end
            default : begin
                symb_nxtSt = SYMB_ST_IDLE;
            end
        endcase
    end



    reg [15:0] symbol_dat;
    // reg        symbol_val;

    always @(posedge clock) begin
        if(rst) begin
            symbol_dat <= 16'b0;
            // symbol_val <= 1'b0;
        end
        else begin
            case(symb_curSt)
                SYMB_ST_WRITE_READY :begin
                    if(decode_val_r) begin
                        // symbol_val <= 1'b1;
                        symbol_dat <= {<<{decode_dat_r}};
                    end
                end
                SYMB_ST_WRITE : begin
                    symbol_dat <= symbol_dat >> 1;
                    // symbol_val <= 1'b0;
                end
                default : begin
                    symbol_dat <= 16'b0;
                    // symbol_val <= 1'b0;
                end
            endcase
        end

    end


    always @(posedge clock) begin
        if(rst) begin
            symb_cntr <= 32'b0;
        end
        else begin
            case(symb_curSt)
                SYMB_ST_IDLE : begin
                    symb_cntr <= 32'b0;
                end
                SYMB_ST_CLEAR : begin
                    if(symb_cntr < 20) begin
                        symb_cntr <= symb_cntr + 1'b1;
                    end
                    else begin
                        symb_cntr <= 32'b0;
                    end
                end
                SYMB_ST_WRITE : begin
                    if(symb_cntr == SF - 1) begin
                        symb_cntr <= 32'b0;
                    end
                    else begin
                        symb_cntr <= symb_cntr + 1'b1;
                    end
                end
                default : begin
                    symb_cntr <= 32'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            fifo_rst <= 1'b0;
        end
        else begin
            if(symb_curSt == SYMB_ST_CLEAR) begin
                if(symb_cntr < 8) begin
                    fifo_rst <= 1'b1;
                end
                else begin
                    fifo_rst <= 1'b0;
                end
            end
            else begin
                fifo_rst <= 1'b0;
            end
        end
    end

    assign fifo_wr_en = (symb_curSt == SYMB_ST_WRITE);
    assign fifo_din   = symbol_dat[0];

    
    assign fifo_rd_en = (fifo_rd_data_count >0)? 1'b1 : 1'b0;

    reg [7:0] code_dat;
    reg       code_val;

    always @(posedge clock) begin
        if(rst) begin
            code_dat <= 8'b0;
            code_val <= 1'b0;
        end
        else begin
            if(fifo_data_valid) begin
                code_dat <= {<<{fifo_dout}};
                code_val <= 1'b1;
            end
            else begin
                code_val <= 1'b0;
            end
        end
    end

    // wire [7:0] dat;
    // assign dat = {<<{fifo_dout}};

    
    // //-------------------------------------------------
    // //---- 缓存 Decode_Dat
    // //-------------------------------------------------
    localparam DECODE_FIFO_DEPTH             = 1024;
    localparam DECODE_FIFO_WR_DWIDTH         = 8;
    localparam DECODE_FIFO_WR_DATA_CNT_WIDTH = $clog2(DECODE_FIFO_DEPTH)+1;
    localparam DECODE_FIFO_RD_DWIDTH         = DECODE_FIFO_WR_DWIDTH;
    localparam DECODE_FIFO_RD_DATA_CNT_WIDTH = $clog2(DECODE_FIFO_DEPTH*DECODE_FIFO_WR_DWIDTH/DECODE_FIFO_RD_DWIDTH)+1;
    
    wire                                     decode_fifo_wr_rst_busy  ;
    wire                                     decode_fifo_wr_en        ;
    wire                                     decode_fifo_wr_ack       ;
    wire [DECODE_FIFO_WR_DWIDTH-1:0]         decode_fifo_din          ;
    wire [DECODE_FIFO_WR_DATA_CNT_WIDTH-1:0] decode_fifo_wr_data_count;
    wire                                     decode_fifo_rd_rst_busy  ;
    wire                                     decode_fifo_rd_en        ;
    wire                                     decode_fifo_data_valid   ;
    wire [DECODE_FIFO_RD_DWIDTH-1:0]         decode_fifo_dout         ;
    wire [DECODE_FIFO_RD_DATA_CNT_WIDTH-1:0] decode_fifo_rd_data_count;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE   ("0"                   ), // String
        .ECC_MODE           ("no_ecc"              ), // String
        .FIFO_MEMORY_TYPE   ("auto"                ), // String
        .FIFO_READ_LATENCY  (0                     ), // DECIMAL
        .FIFO_WRITE_DEPTH   (DECODE_FIFO_DEPTH            ), // DECIMAL
        .FULL_RESET_VALUE   (0                     ), // DECIMAL
        .PROG_EMPTY_THRESH  (10                    ), // DECIMAL
        .PROG_FULL_THRESH   (10                    ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(DECODE_FIFO_RD_DATA_CNT_WIDTH), // DECIMAL
        .READ_DATA_WIDTH    (DECODE_FIFO_RD_DWIDTH        ), // DECIMAL
        .READ_MODE          ("fwft"                 ), // String
        .USE_ADV_FEATURES   ("1414"                ), // String
        .WAKEUP_TIME        (0                     ), // DECIMAL
        .WRITE_DATA_WIDTH   (DECODE_FIFO_WR_DWIDTH        ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(DECODE_FIFO_WR_DATA_CNT_WIDTH)  // DECIMAL
    )
    decode_fifo (
        .rst          (rst                      ),
        .wr_clk       (clock                    ),
        .wr_rst_busy  (decode_fifo_wr_rst_busy  ),
        .wr_en        (decode_fifo_wr_en        ),
        .wr_ack       (                         ),
        .wr_data_count(decode_fifo_wr_data_count),
        .din          (decode_fifo_din          ),
        .injectdbiterr(1'b0                     ),
        .injectsbiterr(1'b0                     ),
        .overflow     (                         ),
        .almost_full  (                         ),
        .prog_full    (                         ),
        .full         (                         ),
        .sleep        (1'b0                     ),

        .rd_rst_busy  (decode_fifo_rd_rst_busy  ),
        .rd_en        (decode_fifo_rd_en        ),
        .dbiterr      (                         ),
        .sbiterr      (                         ),
        .underflow    (                         ),
        .almost_empty (                         ),
        .prog_empty   (                         ),
        .empty        (                         ),
        .data_valid   (decode_fifo_data_valid   ),
        .dout         (decode_fifo_dout         ),
        .rd_data_count(decode_fifo_rd_data_count)
    );

    assign decode_fifo_wr_en = code_val;
    assign decode_fifo_din   = code_dat;



    
    // //-------------------------------------------------
    // //---- 将解调后的数据重新组帧，准备发送
    // //-------------------------------------------------
    localparam FRAME_FIFO_DEPTH             = 1024;
    localparam FRAME_FIFO_WR_DWIDTH         = 8;
    localparam FRAME_FIFO_WR_DATA_CNT_WIDTH = $clog2(FRAME_FIFO_DEPTH)+1;
    localparam FRAME_FIFO_RD_DWIDTH         = FRAME_FIFO_WR_DWIDTH;
    localparam FRAME_FIFO_RD_DATA_CNT_WIDTH = $clog2(FRAME_FIFO_DEPTH*FRAME_FIFO_WR_DWIDTH/FRAME_FIFO_RD_DWIDTH)+1;


    
    reg                                     frame_fifo_rst  ;
    wire                                    frame_fifo_wr_rst_busy  ;
    reg                                     frame_fifo_wr_en        ;
    wire                                    frame_fifo_wr_ack       ;
    reg  [FRAME_FIFO_WR_DWIDTH-1:0]         frame_fifo_din          ;
    wire [FRAME_FIFO_WR_DATA_CNT_WIDTH-1:0] frame_fifo_wr_data_count;
    wire                                    frame_fifo_rd_rst_busy  ;
    wire                                    frame_fifo_rd_en        ;
    wire                                    frame_fifo_data_valid   ;
    wire [FRAME_FIFO_RD_DWIDTH-1:0]         frame_fifo_dout         ;
    wire [FRAME_FIFO_RD_DATA_CNT_WIDTH-1:0] frame_fifo_rd_data_count;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE   ("0"                   ), // String
        .ECC_MODE           ("no_ecc"              ), // String
        .FIFO_MEMORY_TYPE   ("auto"                ), // String
        .FIFO_READ_LATENCY  (0                     ), // DECIMAL
        .FIFO_WRITE_DEPTH   (FRAME_FIFO_DEPTH            ), // DECIMAL
        .FULL_RESET_VALUE   (0                     ), // DECIMAL
        .PROG_EMPTY_THRESH  (10                    ), // DECIMAL
        .PROG_FULL_THRESH   (10                    ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(FRAME_FIFO_RD_DATA_CNT_WIDTH), // DECIMAL
        .READ_DATA_WIDTH    (FRAME_FIFO_RD_DWIDTH        ), // DECIMAL
        .READ_MODE          ("fwft"                 ), // String
        .USE_ADV_FEATURES   ("1414"                ), // String
        .WAKEUP_TIME        (0                     ), // DECIMAL
        .WRITE_DATA_WIDTH   (FRAME_FIFO_WR_DWIDTH        ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(FRAME_FIFO_WR_DATA_CNT_WIDTH)  // DECIMAL
    )
    frame_fifo (
        .rst          (frame_fifo_rst          ),
        .wr_clk       (clock                   ),
        .wr_rst_busy  (frame_fifo_wr_rst_busy  ),
        .wr_en        (frame_fifo_wr_en        ),
        .wr_ack       (                        ),
        .wr_data_count(frame_fifo_wr_data_count),
        .din          (frame_fifo_din          ),
        .injectdbiterr(1'b0                    ),
        .injectsbiterr(1'b0                    ),
        .overflow     (                        ),
        .almost_full  (                        ),
        .prog_full    (                        ),
        .full         (                        ),
        .sleep        (1'b0                    ),

        .rd_rst_busy  (frame_fifo_rd_rst_busy  ),
        .rd_en        (frame_fifo_rd_en        ),
        .dbiterr      (                        ),
        .sbiterr      (                        ),
        .underflow    (                        ),
        .almost_empty (                        ),
        .prog_empty   (                        ),
        .empty        (                        ),
        .data_valid   (frame_fifo_data_valid   ),
        .dout         (frame_fifo_dout         ),
        .rd_data_count(frame_fifo_rd_data_count)

    );


    localparam FR_ST_IDLE         = 4'd0;
    localparam FR_ST_CLEAR        = 4'd1;
    localparam FR_ST_CLEAR_FINISH = 4'd2;

    localparam FR_ST_START        = 4'd3;

    localparam FR_ST_HEAD         = 4'd4;
    localparam FR_ST_LEN          = 4'd5;
    localparam FR_ST_CMD          = 4'd6;
    localparam FR_ST_SRCID        = 4'd7;
    localparam FR_ST_DSTID        = 4'd8;
    localparam FR_ST_DATA         = 4'd9;
    localparam FR_ST_CHKSUM       = 4'd10;

    localparam FR_ST_DONE         = 4'd11;

    // localparam FR_ST_START = 4'd2;
    // localparam FR_ST_WRITE = 4'd2;

    reg [3:0] fr_curSt, fr_nxtSt;
    reg [31:0] fr_st_cntr;

    reg [8*2-1       :0] protocol_head    ;
    reg [8*2-1       :0] protocol_length  ;
    reg [8*2-1       :0] protocol_command ;
    reg [8*1-1       :0] protocol_srcid   ;
    reg [8*1-1       :0] protocol_dstid   ;
    reg [8*1-1       :0] protocol_data    ;
    reg [8*1-1       :0] protocol_checksum;
    reg [8*2-1       :0] protocol_payloadSize;

    always @(posedge clock) begin
        if(rst) begin
            fr_curSt <= FR_ST_IDLE;
        end
        else begin
            fr_curSt <= fr_nxtSt;
        end
    end

    always @(*) begin
        case(fr_curSt)
            FR_ST_IDLE : begin
                fr_nxtSt = FR_ST_CLEAR;
            end
            FR_ST_CLEAR : begin
                if(fr_st_cntr >= 20) begin
                    fr_nxtSt <= FR_ST_CLEAR_FINISH;
                end
                else begin
                    fr_nxtSt = FR_ST_CLEAR;
                end
            end
            FR_ST_CLEAR_FINISH : begin
                if(~frame_fifo_wr_rst_busy) begin
                    fr_nxtSt = FR_ST_START;
                end
                else begin
                    fr_nxtSt = FR_ST_CLEAR_FINISH;
                end
            end

            FR_ST_START : begin
                if(decode_end) begin
                    fr_nxtSt = FR_ST_HEAD;
                end
                else begin
                    fr_nxtSt = FR_ST_START;
                end
            end

            FR_ST_HEAD : begin
                if(fr_st_cntr >= 2-1) begin
                    fr_nxtSt = FR_ST_LEN;
                end
                else begin
                    fr_nxtSt = FR_ST_HEAD;
                end
            end
            
            FR_ST_LEN : begin
                if(fr_st_cntr >= 2-1) begin
                    fr_nxtSt = FR_ST_CMD;
                end
                else begin
                    fr_nxtSt = FR_ST_LEN;
                end
            end
            FR_ST_CMD : begin
                if(fr_st_cntr >= 2-1) begin
                    fr_nxtSt = FR_ST_SRCID;
                end
                else begin
                    fr_nxtSt = FR_ST_CMD;
                end
            end
            FR_ST_SRCID : begin
                if(fr_st_cntr >= 1-1) begin
                    fr_nxtSt = FR_ST_DSTID;
                end
                else begin
                    fr_nxtSt = FR_ST_SRCID;
                end
            end
            FR_ST_DSTID : begin
                if(fr_st_cntr >= 1-1) begin
                    fr_nxtSt = FR_ST_DATA;
                end
                else begin
                    fr_nxtSt = FR_ST_DSTID;
                end
            end

            FR_ST_DATA : begin
                if(fr_st_cntr + 1 >= protocol_payloadSize) begin
                    fr_nxtSt = FR_ST_CHKSUM;
                end
                else begin
                    fr_nxtSt = FR_ST_DATA;
                end
            end
            FR_ST_CHKSUM : begin
                if(fr_st_cntr >= 1-1) begin
                    fr_nxtSt = FR_ST_DONE;
                end
                else begin
                    fr_nxtSt = FR_ST_CHKSUM;
                end
            end
            FR_ST_DONE : begin
                if(frame_fifo_wr_data_count) begin
                    fr_nxtSt = FR_ST_DONE;
                end
                else begin
                    fr_nxtSt = FR_ST_IDLE;
                end
            end
            default : begin
                fr_nxtSt = FR_ST_IDLE;
            end
        endcase
    end


    always @(posedge clock) begin
        if(rst) begin
            fr_st_cntr <= 32'b0;
        end
        else begin
            case(fr_curSt) 
                FR_ST_IDLE : begin
                    fr_st_cntr <= 32'b0;
                end
                FR_ST_CLEAR : begin
                    if(fr_st_cntr >= 20) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_HEAD : begin
                    if(fr_st_cntr >= 2-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_LEN : begin
                    if(fr_st_cntr >= 2-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_CMD : begin
                    if(fr_st_cntr >= 2-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_SRCID : begin
                    if(fr_st_cntr >= 1-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_DSTID : begin
                    if(fr_st_cntr >= 1-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_DATA : begin
                    if(fr_st_cntr + 1 >= protocol_payloadSize) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                FR_ST_CHKSUM : begin
                    if(fr_st_cntr >= 1-1) begin
                        fr_st_cntr <= 32'b0;
                    end
                    else begin
                        fr_st_cntr <= fr_st_cntr + 1'b1;
                    end
                end
                default : begin
                    fr_st_cntr <= 32'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin // protocol_payloadSize
        if(rst) begin
            protocol_payloadSize <= {2{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_START : protocol_payloadSize <= decode_fifo_rd_data_count;
                default     : protocol_payloadSize <= protocol_payloadSize;
            endcase
        end
    end


    always @(posedge clock) begin // protocol_head
        if(rst) begin
            protocol_head <= {2{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE : protocol_head <= T_PROTOCOL_HEAD << 8 | T_PROTOCOL_HEAD >> 8;
                FR_ST_HEAD : protocol_head <= protocol_head >> 8;
                default    : protocol_head <= protocol_head;
            endcase
        end
    end
    always @(posedge clock) begin // protocol_length
        if(rst) begin
            protocol_length <= {2{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_START : protocol_length <= decode_fifo_rd_data_count + 9;
                FR_ST_LEN   : protocol_length <= protocol_length >> 8;
                default     : protocol_length <= protocol_length;
            endcase
        end
    end
    always @(posedge clock) begin // protocol_command
        if(rst) begin
            protocol_command <= {2{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE : protocol_command <= T_PROTOCOL_CMD;
                FR_ST_CMD  : protocol_command <= protocol_command >> 8;
                default    : protocol_command <= protocol_command;
            endcase
        end
    end
    always @(posedge clock) begin // protocol_srcid
        if(rst) begin
            protocol_srcid <= {1{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE  : protocol_srcid <= T_PROTOCOL_SRCID;
                FR_ST_SRCID : protocol_srcid <= protocol_srcid >> 8;
                default     : protocol_srcid <= protocol_srcid;
            endcase
        end
    end
    always @(posedge clock) begin // protocol_dstid
        if(rst) begin
            protocol_dstid <= {1{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE  : protocol_dstid <= T_PROTOCOL_DSTID;
                FR_ST_DSTID : protocol_dstid <= protocol_dstid >> 8;
                default     : protocol_dstid <= protocol_dstid;
            endcase
        end
    end
    // always @(posedge clock) begin // protocol_data
    //     if(rst) begin
    //         protocol_data <= {1{8'b0}};
    //     end
    //     else begin
    //         case(fr_curSt)
    //             FR_ST_IDLE  : protocol_data <= {1{8'b0}};
    //             FR_ST_DATA  : protocol_data <= decode_fifo_dout;
    //             default     : protocol_data <= {1{8'b0}};
    //         endcase
    //     end
    // end
    always @(posedge clock) begin // protocol_checksum
        if(rst) begin
            protocol_checksum <= {1{8'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE  : protocol_checksum <= {1{8'b0}};
                FR_ST_LEN   : protocol_checksum <= protocol_checksum + protocol_length [0+:FRAME_FIFO_WR_DWIDTH];
                FR_ST_CMD   : protocol_checksum <= protocol_checksum + protocol_command[0+:FRAME_FIFO_WR_DWIDTH];
                FR_ST_SRCID : protocol_checksum <= protocol_checksum + protocol_srcid  [0+:FRAME_FIFO_WR_DWIDTH];
                FR_ST_DSTID : protocol_checksum <= protocol_checksum + protocol_dstid  [0+:FRAME_FIFO_WR_DWIDTH];
                FR_ST_DATA  : protocol_checksum <= protocol_checksum + decode_fifo_dout[0+:FRAME_FIFO_WR_DWIDTH];
                // FR_ST_DATA  : begin
                //                   if(frame_fifo_wr_en) begin
                //                       protocol_checksum <= protocol_checksum + frame_fifo_din[0+:FRAME_FIFO_WR_DWIDTH];
                //                   end
                //               end
                default     : protocol_data <= {1{8'b0}};
            endcase
        end
    end


    always @(posedge clock) begin
        if(rst) begin
            frame_fifo_rst <= 1'b0;
        end
        else begin
            if(fr_curSt == FR_ST_CLEAR) begin
                if(fr_st_cntr < 8) begin
                    frame_fifo_rst <= 1'b1;
                end
                else begin
                    frame_fifo_rst <= 1'b0;
                end
            end
            else begin
                frame_fifo_rst <= 1'b0;
            end
        end
    end


    always @(posedge clock) begin
        if(rst) begin
            frame_fifo_wr_en <= 1'b0;
            frame_fifo_din   <= {FRAME_FIFO_WR_DWIDTH{1'b0}};
        end
        else begin
            case(fr_curSt)
                FR_ST_IDLE : begin
                    frame_fifo_wr_en <= 1'b0;
                    frame_fifo_din   <= {FRAME_FIFO_WR_DWIDTH{1'b0}};
                end
                FR_ST_HEAD : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_head[0+:FRAME_FIFO_WR_DWIDTH];
                end
                FR_ST_LEN : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_length[0+:FRAME_FIFO_WR_DWIDTH];
                end
                FR_ST_CMD : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_command[0+:FRAME_FIFO_WR_DWIDTH];
                end
                FR_ST_SRCID : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_srcid[0+:FRAME_FIFO_WR_DWIDTH];
                end
                FR_ST_DSTID : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_dstid[0+:FRAME_FIFO_WR_DWIDTH];
                end
                FR_ST_DATA : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= decode_fifo_dout[0+:FRAME_FIFO_WR_DWIDTH];
                    // if(decode_fifo_rd_data_count) begin
                    //     frame_fifo_wr_en <= 1'b1;
                    //     frame_fifo_din   <= decode_fifo_dout[0+:FRAME_FIFO_WR_DWIDTH];
                    // end
                    // else begin
                    //     frame_fifo_wr_en <= 1'b0;
                    //     frame_fifo_din   <= {FRAME_FIFO_WR_DWIDTH{1'b0}};
                    // end
                end
                FR_ST_CHKSUM : begin
                    frame_fifo_wr_en <= 1'b1;
                    frame_fifo_din   <= protocol_checksum[0+:FRAME_FIFO_WR_DWIDTH];
                end
                default : begin
                    frame_fifo_wr_en <= 1'b0;
                    frame_fifo_din   <= {FRAME_FIFO_WR_DWIDTH{1'b0}};
                end
            endcase
        end
    end

    assign decode_fifo_rd_en = (fr_curSt == FR_ST_DATA)? frame_fifo_wr_en : 1'b0;

    // assign frame_fifo_rd_en = 1'b1;

    wire   uart_tx_en;
    wire [7:0] uart_din;
    wire TI;

    assign frame_fifo_rd_en = (frame_fifo_rd_data_count>0) & (~TI);
    assign uart_tx_en   = frame_fifo_rd_en;
    assign uart_din     = frame_fifo_dout;

    uart_send #(
        .CLK_FREQ ( CLOCK_PEROID ),
        .UART_BPS ( UART_BPS_TX  ))
    uart_send (
        .sys_clk           ( clock      ),
        .rst               ( rst        ),
        .uart_en           ( uart_tx_en ),
        .uart_din          ( uart_din   ),

        .uart_txd          ( uart_txd   ),
        .TI                ( TI         ) 
    );



    // ila_128Xbit frame_send_ila (
    //     .clk(clock), // input wire clk
    //     .probe0({
    //         'b0
    //         ,fr_curSt
    //         ,fr_st_cntr
    //         ,frame_fifo_wr_en
    //         ,frame_fifo_din
    //         ,frame_fifo_wr_data_count
    //         ,protocol_payloadSize
    //     }) // input wire [63:0] probe0
    // );


endmodule