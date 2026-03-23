`timescale 1ns / 1ns
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
module CSS_DeModulator #(
    parameter CLOCK_FREQUENCY_MHZ = 32'd10,
    parameter INIT_FILE_PATH  = "dat.mem"
)(
    input  wire clock, // 10MHz
    input  wire rst,
    
    input  wire [16*2-1:0] sigInIQ,
    input  wire            sigInVal,

    input  wire        config_valid   ,
    input  wire [7:0]  config_sfSel   , // SF : 8 - 12
    // input  wire [7:0]  config_bwSel   , // BW : 125KHz 250KHz 500KHz 1MHz
    input  wire [15:0] config_nfft    , // clog2(fftPoint)
    input  wire [15:0] config_fftPoint, // fftPoint

    output reg        decode_end,
    output reg [15:0] decode_dat,
    output reg        decode_val
   
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


    reg             time_offset_ctrl;
    reg             time_offset_clear;  
    reg   [16-1:0]  time_offset; 
    reg             carrierFre_offset_ctrl;
    reg             carrierFre_offset_clear;  
    reg   [16-1:0]  carrierFre_offset; 

    wire  [16*2-1:0]  TO_sync_sigInIQ;
    wire              TO_sync_sigInVal;

    
    wire  [16*2-1:0]  CFO_sync_sigInIQ;
    wire              CFO_sync_sigInVal;

    CarrierFrequency_Sync CarrierFrequency_Offset_Sync (
        .clock             ( clock          ),   
        .rst               ( rst            ),   
        .config_valid      ( config_valid   ),   
        .config_sfSel      ( config_sfSel   ),   
        .offset_ctrl       ( carrierFre_offset_ctrl ),   
        .offset_clear      ( carrierFre_offset_clear),   
        .offset            ( carrierFre_offset      ),   
        .sigInIQ           ( sigInIQ          ),
        .sigInVal          ( sigInVal         ),
        // .sigInIQ           ( TO_sync_sigInIQ        ),   
        // .sigInVal          ( TO_sync_sigInVal       ),   

        .sigOutIQ          ( CFO_sync_sigInIQ       ),   
        .sigOutVal         ( CFO_sync_sigInVal      )    
    );

    Sample_Sync Time_Offset_Sync (  
        .clock             ( clock            ),
        .rst               ( rst              ),
        .config_valid      ( config_valid     ),
        .config_sfSel      ( config_sfSel     ),

        .offset_ctrl       ( time_offset_ctrl ),
        .offset_clear      ( time_offset_clear),
        .offset            ( time_offset      ),
        // .sigInIQ           ( sigInIQ          ),
        // .sigInVal          ( sigInVal         ),
        .sigInIQ           ( CFO_sync_sigInIQ ),
        .sigInVal          ( CFO_sync_sigInVal),

        .sigOutIQ          ( TO_sync_sigInIQ  ),
        .sigOutVal         ( TO_sync_sigInVal )
    );


    
    // CarrierFrequency_Sync CarrierFrequency_Sync (
    //     .clock             ( clock          ),   
    //     .rst               ( rst            ),   
    //     .config_valid      ( config_valid   ),   
    //     .config_sfSel      ( config_sfSel   ),   
    //     .offset_ctrl       ( carrierFre_offset_ctrl ),   
    //     .offset_clear      ( carrierFre_offset_clear),   
    //     .offset            ( carrierFre_offset      ),   
    //     .sigInIQ           ( TO_sync_sigInIQ        ),   
    //     .sigInVal          ( TO_sync_sigInVal       ),   

    //     .sigOutIQ          ( CFO_sync_sigInIQ       ),   
    //     .sigOutVal         ( CFO_sync_sigInVal      )    
    // );


    //-------------------------------------------------
    //---- Base_UpChirp
    //-------------------------------------------------
    wire [16*2-1:0] baseUpChirpIQ   ;
    wire            baseUpChirpVal  ;
    wire [16*2-1:0] baseDownChirpIQ ;
    wire            baseDownChirpVal;
    BaseChirp #(
        .CLOCK_FREQUENCY_MHZ ( CLOCK_FREQUENCY_MHZ ),
        .CHIRP_DIR           ( 0      ),
        .INIT_FILE_PATH      ( INIT_FILE_PATH))
    Up_BaseChirp (
        .clock             ( clock ),
        .rst               ( rst   ),
        .config_valid      ( config_valid   ),
        .config_sfSel      ( config_sfSel   ),
        // .config_bwSel      ( config_bwSel   ),

        .moduSigOut        ( baseUpChirpIQ  ),
        .moduSigValid      ( baseUpChirpVal )
    );
    //-------------------------------------------------
    //---- Base_DownChirp
    //-------------------------------------------------
    BaseChirp #(
        .CLOCK_FREQUENCY_MHZ ( CLOCK_FREQUENCY_MHZ ),
        .CHIRP_DIR           ( 1      ),
        .INIT_FILE_PATH      ( INIT_FILE_PATH))
    Down_BaseChirp (
        .clock             ( clock ),
        .rst               ( rst   ),
        .config_valid      ( config_valid   ),
        .config_sfSel      ( config_sfSel   ),
        // .config_bwSel      ( config_bwSel   ),
        .moduSigOut        ( baseDownChirpIQ  ),
        .moduSigValid      ( baseDownChirpVal )
    );




    //-------------------------------------------------
    //---- sigInIQ * Base_UpChirp 
    //-------------------------------------------------
    wire [79:0] dotPro_UpDat;
    wire        dotPro_UpVal;
    wire [79:0] dotPro_DownDat;
    wire        dotPro_DownVal;
    complexMult_IPCore complexMult_IPCore_Up (
        .aclk              (clock         ), // input wire aclk
        .aresetn           (~rst          ), // input wire aresetn
        .s_axis_a_tvalid   (TO_sync_sigInVal  ), // input wire s_axis_a_tvalid
        .s_axis_a_tdata    (TO_sync_sigInIQ   ), // input wire [31 : 0] s_axis_a_tdata
        .s_axis_a_tuser    (16'b0         ), // input wire [15 : 0] s_axis_a_tuser
        .s_axis_a_tlast    (1'b0          ), // input wire s_axis_a_tlast
        .s_axis_b_tvalid   (TO_sync_sigInVal  ), // input wire s_axis_b_tvalid
        .s_axis_b_tdata    (baseUpChirpIQ ), // input wire [31 : 0] s_axis_b_tdata
        .s_axis_b_tuser    (16'b0         ), // input wire [15 : 0] s_axis_b_tuser
        .s_axis_b_tlast    (1'b0          ), // input wire s_axis_b_tlast
        .m_axis_dout_tvalid(dotPro_UpVal  ), // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata (dotPro_UpDat  ), // output wire [79 : 0] m_axis_dout_tdata
        .m_axis_dout_tuser (              ), // output wire [31 : 0] m_axis_dout_tuser
        .m_axis_dout_tlast (              )  // output wire m_axis_dout_tlast
    );

    complexMult_IPCore complexMult_IPCore_Down (
        .aclk              (clock           ), // input wire aclk
        .aresetn           (~rst            ), // input wire aresetn
        .s_axis_a_tvalid   (TO_sync_sigInVal    ), // input wire s_axis_a_tvalid
        .s_axis_a_tdata    (TO_sync_sigInIQ     ), // input wire [31 : 0] s_axis_a_tdata
        .s_axis_a_tuser    (16'b0           ), // input wire [15 : 0] s_axis_a_tuser
        .s_axis_a_tlast    (1'b0            ), // input wire s_axis_a_tlast
        .s_axis_b_tvalid   (TO_sync_sigInVal    ), // input wire s_axis_b_tvalid
        .s_axis_b_tdata    (baseDownChirpIQ ), // input wire [31 : 0] s_axis_b_tdata
        .s_axis_b_tuser    (16'b0           ), // input wire [15 : 0] s_axis_b_tuser
        .s_axis_b_tlast    (1'b0            ), // input wire s_axis_b_tlast
        .m_axis_dout_tvalid(dotPro_DownVal  ), // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata (dotPro_DownDat  ), // output wire [79 : 0] m_axis_dout_tdata
        .m_axis_dout_tuser (                ), // output wire [31 : 0] m_axis_dout_tuser
        .m_axis_dout_tlast (                )  // output wire m_axis_dout_tlast
    );

    reg [16-1:0] dotPro_UpIQDat [2-1:0];
    reg          dotPro_UpIQVal;
    reg [16-1:0] dotPro_DownIQDat [2-1:0];
    reg          dotPro_DownIQVal;
    always @(posedge clock) begin
        if(rst) begin
            dotPro_UpIQDat[0] <= 16'b0;
            dotPro_UpIQDat[1] <= 16'b0;
            dotPro_UpIQVal    <= 1'b0;
        end
        else begin
            if(dotPro_UpVal) begin
                dotPro_UpIQVal <= 1'b1;
                dotPro_UpIQDat[0] <= dotPro_UpDat[30-:16]; // I
                dotPro_UpIQDat[1] <= dotPro_UpDat[70-:16]; // Q
            end
            else begin
                dotPro_UpIQVal <= 1'b0;
            end
        end
    end
    always @(posedge clock) begin
        if(rst) begin
            dotPro_DownIQDat[0] <= 16'b0;
            dotPro_DownIQDat[1] <= 16'b0;
            dotPro_DownIQVal    <= 1'b0;
        end
        else begin
            if(dotPro_DownVal) begin
                dotPro_DownIQVal <= 1'b1;
                dotPro_DownIQDat[0] <= dotPro_DownDat[30-:16]; // I
                dotPro_DownIQDat[1] <= dotPro_DownDat[70-:16]; // Q
            end
            else begin
                dotPro_DownIQVal <= 1'b0;
            end
        end
    end

    wire [2-1   :0] spectrum_tvalid; // { De_DownChirp, De_UpChirp }
    wire [32*2-1:0] spectrum_tdata ; // { De_DownChirp, De_UpChirp }
    wire [16*2-1:0] spectrum_tuser ; // { De_DownChirp, De_UpChirp }
    wire [2-1   :0] spectrum_tlast ; // { De_DownChirp, De_UpChirp }

    Xfft_Controller #(
        .CHANNEL ( 2 ))
    Xfft_Controller (
        .dclock            ( clock             ),
        .drst              ( rst               ),
        .sigInIQ           ( {dotPro_UpIQDat[1],
                              dotPro_UpIQDat[0],
                              dotPro_DownIQDat[1],
                              dotPro_DownIQDat[0]
                              }                ),
        .sigInVal          ( dotPro_UpVal & dotPro_DownVal),
        .sclock            ( clock             ),
        .srst              ( rst               ),
        .config_valid      ( config_valid      ),
        .config_nfft       ( config_nfft       ),
        .config_fftPoint   ( config_fftPoint   ),

        .m_spectrum_tvalid ( spectrum_tvalid   ),
        .m_spectrum_tdata  ( spectrum_tdata    ),
        .m_spectrum_tuser  ( spectrum_tuser    ),
        .m_spectrum_tlast  ( spectrum_tlast    )

    );

    wire            deDownChirp_peek_valid;
    wire  [32-1:0]  deDownChirp_peek_ampSqrt;
    wire  [16-1:0]  deDownChirp_peek_index;
    wire            deUpChirp_peek_valid;
    wire  [32-1:0]  deUpChirp_peek_ampSqrt;
    wire  [16-1:0]  deUpChirp_peek_index;

    Spectrum_PeekSearch DeDownChirp_PeekSearch (
        .clock             ( clock ),
        .rst               ( rst   ),
        .spectrum_tvalid   ( spectrum_tvalid[0]       ),
        .spectrum_tdata    ( spectrum_tdata[32*1+:32] ),
        .spectrum_tuser    ( spectrum_tuser[16*1+:16] ),
        .spectrum_tlast    ( spectrum_tlast[0]        ),

        .peek_valid        ( deDownChirp_peek_valid   ),
        .peek_ampSqrt      ( deDownChirp_peek_ampSqrt ),
        .peek_index        ( deDownChirp_peek_index   )
    );
    Spectrum_PeekSearch DeUpChirp_PeekSearch (
        .clock             ( clock ),
        .rst               ( rst   ),
        .spectrum_tvalid   ( spectrum_tvalid[1]       ),
        .spectrum_tdata    ( spectrum_tdata[32*0+:32] ),
        .spectrum_tuser    ( spectrum_tuser[16*0+:16] ),
        .spectrum_tlast    ( spectrum_tlast[1]        ),

        .peek_valid        ( deUpChirp_peek_valid     ),
        .peek_ampSqrt      ( deUpChirp_peek_ampSqrt   ),
        .peek_index        ( deUpChirp_peek_index     )
    );



    /* Unwrapping : 
        t_offset = (preamble_offset - (sfd_offset+2^SF*k))/2;
        f_offset = (preamble_offset + (sfd_offset+2^SF*k))/2;
     */
    localparam ST_IDLE          = 4'd0;
    localparam ST_FIND_PREAMBLE = 4'd1;
    localparam ST_FIND_SFD      = 4'd2;
    localparam ST_OFFSET_CALC1  = 4'd3; // Calc : time_offset_arr = preamble_offset - sfd_offset  carrierFre_offset_arr = preamble_offset + sfd_offset
    localparam ST_OFFSET_CALC2  = 4'd4; // Calc : time_offset_arr = time_offset_arr - 2^SF*k      carrierFre_offset_arr = preamble_offset + 2^SF*k
    localparam ST_OFFSET_CALC3  = 4'd5; // Calc : time_offset_arr = time_offset_arr / 2           carrierFre_offset_arr = carrierFre_offset_arr / 2
    localparam ST_OFFSET_CALC4  = 4'd6; // Unwrapping
    localparam ST_OFFSET_SYNC   = 4'd7;

    localparam ST_DECODE_START  = 4'd8;
    localparam ST_DECODE        = 4'd9;
    localparam ST_FINISH        = 4'd10;


    reg [3:0] curSta, nxtSta;

    reg [7:0] preamble_count;
    reg [7:0] sfd_detect_count;

    reg signed [15:0] preamble_offset;
    reg signed [15:0] sfd_offset;

    reg signed [15:0] time_offset_arr[2:0]      ; // t_offset = (preamble_offset - (sfd_offset+2^SF*k))/2;
    reg signed [15:0] carrierFre_offset_arr[2:0]; // f_offset = (preamble_offset + (sfd_offset+2^SF*k))/2;
    wire [15:0] carrierFre_offset_arr_abs[2:0];

    reg signed [15:0] time_offset_t;
    reg signed [15:0] carrierFre_offset_t;

    reg [15:0] last_peek_index;
    reg decode_flag;


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
                nxtSta = ST_FIND_PREAMBLE;
            end
            ST_FIND_PREAMBLE : begin
                if(preamble_count < 6) begin
                    nxtSta = ST_FIND_PREAMBLE;
                end
                else begin
                    nxtSta = ST_FIND_SFD;
                end
            end
            ST_FIND_SFD : begin
                if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin //SFD_SYMBOL
                    if((deDownChirp_peek_ampSqrt>>1) > deUpChirp_peek_ampSqrt) begin
                        nxtSta = ST_OFFSET_CALC1;
                    end
                    else begin
                        if(sfd_detect_count >=2) begin
                            nxtSta = ST_IDLE;
                        end
                        else begin
                            nxtSta = ST_FIND_SFD;
                        end
                    end
                end
                else begin
                    nxtSta = ST_FIND_SFD;
                end
            end
            ST_OFFSET_CALC1 : begin
                nxtSta = ST_OFFSET_CALC2;
            end
            ST_OFFSET_CALC2 : begin
                nxtSta = ST_OFFSET_CALC3;
            end
            ST_OFFSET_CALC3 : begin
                nxtSta = ST_OFFSET_CALC4;
            end
            ST_OFFSET_CALC4 : begin
                nxtSta = ST_OFFSET_SYNC;
            end
            ST_OFFSET_SYNC : begin
                nxtSta = ST_DECODE_START;
            end
            ST_DECODE_START : begin
                if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin
                    if((deDownChirp_peek_ampSqrt>>1) > deUpChirp_peek_ampSqrt ) begin
                    // if(((deDownChirp_peek_ampSqrt>>1) > deUpChirp_peek_ampSqrt) && (deDownChirp_peek_index == 0) ) begin
                        nxtSta = ST_DECODE;
                    end
                    else begin
                        if(sfd_detect_count >=2) begin
                            nxtSta = ST_IDLE;
                        end
                        else begin
                            nxtSta = ST_DECODE_START;
                        end
                        // nxtSta = ST_DECODE_START;
                    end
                end
            end
            ST_DECODE : begin
                if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin //END_SYMBOL
                    if((decode_flag==1'b1) && ((deDownChirp_peek_ampSqrt>>1) > deUpChirp_peek_ampSqrt) ) begin
                        nxtSta = ST_FINISH;
                    end
                    else begin
                        nxtSta = ST_DECODE;
                    end
                end
                else begin
                    nxtSta = ST_DECODE;
                end
            end
            ST_FINISH : begin
                nxtSta = ST_IDLE;
            end
            default : begin
                nxtSta = ST_IDLE;
            end
        endcase
    end


    always @(posedge clock) begin
        if(rst) begin
            preamble_count <= 8'b0;
        end
        else begin
            if(curSta == ST_FIND_PREAMBLE) begin
                if(deUpChirp_peek_valid) begin
                    if(deUpChirp_peek_index == last_peek_index) begin
                        preamble_count <= preamble_count + 1'b1;
                    end
                    else begin
                        preamble_count <= 8'b0;
                    end
                end
            end
            else begin
                preamble_count <= 8'b0;
            end
        end
    end
    always @(posedge clock) begin
        if(rst) begin
            sfd_detect_count <= 8'b0;
        end
        else begin
            case(curSta)
                ST_FIND_SFD : begin
                    if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin
                        if(sfd_detect_count >= 2) begin
                            sfd_detect_count <= 8'd0;
                        end
                        else begin
                            sfd_detect_count <= sfd_detect_count + 1'b1;
                        end
                    end
                end
                ST_DECODE_START: begin
                    if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin
                        if(sfd_detect_count >= 2) begin
                            sfd_detect_count <= 8'd0;
                        end
                        else begin
                            sfd_detect_count <= sfd_detect_count + 1'b1;
                        end
                    end
                end
                default : begin
                    sfd_detect_count <= 8'b0;
                end
            endcase
        end
    end

    

    always @(posedge clock) begin
        if(rst) begin
            last_peek_index <= 16'b0;
        end
        else begin
            if(curSta == ST_FIND_PREAMBLE) begin
                if(deUpChirp_peek_valid) begin
                    last_peek_index <= deUpChirp_peek_index;
                end
            end
        end
    end



    always @(posedge clock) begin // preamble_offset
        if(rst) begin
            preamble_offset <= 16'b0;
        end
        else begin
            if(curSta == ST_FIND_PREAMBLE) begin
                if(deUpChirp_peek_valid) begin
                    case(SF)
                        8'd8    : preamble_offset <= $signed(deUpChirp_peek_index[0+:8 ]);
                        8'd9    : preamble_offset <= $signed(deUpChirp_peek_index[0+:9 ]);
                        8'd10   : preamble_offset <= $signed(deUpChirp_peek_index[0+:10]);
                        8'd11   : preamble_offset <= $signed(deUpChirp_peek_index[0+:11]);
                        8'd12   : preamble_offset <= $signed(deUpChirp_peek_index[0+:12]);
                        default : preamble_offset <= $signed(deUpChirp_peek_index[0+:8 ]);
                    endcase
                end
            end
        end
    end

    always @(posedge clock) begin // sfd_offset
        if(rst) begin
            sfd_offset <= 16'b0;
        end
        else begin
            if(curSta == ST_FIND_SFD) begin
                if(deDownChirp_peek_valid) begin
                    case(SF)
                        8'd8    : sfd_offset <= $signed(deDownChirp_peek_index[0+:8 ]);
                        8'd9    : sfd_offset <= $signed(deDownChirp_peek_index[0+:9 ]);
                        8'd10   : sfd_offset <= $signed(deDownChirp_peek_index[0+:10]);
                        8'd11   : sfd_offset <= $signed(deDownChirp_peek_index[0+:11]);
                        8'd12   : sfd_offset <= $signed(deDownChirp_peek_index[0+:12]);
                        default : sfd_offset <= $signed(deDownChirp_peek_index[0+:8 ]);
                    endcase
                end
            end
        end
    end

    always @(posedge clock) begin // TO & CFO Unwrapping
        if(rst) begin
            time_offset_arr[0]       <= 16'b0; // k=0
            time_offset_arr[1]       <= 16'b0; // k=1
            time_offset_arr[2]       <= 16'b0; // k=-1
            carrierFre_offset_arr[0] <= 16'b0; // k=0
            carrierFre_offset_arr[1] <= 16'b0; // k=1
            carrierFre_offset_arr[2] <= 16'b0; // k=-1
        end
        else begin
            case(curSta)
                ST_OFFSET_CALC1 : begin
                // Calc : time_offset_arr       = preamble_offset - sfd_offset
                // Calc : carrierFre_offset_arr = preamble_offset + sfd_offset
                    case(SF)
                        8'd8    : begin
                            time_offset_arr[0]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 0
                            time_offset_arr[1]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 1
                            time_offset_arr[2]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = -1
                            carrierFre_offset_arr[0] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 0
                            carrierFre_offset_arr[1] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 1
                            carrierFre_offset_arr[2] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = -1
                        end
                        8'd9    : begin
                            time_offset_arr[0]       <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      - {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = 0
                            time_offset_arr[1]       <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      - {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = 1
                            time_offset_arr[2]       <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      - {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = -1
                            carrierFre_offset_arr[0] <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      + {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = 0
                            carrierFre_offset_arr[1] <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      + {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = 1
                            carrierFre_offset_arr[2] <= {{7{preamble_offset[9-1]}}, preamble_offset[0+:9]}
                                                      + {{7{sfd_offset     [9-1]}}, sfd_offset     [0+:9]}; // k = -1
                        end
                        8'd10   : begin
                            time_offset_arr[0]       <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      - {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = 0
                            time_offset_arr[1]       <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      - {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = 1
                            time_offset_arr[2]       <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      - {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = -1
                            carrierFre_offset_arr[0] <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      + {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = 0
                            carrierFre_offset_arr[1] <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      + {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = 1
                            carrierFre_offset_arr[2] <= {{6{preamble_offset[10-1]}}, preamble_offset[0+:10]}
                                                      + {{6{sfd_offset     [10-1]}}, sfd_offset     [0+:10]}; // k = -1
                        end
                        8'd11   : begin
                            time_offset_arr[0]       <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      - {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = 0
                            time_offset_arr[1]       <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      - {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = 1
                            time_offset_arr[2]       <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      - {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = -1
                            carrierFre_offset_arr[0] <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      + {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = 0
                            carrierFre_offset_arr[1] <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      + {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = 1
                            carrierFre_offset_arr[2] <= {{5{preamble_offset[11-1]}}, preamble_offset[0+:11]}
                                                      + {{5{sfd_offset     [11-1]}}, sfd_offset     [0+:11]}; // k = -1
                        end
                        8'd12   : begin
                            time_offset_arr[0]       <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      - {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = 0
                            time_offset_arr[1]       <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      - {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = 1
                            time_offset_arr[2]       <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      - {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = -1
                            carrierFre_offset_arr[0] <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      + {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = 0
                            carrierFre_offset_arr[1] <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      + {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = 1
                            carrierFre_offset_arr[2] <= {{4{preamble_offset[12-1]}}, preamble_offset[0+:12]}
                                                      + {{4{sfd_offset     [12-1]}}, sfd_offset     [0+:12]}; // k = -1
                        end
                        default : begin
                            time_offset_arr[0]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 0
                            time_offset_arr[1]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 1
                            time_offset_arr[2]       <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      - {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = -1
                            carrierFre_offset_arr[0] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 0
                            carrierFre_offset_arr[1] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = 1
                            carrierFre_offset_arr[2] <= {{8{preamble_offset[8-1]}}, preamble_offset[0+:8]}
                                                      + {{8{sfd_offset     [8-1]}}, sfd_offset     [0+:8]}; // k = -1
                        end
                    endcase
                end
                ST_OFFSET_CALC2 : begin
                // Calc : time_offset_arr       = time_offset_arr - 2^SF*k
                // Calc : carrierFre_offset_arr = preamble_offset + 2^SF*k
                    case(SF)
                        8'd8    : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                    ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {8'b1,8'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {8'b1,8'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]              ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {8'b1,8'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {8'b1,8'b0}; // k = -1
                        end
                        8'd9    : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                    ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {7'b1,9'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {7'b1,9'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]              ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {7'b1,9'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {7'b1,9'b0}; // k = -1
                        end
                        8'd10   : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                     ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {6'b1,10'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {6'b1,10'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]               ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {6'b1,10'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {6'b1,10'b0}; // k = -1
                        end
                        8'd11   : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                     ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {5'b1,11'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {5'b1,11'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]               ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {5'b1,11'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {5'b1,11'b0}; // k = -1
                        end
                        8'd12   : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                     ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {4'b1,12'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {4'b1,12'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]               ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {4'b1,12'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {4'b1,12'b0}; // k = -1
                        end
                        default : begin
                            time_offset_arr[0]       <= time_offset_arr[0]                    ; // k = 0
                            time_offset_arr[1]       <= time_offset_arr[1]       - {8'b1,8'b0}; // k = 1
                            time_offset_arr[2]       <= time_offset_arr[2]       + {8'b1,8'b0}; // k = -1
                            carrierFre_offset_arr[0] <= carrierFre_offset_arr[0]              ; // k = 0
                            carrierFre_offset_arr[1] <= carrierFre_offset_arr[1] + {8'b1,8'b0}; // k = 1
                            carrierFre_offset_arr[2] <= carrierFre_offset_arr[2] - {8'b1,8'b0}; // k = -1
                        end
                    endcase
                end
                ST_OFFSET_CALC3 : begin
                // Calc : time_offset_arr       = time_offset_arr / 2
                // Calc : carrierFre_offset_arr = carrierFre_offset_arr / 2
                    time_offset_arr[0]       <= {time_offset_arr[0][15], time_offset_arr[0][1+:15]}; // k = 0
                    time_offset_arr[1]       <= {time_offset_arr[1][15], time_offset_arr[1][1+:15]}; // k = 1
                    time_offset_arr[2]       <= {time_offset_arr[2][15], time_offset_arr[2][1+:15]}; // k = -1
                    carrierFre_offset_arr[0] <= {carrierFre_offset_arr[0][15], carrierFre_offset_arr[0][1+:15]}; // k = 0
                    carrierFre_offset_arr[1] <= {carrierFre_offset_arr[1][15], carrierFre_offset_arr[1][1+:15]}; // k = 1
                    carrierFre_offset_arr[2] <= {carrierFre_offset_arr[2][15], carrierFre_offset_arr[2][1+:15]}; // k = -1
                end
                default : begin
                    
                end
            endcase
        end
    end

    assign carrierFre_offset_arr_abs[0] = (carrierFre_offset_arr[0][15])? -carrierFre_offset_arr[0] : carrierFre_offset_arr[0];  
    assign carrierFre_offset_arr_abs[1] = (carrierFre_offset_arr[1][15])? -carrierFre_offset_arr[1] : carrierFre_offset_arr[1];  
    assign carrierFre_offset_arr_abs[2] = (carrierFre_offset_arr[2][15])? -carrierFre_offset_arr[2] : carrierFre_offset_arr[2];  


    always @(posedge clock) begin
        if(rst) begin
            time_offset_t       <= 16'b0;
            carrierFre_offset_t <= 16'b0;
        end
        else begin
            case(curSta)
                ST_OFFSET_CALC4 : begin
                    if((carrierFre_offset_arr_abs[0] <= carrierFre_offset_arr_abs[1]) &&
                       (carrierFre_offset_arr_abs[0] <= carrierFre_offset_arr_abs[2])) begin
                        time_offset_t       <= time_offset_arr[0];
                        carrierFre_offset_t <= carrierFre_offset_arr[0];
                    end
                    else if((carrierFre_offset_arr_abs[1] <= carrierFre_offset_arr_abs[0]) &&
                        (carrierFre_offset_arr_abs[1] <= carrierFre_offset_arr_abs[2])) begin
                        time_offset_t       <= time_offset_arr[1];
                        carrierFre_offset_t <= carrierFre_offset_arr[1];
                    end
                    else begin
                        time_offset_t       <= time_offset_arr[2];
                        carrierFre_offset_t <= carrierFre_offset_arr[2];
                    end
                end
                default : begin
                    time_offset_t       <= 16'b0;
                    carrierFre_offset_t <= 16'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            time_offset_ctrl        <= 1'b0 ;
            time_offset_clear       <= 1'b0 ;
            time_offset             <= 16'b0;
        end
        else begin
            case(curSta)
                ST_IDLE : begin
                    time_offset_ctrl  <= 1'b1;
                    time_offset_clear <= 1'b1;
                    time_offset       <= 16'b0;
                end
                ST_OFFSET_SYNC : begin
                    time_offset_ctrl  <= 1'b1;
                    time_offset_clear <= 1'b0;
                    case(SF)
                        8'd8   : time_offset <= {8'b0, time_offset_t[0+:8 ]};
                        8'd9   : time_offset <= {7'b0, time_offset_t[0+:9 ]};
                        8'd10  : time_offset <= {6'b0, time_offset_t[0+:10]};
                        8'd11  : time_offset <= {5'b0, time_offset_t[0+:11]};
                        8'd12  : time_offset <= {4'b0, time_offset_t[0+:12]};
                        default: time_offset <= {8'b0, time_offset_t[0+:8 ]};
                    endcase
                end
                default : begin
                    time_offset_ctrl  <= 1'b0;
                    time_offset_clear <= 1'b0;
                    time_offset       <= 16'b0;
                end
            endcase
        end
    end
    always @(posedge clock) begin
        if(rst) begin
            carrierFre_offset_ctrl  <= 1'b0 ;
            carrierFre_offset_clear <= 1'b0 ;
            carrierFre_offset       <= 16'b0;
        end
        else begin
            case(curSta)
                ST_IDLE : begin
                    carrierFre_offset_ctrl  <= 1'b1;
                    carrierFre_offset_clear <= 1'b1;
                    carrierFre_offset       <= 16'b0;
                end
                ST_OFFSET_SYNC : begin
                    carrierFre_offset_ctrl  <= 1'b1;
                    carrierFre_offset_clear <= 1'b0;
                    case(SF)
                        8'd8   : carrierFre_offset <= {{8{carrierFre_offset_t[8 -1]}}, carrierFre_offset_t[0+:8 ]};
                        8'd9   : carrierFre_offset <= {{7{carrierFre_offset_t[9 -1]}}, carrierFre_offset_t[0+:9 ]};
                        8'd10  : carrierFre_offset <= {{6{carrierFre_offset_t[10-1]}}, carrierFre_offset_t[0+:10]};
                        8'd11  : carrierFre_offset <= {{5{carrierFre_offset_t[11-1]}}, carrierFre_offset_t[0+:11]};
                        8'd12  : carrierFre_offset <= {{4{carrierFre_offset_t[12-1]}}, carrierFre_offset_t[0+:12]};
                        default: carrierFre_offset <= {{8{carrierFre_offset_t[8 -1]}}, carrierFre_offset_t[0+:8 ]};
                    endcase
                end
                default : begin
                    carrierFre_offset_ctrl  <= 1'b0;
                    carrierFre_offset_clear <= 1'b0;
                    carrierFre_offset       <= 16'b0;
                end
            endcase
        end
    end

    always @(posedge clock) begin // decode_flag
        if(rst) begin
            decode_flag <= 1'b0;
        end
        else begin
            if(curSta == ST_DECODE) begin
                if(deUpChirp_peek_valid && deDownChirp_peek_valid) begin
                    if((deUpChirp_peek_ampSqrt >> 1) > deDownChirp_peek_ampSqrt) begin
                        decode_flag <= 1'b1;
                    end
                    else begin
                        decode_flag <= 1'b0;
                    end
                end
            end
            else begin
                decode_flag <= 1'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            decode_dat <= 16'b0;
            decode_val <= 1'b0;
        end
        else begin
            if(curSta == ST_DECODE) begin
                if(deDownChirp_peek_valid & deUpChirp_peek_valid) begin //END_SYMBOL
                    if((deUpChirp_peek_ampSqrt>>1) > deDownChirp_peek_ampSqrt) begin
                        decode_val <= 1'b1;
                        decode_dat <= deUpChirp_peek_index;
                    end
                    else begin
                        decode_val <= 1'b0;
                        // decode_dat <= 16'b0;
                    end
                end
                else begin
                    decode_val <= 1'b0;
                    // decode_dat <= 16'b0;
                end
            end
            else begin
                decode_val <= 1'b0;
                // decode_dat <= 16'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            decode_end <= 1'b0;
        end
        else begin
            if(curSta == ST_FINISH) begin
                decode_end <= 1'b1;
            end
            else begin
                decode_end <= 1'b0;
            end
        end
    end








    
    
    // ila_256Xbit DeCSS_ila (
    //     .clk(clock), // input wire clk
    //     .probe0({
    //         'b0
    //         ,sfd_detect_count
    //         ,curSta
    //         ,preamble_count
    //         ,deDownChirp_peek_valid
    //         ,deDownChirp_peek_ampSqrt
    //         ,deDownChirp_peek_index
    //         ,deUpChirp_peek_valid
    //         ,deUpChirp_peek_ampSqrt
    //         ,deUpChirp_peek_index

    //         ,decode_flag

    //         ,decode_end
    //         ,decode_dat
    //         ,decode_val
    //     }) // input wire [63:0] probe0
    // );







    // initial begin
    //     forever begin
    //         @(posedge clock) begin
    //             if(decode_val) begin
    //                 $display("Demodulator Output Code = %4d, \t@ : %t ns", decode_dat, $time);
    //             end
    //         end
    //     end    
    // end



    // integer fp;
    // reg [31:0] count;
    // initial begin
    //     count <= 32'b0;
    //     fp = $fopen("../../../../../Mat/fpga_dotPro.csv","wb");
    //     if(fp == 0) begin
    //         $display("Open failed !\n");
    //         $stop;
    //     end
    //     else begin
    //         // wait(~rst);
    //         @(negedge rst);
    //         #1000
    //         forever begin
    //             @(posedge clock) begin
    //                 if(sigInVal) begin
    //                     // if(count < 8192) begin
    //                         $fdisplay(fp,"%d,%d,%d,%d,%d,%d",
    //                             $signed(sigInIQ[(16*1)+:16]),// Q0
    //                             $signed(sigInIQ[(16*0)+:16]),// I0
    //                             $signed(baseUpChirpIQ[(16*1)+:16]),// Q0
    //                             $signed(baseUpChirpIQ[(16*0)+:16]),// I0
    //                             $signed(baseDownChirpIQ[(16*1)+:16]),// Q0
    //                             $signed(baseDownChirpIQ[(16*0)+:16])// I0
    //                         );
    //                         count <= count +1;
    //                     // end
    //                     // else begin
    //                     //     // $fclose(fp);
    //                     //     // $display("Stop write data @ : %t ns", $time);
    //                     //     // $stop;
    //                     // end
    //                 end
    //             end
    //         end
    //     end
    // end

endmodule