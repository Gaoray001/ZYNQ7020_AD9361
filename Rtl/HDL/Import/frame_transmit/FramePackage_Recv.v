`timescale 1ns / 1ns

/* 

    Frame Package Struct

    // Head     (1B) -> '$'        8'h24
    // Data     (NB) -> N X Bytes
    // Tail     (2B) -> 'CR' 'LF'  16'h0d0a
    Head     (2B) -> 16'hfeef
    Length   (2B) -> Total Length (All of the Package's Length)
    Command  (2B) -> 16bit
    Src_Id   (1B) -> 8'h01
    Dst_Id   (1B) -> 8'h02
    Data     (NB) -> N X Bytes
    CheckSum (1B) -> Calculate the sum of Length / Command / Src_Id / Dst_Id / Data
    // Tail     (2B) -> 16'h0d0a


    Command : 
        0x0000 -> Frame of SystemCtrl
            Data : InstructionID(2B) + Parameter(NB)
                InstructionID(2B):
                    16'h0001 : 设置设备参数
                    16'hFF01 : 获取设备参数


        0x0001 -> Frame of TransData
            Data : TransData(NB)


    Receive uart data and Convert the data_width from 8bit to 1bit

 */
module FramePackage_Recv #
(
    parameter CLOCK_PEROID = 32'd100_000_000,
    parameter UART_BPS_RX  = 32'd115_200
)(
    input  wire clock,
    input  wire rst,

    input  wire uart_rxd,
    
    input  wire        frame_bitIdle ,
    output reg         frame_bitReady,
    output reg  [15:0] frame_bitCount,
    input  wire        frame_bitRequest,
    output wire        frame_bitData,
    output wire        frame_bitValid

);
`define SIM_MODE

    localparam B2B_INTERVAL_TIMEOUT = CLOCK_PEROID/UART_BPS_RX*50; // Uart接收字节间超时时长


    localparam R_PROTOCOL_HEAD    = 16'hfeef;
    localparam R_PROTOCOL_SRCID   = 8'h01;
    localparam R_PROTOCOL_DSTID   = 8'h02;
    // localparam R_PROTOCOL_TAIL    = 16'h0d0a;

    localparam R_PROTOCOL_CMD_SYSCTRL  = 16'h0000; // Frame of SystemCtrl
    localparam R_PROTOCOL_CMD_TRANSDAT = 16'h0001; // Frame of TransData



    localparam PROTOCOL_DATA_LEN_MAX = 32'd256;  // 定义协议数据字段最大长度
    
    // localparam D_BUF = PROTOCOL_DATA_LEN_MAX; // 数据段 buffer深度

    integer i;

    ////////////////    UART RX MODULE    ////////////////
