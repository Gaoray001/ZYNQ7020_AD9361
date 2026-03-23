`timescale 1ns / 1ns

module Sample_Sync(
    input  wire clock, // 10MHz
    input  wire rst,
    
    input  wire        config_valid   ,
    input  wire [7:0]  config_sfSel   , // SF : 8 - 12

    input  wire          offset_ctrl,
    input  wire          offset_clear,
    input  wire [16-1:0] offset,

    input  wire [16*2-1:0] sigInIQ,
    input  wire            sigInVal,

    output reg  [16*2-1:0] sigOutIQ,
    output reg             sigOutVal
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

    reg [15:0] offset_r;

    always @(posedge clock) begin
        if(rst) begin
            offset_r <= 16'b0;
        end
        else begin
            if(offset_ctrl) begin
                // offset_r <= offset;
                case(SF)
                    8'd8    : offset_r <= {8'b0, offset[0+:8 ]};
                    8'd9    : offset_r <= {7'b0, offset[0+:9 ]};
                    8'd10   : offset_r <= {6'b0, offset[0+:10]};
                    8'd11   : offset_r <= {5'b0, offset[0+:11]};
                    8'd12   : offset_r <= {4'b0, offset[0+:12]};
                    default : offset_r <= {8'b0, offset[0+:8 ]};
                endcase
            end
        end
    end

    // **** sdpram Write Ports : Cache the Sample Data
    localparam SDPRAM_AWIDTH_A = 13; // 2^13 = 8192
    localparam SDPRAM_DWIDTH_A = 32; // 4B
    localparam SDPRAM_MSIZE    = (2**SDPRAM_AWIDTH_A)*SDPRAM_DWIDTH_A; // (2^13)*4B
    localparam SDPRAM_DWIDTH_B = SDPRAM_DWIDTH_A; //
    localparam SDPRAM_AWIDTH_B = $clog2(SDPRAM_MSIZE/SDPRAM_DWIDTH_B);

    reg  [SDPRAM_AWIDTH_A-1  :0] SDPRAM_wrAddr;
    wire [SDPRAM_DWIDTH_A-1  :0] SDPRAM_wrData;
    wire                         SDPRAM_wrEn  ;
    wire                         SDPRAM_wrWe  ;
    reg  [SDPRAM_AWIDTH_B-1  :0] SDPRAM_rdAddr;
    wire [SDPRAM_DWIDTH_A-1  :0] SDPRAM_rdData;
    wire                         SDPRAM_rdEn  ;

    xpm_memory_sdpram #(
        .ADDR_WIDTH_A            ( SDPRAM_AWIDTH_A     ),
        .ADDR_WIDTH_B            ( SDPRAM_AWIDTH_B     ),
        .AUTO_SLEEP_TIME         ( 0                   ),
        .BYTE_WRITE_WIDTH_A      ( SDPRAM_DWIDTH_A     ),
        .CLOCKING_MODE           ( "common_clock"      ), // "common_clock" or "independent_clock" 
        .ECC_MODE                ( "no_ecc"            ),
        .MEMORY_INIT_FILE        ( "none"              ),
        .MEMORY_INIT_PARAM       ( "0"                 ),
        .MEMORY_OPTIMIZATION     ( "true"              ),
        .MEMORY_PRIMITIVE        ( "auto"              ),
        .MEMORY_SIZE             ( SDPRAM_MSIZE        ),
        .MESSAGE_CONTROL         ( 0                   ),
        .READ_DATA_WIDTH_B       ( SDPRAM_DWIDTH_B     ),
        .READ_LATENCY_B          ( 1                   ),
        .READ_RESET_VALUE_B      ( "0"                 ),
        .RST_MODE_A              ( "SYNC"              ),
        .RST_MODE_B              ( "SYNC"              ),
        .USE_EMBEDDED_CONSTRAINT ( 0                   ),
        .USE_MEM_INIT            ( 1                   ),
        .WAKEUP_TIME             ( "disable_sleep"     ),
        .WRITE_DATA_WIDTH_A      ( SDPRAM_DWIDTH_A     ),
        .WRITE_MODE_B            ( "no_change"         ) 
    ) xpm_memory_sdpram (
        .clka  (clock         ),
        .addra (SDPRAM_wrAddr ),
        .dina  (SDPRAM_wrData ),
        .ena   (SDPRAM_wrEn   ),
        .wea   (SDPRAM_wrWe   ),

        .clkb  (clock          ),
        .rstb  (1'b0           ),
        .addrb (SDPRAM_rdAddr  ),
        .doutb (SDPRAM_rdData  ),
        .enb   (SDPRAM_rdEn    ),
        .regceb(1'b1           )
    );


    reg [15:0] wrAddr;
    wire       wrEn;

    always @(posedge clock) begin
        if(rst) begin
            wrAddr <= 16'b0;
        end
        else begin
            if(config_valid) begin
                wrAddr <= 16'b0;
            end
            else begin
                if(sigInVal) begin
                    wrAddr <= wrAddr + 1'b1;
                end
            end
        end
    end

    assign wrEn = sigInVal;


    always @(*) begin
        case(SF)
            8'd8    : SDPRAM_wrAddr   = wrAddr[0+:8] ;
            8'd9    : SDPRAM_wrAddr   = wrAddr[0+:9] ;
            8'd10   : SDPRAM_wrAddr   = wrAddr[0+:10];
            8'd11   : SDPRAM_wrAddr   = wrAddr[0+:11];
            8'd12   : SDPRAM_wrAddr   = wrAddr[0+:12];
            default : SDPRAM_wrAddr   = wrAddr[0+:8] ;
        endcase
    end

    assign SDPRAM_wrEn   = wrEn;
    assign SDPRAM_wrWe   = 1'b1;
    assign SDPRAM_wrData = sigInIQ;




    // reg [15:0] rdAddr;
    // reg        rdEn;

    // always @(posedge clock) begin
    //     if(rst) begin
    //         rdEn <= 1'b0;
    //     end
    //     else begin
    //         if(SDPRAM_wrEn) begin
    //             rdEn <= 1'b1;
    //         end
    //         else begin
    //             rdEn <= 1'b0;
    //         end
    //     end
    // end

    // always @(posedge clock) begin
    //     if(rst) begin
    //         rdAddr <= {16{1'b0}};
    //     end
    //     else begin
    //         if(rdEn) begin
    //             rdAddr <= rdAddr + 1'b1;
    //         end
    //         else if(offset_ctrl) begin
    //             rdAddr <= rdAddr - offset;
    //         end
    //     end
    // end

    localparam R_ST_IDLE  = 2'd0;
    localparam R_ST_READ  = 2'd1;
    localparam R_ST_DELAY =2'd2;

    reg [1:0] r_curSt, r_nxtSt;
    reg [31:0] cntr;


    reg [15:0] rdAddr;
    reg        rdEn;

    always @(posedge clock) begin
        if(rst) begin
            r_curSt <= R_ST_IDLE;
        end
        else begin
            r_curSt <= r_nxtSt;
        end
    end

    always @(*) begin
        case(r_curSt) 
            R_ST_IDLE : begin
                r_nxtSt = R_ST_READ;
            end
            R_ST_READ : begin
                if(offset_ctrl) begin
                    if(offset_clear) begin
                        r_nxtSt = R_ST_IDLE;
                    end
                    else begin
                        if(offset >0) begin
                            r_nxtSt = R_ST_DELAY;
                        end
                        else begin
                            r_nxtSt = R_ST_READ;
                        end
                    end
                end
                else begin
                    r_nxtSt = R_ST_READ;
                end
            end
            R_ST_DELAY : begin
                if(rdEn) begin
                    if((cntr + 1'b1) < offset_r) begin
                        r_nxtSt = R_ST_DELAY;
                    end
                    else begin
                        r_nxtSt = R_ST_READ;
                    end
                end
                else begin
                    r_nxtSt = R_ST_DELAY;
                end
            end
            default : begin
                r_nxtSt = R_ST_IDLE;
            end
        endcase
    end

    always @(posedge clock) begin
        if(rst) begin
            cntr <= 32'b0;
        end
        else begin
            if(r_curSt == R_ST_DELAY) begin
                if(rdEn) begin
                    if(cntr + 1'b1 < offset_r) begin
                        cntr <= cntr + 1'b1;
                    end
                    else begin
                        cntr <= 32'b0;
                    end
                end
            end
            else begin
                cntr <= 32'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            rdEn <= 1'b0;
        end
        else begin
            if(SDPRAM_wrEn) begin
                rdEn <= 1'b1;
            end
            else begin
                rdEn <= 1'b0;
            end
        end
    end

    always @(posedge clock) begin
        if(rst) begin
            rdAddr <= {16{1'b0}};
        end
        else begin
            case(r_curSt)
                R_ST_IDLE : begin
                    rdAddr <= wrAddr;
                    // rdAddr <= {16{1'b0}};
                end
                R_ST_READ : begin
                    if(rdEn) begin
                        rdAddr <= rdAddr + 1'b1;
                    end
                end
                R_ST_DELAY : begin
                    rdAddr <= rdAddr;
                end
                default : begin
                    rdAddr <= rdAddr;
                end
            endcase
        end
    end



    always @(*) begin
        case(SF)
            8'd8    : SDPRAM_rdAddr   = rdAddr[0+:8] ;
            8'd9    : SDPRAM_rdAddr   = rdAddr[0+:9] ;
            8'd10   : SDPRAM_rdAddr   = rdAddr[0+:10];
            8'd11   : SDPRAM_rdAddr   = rdAddr[0+:11];
            8'd12   : SDPRAM_rdAddr   = rdAddr[0+:12];
            default : SDPRAM_rdAddr   = rdAddr[0+:8] ;
        endcase
    end

    assign SDPRAM_rdEn   = rdEn;


    reg rdValid;
    always @(posedge clock) begin
        if(rst) begin
            rdValid <= 1'b0;
        end
        else begin
            rdValid <= rdEn;
        end
    end
    


    always @(posedge clock) begin
        if(rst) begin
            sigOutIQ  <= {(16*2){1'b0}};
            sigOutVal <= 1'b0;
        end
        else begin
            if(rdValid) begin
                sigOutIQ  <= SDPRAM_rdData;
                sigOutVal <= 1'b1;
            end
            else begin
                sigOutIQ  <= {(16*2){1'b0}};
                sigOutVal <= 1'b0;
            end
        end
    end



endmodule