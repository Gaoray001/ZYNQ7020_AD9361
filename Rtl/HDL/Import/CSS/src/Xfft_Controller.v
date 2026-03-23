// `default_nettype none
`timescale 1ns / 1ns

module Xfft_Controller #(
    parameter CHANNEL = 1
)(
    input wire dclock,
    input wire drst,
    
    input wire [16*2*CHANNEL-1:0] sigInIQ,
    input wire            sigInVal,

    input wire sclock,
    input wire srst,

    input wire        config_valid,
    input wire [15:0] config_nfft, // clog2(fftPoint)
    input wire [15:0] config_fftPoint, // fftPoint

    // input  wire [15:0] SampleOffset,

    output wire [CHANNEL-1   :0] m_spectrum_tvalid,
    output wire [32*CHANNEL-1:0] m_spectrum_tdata,
    output wire [16*CHANNEL-1:0] m_spectrum_tuser,
    output wire [CHANNEL-1   :0] m_spectrum_tlast
);  
    localparam POINT_MAX = 8192; // 最大FFT点数
    localparam FFT_SCALE_DWIDTH = $clog2(POINT_MAX) * 2;



    // **** as_fifo : Cache the SignalData and Convert the clock domain
    localparam AS_FIFO_DEPTH     = POINT_MAX*2;
    localparam AS_FIFO_WR_DWIDTH = 16*2*CHANNEL;
    localparam AS_FIFO_WR_CWIDTH = $clog2(AS_FIFO_DEPTH)+1;
    localparam AS_FIFO_RD_DWIDTH = AS_FIFO_WR_DWIDTH;
    localparam AS_FIFO_RD_CWIDTH = $clog2(AS_FIFO_DEPTH*AS_FIFO_WR_DWIDTH/AS_FIFO_RD_DWIDTH)+1;

    // wire                         as_fifo_rst        ;
    wire                         as_fifo_wr_rst_busy;
    reg                          as_fifo_wr_en      ;
    reg  [AS_FIFO_WR_DWIDTH-1:0] as_fifo_din        ;
    wire [AS_FIFO_WR_CWIDTH-1:0] as_fifo_wr_cnt     ;
    wire                         as_fifo_rd_rst_busy;
    reg                          as_fifo_rd_en      ;
    wire                         as_fifo_data_valid ;
    wire [AS_FIFO_RD_DWIDTH-1:0] as_fifo_dout       ;
    wire [AS_FIFO_RD_CWIDTH-1:0] as_fifo_rd_cnt     ;


    xpm_fifo_async #(
        .ECC_MODE           ("no_ecc"          ), // String
        .FIFO_MEMORY_TYPE   ("auto"            ), // String  "auto"/"block"/"distributed" 
        .RELATED_CLOCKS     (0                 ), // DECIMAL
        .CDC_SYNC_STAGES    (2                 ), // DECIMAL
        .READ_MODE          ("fwft"            ), // String   "fwft" or "std"
        .FIFO_READ_LATENCY  (0                 ), // DECIMAL  If the mode is "fwft", then the value must be 0.
        .USE_ADV_FEATURES   ("1D1D"            ), // String   Disable almost_full flag and almost_empty flag.

        .FIFO_WRITE_DEPTH   (AS_FIFO_DEPTH     ), // DECIMAL
        .WRITE_DATA_WIDTH   (AS_FIFO_WR_DWIDTH ), // DECIMAL
        .WR_DATA_COUNT_WIDTH(AS_FIFO_WR_CWIDTH ), // DECIMAL
        .READ_DATA_WIDTH    (AS_FIFO_RD_DWIDTH ), // DECIMAL
        .RD_DATA_COUNT_WIDTH(AS_FIFO_RD_CWIDTH ), // DECIMAL

        .DOUT_RESET_VALUE   ("0"               ), // String
        .FULL_RESET_VALUE   (0                 ), // DECIMAL
        .PROG_EMPTY_THRESH  (0                 ), // DECIMAL
        .PROG_FULL_THRESH   (0                 ), // DECIMAL
        .WAKEUP_TIME        (0                 )  // DECIMAL
    )
    as_fifo (
        .rst                (drst               ),
        .wr_clk             (dclock             ),
        .wr_rst_busy        (as_fifo_wr_rst_busy),
        .wr_en              (as_fifo_wr_en      ),
        .wr_ack             (                   ),
        .wr_data_count      (as_fifo_wr_cnt     ),
        .din                (as_fifo_din        ),

        .rd_clk             (sclock             ),
        .rd_rst_busy        (as_fifo_rd_rst_busy),
        .rd_en              (as_fifo_rd_en      ),
        .data_valid         (as_fifo_data_valid ),
        .dout               (as_fifo_dout       ),
        .rd_data_count      (as_fifo_rd_cnt     )
    );


    // **** xfft_IPCore : Max Point is 8192
    wire  fftcore_aresetn;

    wire           s_fftcore_config_tready      ;
    wire           s_fftcore_config_tvalid      ;
    wire [63 : 0]  s_fftcore_config_tdata       ;

    wire           s_fftcore_data_tready        ;
    wire           s_fftcore_data_tvalid        ;
    wire [63 : 0]  s_fftcore_data_tdata         ;
    wire           s_fftcore_data_tlast         ;

    wire [63  : 0] m_fftcore_data_tdata         ;
    wire [15  : 0] m_fftcore_data_tuser         ;
    wire           m_fftcore_data_tvalid        ;
    wire           m_fftcore_data_tlast         ;
    wire           event_frame_started       ;
    wire           event_tlast_unexpected    ;
    wire           event_tlast_missing       ;
    wire           event_data_in_channel_halt;

    xfft_IPCore xfft_IPCore (
        .aclk                      (sclock                     ), // input wire aclk
        .aresetn                   (fftcore_aresetn            ), // input wire aresetn
        .s_axis_config_tready      (s_fftcore_config_tready    ), // output wire s_axis_config_tready
        .s_axis_config_tvalid      (s_fftcore_config_tvalid    ), // input wire s_axis_config_tvalid
        .s_axis_config_tdata       (s_fftcore_config_tdata     ), // input wire [63 : 0] s_axis_config_tdata
        .s_axis_data_tready        (s_fftcore_data_tready      ), // output wire s_axis_data_tready
        .s_axis_data_tvalid        (s_fftcore_data_tvalid      ), // input wire s_axis_data_tvalid
        .s_axis_data_tdata         (s_fftcore_data_tdata       ), // input wire [63 : 0] s_axis_data_tdata
        .s_axis_data_tlast         (s_fftcore_data_tlast       ), // input wire s_axis_data_tlast
        .m_axis_data_tdata         (m_fftcore_data_tdata       ), // output wire [63 : 0] m_axis_data_tdata
        .m_axis_data_tuser         (m_fftcore_data_tuser       ), // output wire [15 : 0] m_axis_data_tuser
        .m_axis_data_tvalid        (m_fftcore_data_tvalid      ), // output wire m_axis_data_tvalid
        .m_axis_data_tlast         (m_fftcore_data_tlast       ), // output wire m_axis_data_tlast
        .event_frame_started       (event_frame_started        ), // output wire event_frame_started
        .event_tlast_unexpected    (event_tlast_unexpected     ), // output wire event_tlast_unexpected
        .event_tlast_missing       (event_tlast_missing        ), // output wire event_tlast_missing
        .event_data_in_channel_halt(event_data_in_channel_halt )  // output wire event_data_in_channel_halt
    );

    // **** complexMult_IPCore : fft_real^2 + fft_imag^2 = (fft_real + j.fft_imag) .* (fft_real - j.fft_imag)

    wire [79:0] m_Ch0_cmpMult_tdata;
    wire [31:0] m_Ch0_cmpMult_tuser;
    wire        m_Ch0_cmpMult_tvalid;
    wire        m_Ch0_cmpMult_tlast;
    wire [79:0] m_Ch1_cmpMult_tdata;
    wire [31:0] m_Ch1_cmpMult_tuser;
    wire        m_Ch1_cmpMult_tvalid;
    wire        m_Ch1_cmpMult_tlast;

    complexMult_IPCore Ch0_fftSqrt (
        .aclk              (sclock ), // input wire aclk
        .aresetn           (~srst  ), // input wire aresetn
        .s_axis_a_tvalid   (m_fftcore_data_tvalid ), // input wire s_axis_a_tvalid
        .s_axis_a_tdata    ({$signed(m_fftcore_data_tdata[16*1+:16]),
                             $signed(m_fftcore_data_tdata[16*0+:16])} ), // input wire [31 : 0] s_axis_a_tdata
        .s_axis_a_tuser    (m_fftcore_data_tuser  ), // input wire [15 : 0] s_axis_a_tuser
        .s_axis_a_tlast    (m_fftcore_data_tlast  ), // input wire s_axis_a_tlast
        .s_axis_b_tvalid   (m_fftcore_data_tvalid ), // input wire s_axis_b_tvalid
        .s_axis_b_tdata    ({-$signed(m_fftcore_data_tdata[16*1+:16]),
                             $signed(m_fftcore_data_tdata[16*0+:16])} ), // input wire [31 : 0] s_axis_b_tdata
        .s_axis_b_tuser    (m_fftcore_data_tuser  ), // input wire [15 : 0] s_axis_b_tuser
        .s_axis_b_tlast    (m_fftcore_data_tlast  ), // input wire s_axis_b_tlast
        .m_axis_dout_tvalid(m_Ch0_cmpMult_tvalid  ), // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata (m_Ch0_cmpMult_tdata   ), // output wire [79 : 0] m_axis_dout_tdata
        .m_axis_dout_tuser (m_Ch0_cmpMult_tuser   ), // output wire [31 : 0] m_axis_dout_tuser
        .m_axis_dout_tlast (m_Ch0_cmpMult_tlast   )  // output wire m_axis_dout_tlast
    );
    complexMult_IPCore Ch1_fftSqrt (
        .aclk              (sclock ), // input wire aclk
        .aresetn           (~srst  ), // input wire aresetn
        .s_axis_a_tvalid   (m_fftcore_data_tvalid ), // input wire s_axis_a_tvalid
        .s_axis_a_tdata    ({$signed(m_fftcore_data_tdata[16*3+:16]),
                             $signed(m_fftcore_data_tdata[16*2+:16])} ), // input wire [31 : 0] s_axis_a_tdata
        .s_axis_a_tuser    (m_fftcore_data_tuser  ), // input wire [15 : 0] s_axis_a_tuser
        .s_axis_a_tlast    (m_fftcore_data_tlast  ), // input wire s_axis_a_tlast
        .s_axis_b_tvalid   (m_fftcore_data_tvalid ), // input wire s_axis_b_tvalid
        .s_axis_b_tdata    ({-$signed(m_fftcore_data_tdata[16*3+:16]),
                             $signed(m_fftcore_data_tdata[16*2+:16])} ), // input wire [31 : 0] s_axis_b_tdata
        .s_axis_b_tuser    (m_fftcore_data_tuser  ), // input wire [15 : 0] s_axis_b_tuser
        .s_axis_b_tlast    (m_fftcore_data_tlast  ), // input wire s_axis_b_tlast
        .m_axis_dout_tvalid(m_Ch1_cmpMult_tvalid  ), // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata (m_Ch1_cmpMult_tdata   ), // output wire [79 : 0] m_axis_dout_tdata
        .m_axis_dout_tuser (m_Ch1_cmpMult_tuser   ), // output wire [31 : 0] m_axis_dout_tuser
        .m_axis_dout_tlast (m_Ch1_cmpMult_tlast   )  // output wire m_axis_dout_tlast
    );

    reg [31:0] m_Ch0_cmpMult_tdata_r;
    reg [15:0] m_Ch0_cmpMult_tuser_r;
    reg        m_Ch0_cmpMult_tvalid_r;
    reg        m_Ch0_cmpMult_tlast_r;
    reg [31:0] m_Ch1_cmpMult_tdata_r;
    reg [15:0] m_Ch1_cmpMult_tuser_r;
    reg        m_Ch1_cmpMult_tvalid_r;
    reg        m_Ch1_cmpMult_tlast_r;

    always @(posedge sclock) begin
        if(srst) begin
            m_Ch0_cmpMult_tdata_r <= 32'b0;
            m_Ch0_cmpMult_tuser_r <= 16'b0;
            m_Ch0_cmpMult_tvalid_r <= 1'b0;
            m_Ch0_cmpMult_tlast_r <= 1'b0;
        end
        else begin
            if(m_Ch0_cmpMult_tvalid) begin
                m_Ch0_cmpMult_tdata_r <= m_Ch0_cmpMult_tdata;
                m_Ch0_cmpMult_tuser_r <= m_Ch0_cmpMult_tuser[0+:16];
                m_Ch0_cmpMult_tlast_r <= m_Ch0_cmpMult_tlast;
            end
            else begin
                m_Ch0_cmpMult_tdata_r <= 32'b0;
                m_Ch0_cmpMult_tuser_r <= 16'b0;
                m_Ch0_cmpMult_tlast_r <= 1'b0;
            end
            m_Ch0_cmpMult_tvalid_r <= m_Ch0_cmpMult_tvalid;
        end
    end
    always @(posedge sclock) begin
        if(srst) begin
            m_Ch1_cmpMult_tdata_r <= 32'b0;
            m_Ch1_cmpMult_tuser_r <= 16'b0;
            m_Ch1_cmpMult_tvalid_r <= 1'b0;
            m_Ch1_cmpMult_tlast_r <= 1'b0;
        end
        else begin
            if(m_Ch1_cmpMult_tvalid) begin
                m_Ch1_cmpMult_tdata_r <= m_Ch1_cmpMult_tdata;
                m_Ch1_cmpMult_tuser_r <= m_Ch1_cmpMult_tuser[0+:16];
                m_Ch1_cmpMult_tlast_r <= m_Ch1_cmpMult_tlast;
            end
            else begin
                m_Ch1_cmpMult_tdata_r <= 32'b0;
                m_Ch1_cmpMult_tuser_r <= 16'b0;
                m_Ch1_cmpMult_tlast_r <= 1'b0;
            end
            m_Ch1_cmpMult_tvalid_r <= m_Ch1_cmpMult_tvalid;
        end
    end


    // **** as_fifo Write State Machine : In order to cache the SignalData and convert the clock
    localparam CACHE_ST_IDLE  = 4'd0;
    localparam CACHE_ST_WRITE = 4'd1;

    reg [3:0] cache_curSt, cache_nxtSt; // 
    always @(posedge dclock) begin
        if(drst) begin
            cache_curSt <= CACHE_ST_IDLE;
        end
        else begin
            cache_curSt <= cache_nxtSt;
        end
    end
    always @(*) begin
        case(cache_curSt)
            CACHE_ST_IDLE : begin
                cache_nxtSt = CACHE_ST_WRITE;
            end
            CACHE_ST_WRITE : begin
                cache_nxtSt = CACHE_ST_WRITE;
            end
            default : begin
                cache_nxtSt = CACHE_ST_IDLE;
            end
        endcase
    end

    always @(posedge dclock) begin
        if(drst) begin
            as_fifo_wr_en     <= 1'b0;
            as_fifo_din       <= {AS_FIFO_WR_DWIDTH{1'b0}};
        end
        else begin
            if(cache_curSt == CACHE_ST_WRITE) begin
                as_fifo_wr_en <= sigInVal;
                as_fifo_din   <= sigInIQ;
            end
            else begin
                as_fifo_wr_en <= 1'b0;
                as_fifo_din   <= {AS_FIFO_WR_DWIDTH{1'b0}};
            end
        end
    end

    // **** as_fifo Read State Machine : In order to cache the SignalData and convert the clock
    localparam FFT_ST_IDLE        = 4'd0;
    localparam FFT_ST_CONFIG      = 4'd1;
    localparam FFT_ST_DATA_READY0 = 4'd2; // FIFO data ready for offset_st
    localparam FFT_ST_OFFSET      = 4'd3;
    localparam FFT_ST_DATA_READY1 = 4'd4; // FIFO data ready for xin_st
    localparam FFT_ST_XIN         = 4'd5;

    reg [15:0] config_nfft_r;
    reg [15:0] config_fftPoint_r;
    reg [FFT_SCALE_DWIDTH-1:0] config_scale_r;
    always @(posedge sclock) begin
        if(srst) begin
            config_nfft_r     <= 16'd8; // SF = 8
            config_fftPoint_r <= 16'd256; // SF = 8
            config_scale_r    <= {8{2'b01}};
            // config_nfft_r     <= 16'd9; // SF = 9
            // config_fftPoint_r <= 16'd512; // SF = 9
            // config_scale_r    <= {9{2'b01}};
        end
        else begin
            if(config_valid) begin
                config_nfft_r     <= config_nfft;
                config_fftPoint_r <= config_fftPoint;
                case(config_nfft)
                    16'd8   : config_scale_r <= {8{2'b01}};
                    16'd9   : config_scale_r <= {9{2'b01}};
                    16'd10  : config_scale_r <= {10{2'b01}};
                    16'd11  : config_scale_r <= {11{2'b01}};
                    16'd12  : config_scale_r <= {12{2'b01}};
                    default : config_scale_r <= {8{2'b01}};
                endcase
            end
        end
    end



    reg [3:0] fft_curSt, fft_nxtSt;
    reg [31:0] x_cntr;
    reg [15:0] cur_fft_point;

    always @(posedge sclock) begin
        if(srst || config_valid) begin
            fft_curSt <= FFT_ST_IDLE;
        end
        else begin
            fft_curSt <= fft_nxtSt;
        end
    end
    always @(*) begin
        case(fft_curSt)
            FFT_ST_IDLE : begin
                if(x_cntr == 2) begin
                    fft_nxtSt = FFT_ST_CONFIG;
                end
                else begin
                    fft_nxtSt = FFT_ST_IDLE;
                end
            end
            FFT_ST_CONFIG : begin
                if(s_fftcore_config_tready & s_fftcore_config_tvalid) begin
                    // if(SampleOffset == 0) begin
                    //     fft_nxtSt = FFT_ST_DATA_READY1;
                    // end
                    // else begin
                    //     fft_nxtSt = FFT_ST_DATA_READY0;
                    // end
                    fft_nxtSt = FFT_ST_DATA_READY1;
                end
                else begin
                    fft_nxtSt = FFT_ST_CONFIG;
                end
            end
            // FFT_ST_DATA_READY0 : begin // FIFO data ready for FFT_ST_OFFSET
            //     if(as_fifo_rd_cnt < SampleOffset) begin
            //         fft_nxtSt = FFT_ST_DATA_READY0;
            //     end
            //     else begin
            //         fft_nxtSt = FFT_ST_OFFSET;
            //     end
            // end
            // FFT_ST_OFFSET : begin
            //     if(x_cntr == SampleOffset-1) begin
            //         fft_nxtSt = FFT_ST_DATA_READY1;
            //     end
            //     else begin
            //         fft_nxtSt = FFT_ST_OFFSET;
            //     end
            // end
            FFT_ST_DATA_READY1 : begin // FIFO data ready for FFT_ST_XIN
                if(as_fifo_rd_cnt < cur_fft_point) begin
                    fft_nxtSt = FFT_ST_DATA_READY1;
                end
                else begin
                    fft_nxtSt = FFT_ST_XIN;
                end
            end
            FFT_ST_XIN : begin
                if(s_fftcore_data_tready & s_fftcore_data_tvalid & (x_cntr == cur_fft_point-1)) begin
                    fft_nxtSt = FFT_ST_CONFIG;
                end
                else begin
                    fft_nxtSt = FFT_ST_XIN;
                end
            end
            default : begin
                fft_nxtSt = FFT_ST_IDLE;
            end
        endcase
    end
    
    assign fftcore_aresetn = ~(fft_curSt == FFT_ST_IDLE);

    always @(posedge sclock) begin // cur_fft_point
        if(srst) begin
            cur_fft_point <= 16'b0;
        end
        else begin
            if(fft_curSt == FFT_ST_CONFIG) begin
                if(s_fftcore_config_tready & s_fftcore_config_tvalid) begin
                    cur_fft_point <= config_fftPoint_r;
                end
            end
        end
    end

    always @(posedge sclock) begin
        if(srst) begin
            x_cntr <= 32'b0;
        end
        else begin
            case(fft_curSt)
                FFT_ST_IDLE : begin
                    if(x_cntr == 2) begin
                        x_cntr <= 32'b0;
                    end
                    else begin
                        x_cntr <= x_cntr + 1'b1;
                    end
                end
                // FFT_ST_OFFSET : begin
                //     if(x_cntr == SampleOffset-1) begin
                //         x_cntr <= 32'b0;
                //     end
                //     else begin
                //         x_cntr <= x_cntr + 1'b1;
                //     end
                // end
                FFT_ST_XIN : begin
                    if(s_fftcore_data_tready & s_fftcore_data_tvalid) begin
                        if(x_cntr == cur_fft_point-1) begin
                            x_cntr <= 32'b0;
                        end
                        else begin
                            x_cntr <= x_cntr + 1'b1;
                        end
                    end
                end
                default : begin
                    x_cntr <= 32'b0;
                end
            endcase
        end
    end

    assign s_fftcore_config_tvalid = (fft_curSt == FFT_ST_CONFIG);
    assign s_fftcore_config_tdata  = {config_scale_r,config_scale_r, 1'b1, 1'b1, 3'b0, config_nfft_r[0+:5]};

    // assign as_fifo_rd_en     = s_fftcore_data_tready & s_fftcore_data_tvalid;
    always @(*) begin
        case(fft_curSt)
            FFT_ST_OFFSET : begin
                if(as_fifo_rd_cnt > 0) begin
                    as_fifo_rd_en = 1'b1;
                end
                else begin
                    as_fifo_rd_en = 1'b0;
                end
            end
            FFT_ST_XIN : begin
                as_fifo_rd_en = s_fftcore_data_tready;
            end
            default : begin
                as_fifo_rd_en = 1'b0;
            end
        endcase
    end


    assign s_fftcore_data_tdata  = (fft_curSt == FFT_ST_XIN) ? as_fifo_dout : {AS_FIFO_RD_DWIDTH{1'b0}};
    assign s_fftcore_data_tvalid = (fft_curSt == FFT_ST_XIN) ? s_fftcore_data_tready : 1'b0;
    assign s_fftcore_data_tlast  = (fft_curSt == FFT_ST_XIN) && (x_cntr == cur_fft_point-1);


    assign m_spectrum_tvalid[0]        = m_Ch0_cmpMult_tvalid_r;
    assign m_spectrum_tdata[32*0+:32]  = m_Ch0_cmpMult_tdata_r;
    assign m_spectrum_tuser[16*0+:16]  = m_Ch0_cmpMult_tuser_r;
    assign m_spectrum_tlast[0]         = m_Ch0_cmpMult_tlast_r;

    assign m_spectrum_tvalid[1]        = m_Ch1_cmpMult_tvalid_r;
    assign m_spectrum_tdata[32*1+:32]  = m_Ch1_cmpMult_tdata_r;
    assign m_spectrum_tuser[16*1+:16]  = m_Ch1_cmpMult_tuser_r;
    assign m_spectrum_tlast[1]         = m_Ch1_cmpMult_tlast_r;


endmodule