`ifndef SIM_MODE
    wire       uart_done;
    wire [7:0] uart_data;
    wire       uart_RI  ;

    uart_recv #(
        .CLK_FREQ(CLOCK_PEROID),
        .UART_BPS(UART_BPS_RX   )
        )
    uart_recv(
        .sys_clk  (clock    ), //系统时钟
        .rst      (rst      ), //系统复位
        
        .uart_rxd (uart_rxd ), //UART接收端口
        .RI       (uart_RI  ), //UART接收标志
        .uart_done(uart_done), //接收 帧数据完成
        .uart_data(uart_data)  //接收 帧数据
        
    );
`else



    reg         uart_done;
    reg  [7:0]  uart_data;
    wire       uart_RI  ;
    initial begin
        uart_done <= 1'b0;
        uart_data <= 8'b0;
        wait(rst);
        wait(~rst);
        repeat(1) begin
            #1000
            // #100 
            repeat(3) begin
                uart_data_sm(8'hfe);// Head
                uart_data_sm(8'hef);// Head
                uart_data_sm(8'd13);// Len
                uart_data_sm(8'd00);// Len
                uart_data_sm(8'h01);// Cmd
                uart_data_sm(8'h00);// Cmd
                uart_data_sm(8'h01);// Src
                uart_data_sm(8'h02);// Dst
                uart_data_sm(8'h01);// Dat
                uart_data_sm(8'h52);// Dat
                uart_data_sm(8'h94);// Dat
                uart_data_sm(8'hD1);// Dat
                uart_data_sm(8'hC9);// Chk
                #20_000_000 ;
            end

        end
    end


    task automatic uart_data_sm;
        input [7:0] data;

        begin 
            @(posedge clock) begin
                uart_done <= 1'b1;
                uart_data <= data;
            end
            @(posedge clock) begin
                uart_done <= 1'b0;
                uart_data <= 8'd0;
            end
        end
    endtask


    initial begin
        forever begin
            @(posedge clock) begin
                if(uart_done) begin
                    $display("Modulator Input Code = %4d, \t@ : %t ns", uart_data, $time);
                end
            end
        end
    end
`endif 

    //-------------------------------------------------
    //---- 实现按位读取数据，并根据SF拼接成基带Code (MSB)
    //-------------------------------------------------

    localparam FIFO_DEPTH             = PROTOCOL_DATA_LEN_MAX;
    localparam FIFO_WR_DWIDTH         = 8;
    localparam FIFO_WR_DATA_CNT_WIDTH = $clog2(FIFO_DEPTH)+1;
    localparam FIFO_RD_DWIDTH         = 1;
    localparam FIFO_RD_DATA_CNT_WIDTH = $clog2(FIFO_DEPTH*FIFO_WR_DWIDTH/FIFO_RD_DWIDTH)+1;


    
    reg                               fifo_rst          ;
    wire                              fifo_wr_rst_busy  ;
    reg                               fifo_wr_en        ;
    wire                              fifo_wr_ack       ;
    reg  [FIFO_WR_DWIDTH-1:0]         fifo_din          ;
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

//######## Uart Receive Check 
    reg uart_done_r,uart_done_rr;
    wire uart_done_pos;

    always @ (posedge clock) begin	// uart_done posedge check
        if (rst) begin
            uart_done_r  <= 1'b0;
            uart_done_rr <= 1'b0;            
        end
        else begin
            uart_done_r  <= uart_done  ;
            uart_done_rr <= uart_done_r;
        end
    end

    assign uart_done_pos = (~uart_done_rr) && uart_done_r;
    
    reg [7:0] uart_data_r, uart_data_rr;
    always @(posedge clock) begin
        if(rst) begin
            uart_data_r  <= 8'b0;
            uart_data_rr <= 8'b0;
        end
        else begin
            uart_data_r  <= uart_data;
            uart_data_rr <= uart_data_r;
        end
    end




//######## Uart Receive SM
    localparam ST_IDLE          = 4'd0;
    localparam ST_UART_RX       = 4'd1;
    localparam ST_RECV          = 4'd2;
    localparam ST_TIMER_INT     = 4'd3;

    localparam ST_RECV_IDLE     = 4'd0;
    localparam ST_RECV_HEAD     = 4'd1;
    localparam ST_RECV_LENGTH   = 4'd2;
    localparam ST_RECV_COMMAND  = 4'd3;
    localparam ST_RECV_SRCID    = 4'd4;
    localparam ST_RECV_DSTID    = 4'd5;
    localparam ST_RECV_DATA     = 4'd6;
    localparam ST_RECV_CHECKSUM = 4'd7;
    localparam ST_RECV_TAIL     = 4'd8;
    localparam ST_RECV_SUCCESSFUL = 4'd9;
    localparam ST_RECV_FAILED = 4'd10;
    localparam ST_FIFO_RST    = 4'd11;

    // localparam ST_RECV_CFG_FINISH = 4'd11;
    // localparam ST_WRITE_FIFO    = 4'd10;
    // localparam ST_FIFO_LATENCY  = 4'd11;
    // localparam ST_FIFO_READY    = 4'd12;

    reg [3:0] curSta,nxtSta;

    reg [31:0] B2B_timer;
    wire B2B_timeout;

    reg [15:0] byteCntr;
    reg [8*1-1:0] r_checksum_t;
    reg [8*2-1:0] r_length_t;

    reg [8*2-1       :0] protocol_head    ;
    reg [8*2-1       :0] protocol_length  ;
    reg [8*2-1       :0] protocol_command ;
    reg [8*1-1       :0] protocol_srcid   ;
    reg [8*1-1       :0] protocol_dstid   ;
    reg [8*1-1       :0] protocol_data    ;
    reg [8*1-1       :0] protocol_checksum;
    // reg [8*2-1       :0] protocol_tail    ;


    // reg [8*2-1:0] data_length;

    // wire  protocol_correct;

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
                nxtSta = ST_UART_RX;
            end
            ST_UART_RX : begin
                if(uart_done_pos) begin
                    nxtSta = ST_RECV;
                end
                else begin
                    nxtSta = ST_UART_RX;
                end
            end
            ST_RECV : begin
                nxtSta = ST_UART_RX;
            end
            default : begin
                nxtSta = ST_IDLE;
            end
        endcase
    end


    reg [3:0] recv_curSta,recv_nxtSta;
    always @(posedge clock) begin
        if(rst) begin
            recv_curSta <= ST_RECV_IDLE;
        end
        else begin
            recv_curSta <= recv_nxtSta;
        end
    end


    always @(*) begin
        case(recv_curSta)
            ST_RECV_IDLE : begin
                recv_nxtSta = ST_RECV_HEAD;
            end
            ST_RECV_HEAD : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if({protocol_head[(0*8)+:8],uart_data_rr} == R_PROTOCOL_HEAD) begin
                        recv_nxtSta = ST_RECV_LENGTH;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_HEAD;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_HEAD;
                end
            end
            ST_RECV_LENGTH : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if(byteCntr == 2-1) begin
                        recv_nxtSta = ST_RECV_COMMAND;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_LENGTH;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_LENGTH;
                end
            end
            ST_RECV_COMMAND : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if(byteCntr == 2-1) begin
                        recv_nxtSta = ST_RECV_SRCID;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_COMMAND;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_COMMAND;
                end
            end
            ST_RECV_SRCID : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if(uart_data_rr == R_PROTOCOL_SRCID) begin
                        recv_nxtSta = ST_RECV_DSTID;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_IDLE;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_SRCID;
                end
            end
            ST_RECV_DSTID : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if(uart_data_rr == R_PROTOCOL_DSTID) begin
                        recv_nxtSta = ST_RECV_DATA;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_IDLE;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_DSTID;
                end
            end
            ST_RECV_DATA : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    if(byteCntr == r_length_t-1) begin
                        recv_nxtSta = ST_RECV_CHECKSUM;
                    end
                    else begin
                        recv_nxtSta = ST_RECV_DATA;
                    end
                end
                else begin
                    recv_nxtSta = ST_RECV_DATA;
                end
            end
            ST_RECV_CHECKSUM : begin
                if(curSta == ST_UART_RX && B2B_timeout) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else if(curSta == ST_RECV) begin
                    recv_nxtSta = ST_RECV_SUCCESSFUL;
                    // if(uart_data_rr == r_checksum_t) begin
                    //     recv_nxtSta = ST_RECV_SUCCESSFUL;
                    // end
                    // else begin
                    //     recv_nxtSta = ST_RECV_FAILED;
                    // end
                end
                else begin
                    recv_nxtSta = ST_RECV_CHECKSUM;
                end
            end
            ST_RECV_SUCCESSFUL : begin
                recv_nxtSta = ST_RECV_IDLE;
            end
            ST_RECV_FAILED : begin
                if(protocol_command == R_PROTOCOL_CMD_TRANSDAT) begin
                    recv_nxtSta = ST_FIFO_RST;
                end
                else begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
            end
            ST_FIFO_RST : begin
                if(byteCntr == 16'd60) begin
                    recv_nxtSta = ST_RECV_IDLE;
                end
                else begin
                    recv_nxtSta = ST_FIFO_RST;
                end
            end


            default : begin
                recv_nxtSta = ST_RECV_IDLE;
            end
        endcase
    end

    always @(posedge clock) begin
        if(rst) begin
            B2B_timer <= 32'b0;
        end
        else begin
            case(curSta)
                ST_IDLE : begin
                    B2B_timer <= 32'b0;
                end
                ST_UART_RX : begin
                    if(uart_done_pos) begin
                        B2B_timer <= 32'b0;
                    end
                    else begin
                        if(B2B_timer < B2B_INTERVAL_TIMEOUT) begin
                            B2B_timer <= B2B_timer + 1'b1;
                        end
                        else begin
                            B2B_timer <= 32'b0;
                        end
                    end
                end
                default : begin
                    B2B_timer <= 32'b0;
                end
            endcase
        end
    end
    assign B2B_timeout = (B2B_timer == B2B_INTERVAL_TIMEOUT);

    always @(posedge clock) begin // byteCntr
        if(rst) begin
            byteCntr <= 16'b0;
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    byteCntr <= 16'b0;
                end
                ST_RECV_LENGTH : begin
                    if(curSta == ST_RECV) begin
                        if(byteCntr == 2-1) begin
                            byteCntr <= 16'b0;
                        end
                        else begin
                            byteCntr <= byteCntr + 1'b1;
                        end
                    end
                end
                ST_RECV_COMMAND : begin
                    if(curSta == ST_RECV) begin
                        if(byteCntr == 2-1) begin
                            byteCntr <= 16'b0;
                        end
                        else begin
                            byteCntr <= byteCntr + 1'b1;
                        end
                    end
                end
                ST_RECV_DATA : begin
                    if(curSta == ST_RECV) begin
                        if(byteCntr == r_length_t-1) begin
                            byteCntr <= 16'b0;
                        end
                        else begin
                            byteCntr <= byteCntr + 1'b1;
                        end
                    end
                end
                ST_FIFO_RST : begin
                    if(byteCntr == 16'd60) begin
                        byteCntr <= 16'b0;
                    end
                    else begin
                        byteCntr <= byteCntr + 1'b1;
                    end
                end
                default : begin
                    byteCntr <= 16'b0;
                end
            endcase
        end
    end


    always @(posedge clock) begin // protocol_head
        if(rst) begin
            protocol_head <= {(8*2){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_head <= {(8*2){1'b0}};
                end
                ST_RECV_HEAD : begin
                    if(curSta == ST_RECV) begin
                        protocol_head <= protocol_head<<8 | uart_data_rr;
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_length
        if(rst) begin
            protocol_length <= {(8*2){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_length <= {(8*2){1'b0}};
                end
                ST_RECV_LENGTH : begin
                    if(curSta == ST_RECV) begin
                        protocol_length <= {uart_data_rr,protocol_length[8*1+:8]};
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_command
        if(rst) begin
            protocol_command <= {(8*2){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_command <= {(8*2){1'b0}};
                end
                ST_RECV_COMMAND : begin
                    if(curSta == ST_RECV) begin
                        protocol_command <= {uart_data_rr,protocol_command[8*1+:8]};
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_srcid
        if(rst) begin
            protocol_srcid <= {(8*1){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_srcid <= {(8*1){1'b0}};
                end
                ST_RECV_SRCID : begin
                    if(curSta == ST_RECV) begin
                        protocol_srcid <= uart_data_rr;
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_dstid
        if(rst) begin
            protocol_dstid <= {(8*1){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_dstid <= {(8*1){1'b0}};
                end
                ST_RECV_DSTID : begin
                    if(curSta == ST_RECV) begin
                        protocol_dstid <= uart_data_rr;
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_data
        if(rst) begin
            protocol_data <= {(8*1){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_data <= {(8*1){1'b0}};
                end
                ST_RECV_DATA : begin
                    if(curSta == ST_RECV) begin
                        protocol_data <= uart_data_rr;
                    end
                end
            endcase
        end
    end
    always @(posedge clock) begin // protocol_checksum
        if(rst) begin
            protocol_checksum <= {(8*1){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    protocol_checksum <= {(8*1){1'b0}};
                end
                ST_RECV_CHECKSUM : begin
                    if(curSta == ST_RECV) begin
                        protocol_checksum <= uart_data_rr;
                    end
                end
            endcase
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            r_length_t <= 16'b0;
        end
        else begin
            r_length_t <= protocol_length - 16'd9; // 
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            r_checksum_t <= {(8*1){1'b0}};
        end
        else begin
            case(recv_curSta)
                ST_RECV_IDLE : begin
                    r_checksum_t <=  {(8*1){1'b0}};
                end
                ST_RECV_LENGTH : begin
                    if(curSta == ST_RECV) begin
                        r_checksum_t <= r_checksum_t + uart_data_rr;
                    end
                end
                ST_RECV_COMMAND : begin
                    if(curSta == ST_RECV) begin
                        r_checksum_t <= r_checksum_t + uart_data_rr;
                    end
                end
                ST_RECV_SRCID : begin
                    if(curSta == ST_RECV) begin
                        r_checksum_t <= r_checksum_t + uart_data_rr;
                    end
                end
                ST_RECV_DSTID : begin
                    if(curSta == ST_RECV) begin
                        r_checksum_t <= r_checksum_t + uart_data_rr;
                    end
                end
                ST_RECV_DATA : begin
                    if(curSta == ST_RECV) begin
                        r_checksum_t <= r_checksum_t + uart_data_rr;
                    end
                end
                default : begin
                    r_checksum_t <= r_checksum_t;
                end
            endcase
        end
    end

    always @(posedge clock) begin //  fifo_write_ports
        if(rst) begin
            fifo_wr_en <= 1'b0;
            fifo_din   <= {FIFO_WR_DWIDTH{1'b0}};
        end
        else begin
            if(recv_curSta == ST_RECV_DATA) begin
                if(protocol_command == R_PROTOCOL_CMD_TRANSDAT) begin
                    fifo_wr_en <= (curSta == ST_RECV);
                    fifo_din   <= {<< {uart_data_rr}};
                end
                else begin
                    fifo_wr_en <= 1'b0;
                end
            end
            else begin
                fifo_wr_en <= 1'b0;
            end
        end
    end

    always @(posedge clock) begin // fifo_rst
        if(rst) begin
            fifo_rst <= 1'b0;
        end
        else begin
            if(recv_curSta == ST_FIFO_RST) begin
                if(byteCntr < 16'd20) begin
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

    // assign protocol_correct = (recv_curSta == ST_RECV_FINISH) && 
    //                           (protocol_tail == PROTOCOL_TAIL);






    always @(posedge clock) begin
        if(rst) begin
            frame_bitReady <= 1'b0;
        end
        else begin
            if((recv_curSta == ST_RECV_SUCCESSFUL) && 
                (protocol_command == R_PROTOCOL_CMD_TRANSDAT)) begin
                frame_bitReady <= 1'b1;
            end
            else begin
                frame_bitReady <= 1'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            frame_bitCount <= 16'b0;
        end
        else begin
            if((recv_curSta == ST_RECV_SUCCESSFUL) &&
                (protocol_command == R_PROTOCOL_CMD_TRANSDAT)) begin
                frame_bitCount <= fifo_rd_data_count;
            end
        end

    end


    assign fifo_rd_en = frame_bitRequest ;

    assign frame_bitData  = fifo_dout      ;
    assign frame_bitValid = fifo_data_valid;

    // ila_64bit uart_ila (
    //     .clk(clock), // input wire clk
    //     .probe0({
    //         'b0
    //         ,curSta
    //         ,byteCntr
    //         ,recv_curSta
    //         ,uart_data_rr
    //     }) // input wire [63:0] probe0
    // );


endmodule