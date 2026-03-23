module Resample_Up #(
    parameter DWIDTH        = 16,
    parameter CHANNEL       = 2 
)(
    input  wire clock,
    input  wire rst,

    input  wire [DWIDTH*CHANNEL-1:0] SampleIn_Dat,
    input  wire                      SampleIn_Val,

    output reg  [DWIDTH*CHANNEL-1:0] SampleOut_Dat,
    output reg                       SampleOut_Val
);



    //// X2
    wire [(DWIDTH+2)*CHANNEL-1:0] interp2_dat;
    wire                          interp2_val;

    Resample_Up_Interp2 #(
        .INPUT_DWIDTH  ( DWIDTH   ),
        .OUTPUT_DWIDTH ( DWIDTH+2 ),
        .CHANNEL       ( 2        ))
    Resample_Up_Interp2 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( SampleIn_Dat    ),
        .SampleIn_Val      ( SampleIn_Val    ),

        .SampleOut_Dat     ( interp2_dat     ),
        .SampleOut_Val     ( interp2_val     )
    );


    //// X5
    wire [(DWIDTH+4)*CHANNEL-1:0] interp5_dat;
    wire                          interp5_val;

    Resample_Up_Interp5 #(
        .INPUT_DWIDTH  ( DWIDTH+2 ),
        .OUTPUT_DWIDTH ( DWIDTH+4 ),
        .CHANNEL       ( 2        ))
    Resample_Up_Interp5 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( interp2_dat     ),
        .SampleIn_Val      ( interp2_val     ),

        .SampleOut_Dat     ( interp5_dat     ),
        .SampleOut_Val     ( interp5_val     )
    );

    //// X4
    wire [(DWIDTH+6)*CHANNEL-1:0] interp4_L1_dat;
    wire                          interp4_L1_val;

    Resample_Up_Interp4_1 #(
        .INPUT_DWIDTH  ( DWIDTH+4 ),
        .OUTPUT_DWIDTH ( DWIDTH+6 ),
        .CHANNEL       ( 2        ))
    Resample_Up_Interp4_1 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( interp5_dat     ),
        .SampleIn_Val      ( interp5_val     ),

        .SampleOut_Dat     ( interp4_L1_dat  ),
        .SampleOut_Val     ( interp4_L1_val  )
    );

    //// X4
    wire [(DWIDTH+8)*CHANNEL-1:0] interp4_L2_dat;
    wire                          interp4_L2_val;

    Resample_Up_Interp4_2 #(
        .INPUT_DWIDTH  ( DWIDTH+6 ),
        .OUTPUT_DWIDTH ( DWIDTH+8 ),
        .CHANNEL       ( 2        ))
    Resample_Up_Interp4_2 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( interp4_L1_dat  ),
        .SampleIn_Val      ( interp4_L1_val  ),

        .SampleOut_Dat     ( interp4_L2_dat  ),
        .SampleOut_Val     ( interp4_L2_val  )
    );

    genvar g;

    generate
        for(g=0; g<CHANNEL; g=g+1) begin
            always @(posedge clock) begin
                if(rst) begin
                    SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= {DWIDTH{1'b0}};
                end
                else begin
                    if(interp4_L2_val) begin
                        SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= 
                            interp4_L2_dat[((DWIDTH+8)*(g+1)-1-5)-:DWIDTH];
                    end
                    else begin
                        SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= {DWIDTH{1'b0}};
                    end
                end
            end
            // assign SampleOut_Dat[(DWIDTH*g)+:DWIDTH] = 
            //             interp4_L2_dat[((DWIDTH+6)*(g+1)-1-4)-:DWIDTH];
        end
    endgenerate

    // assign SampleOut_Val = interp4_L2_val;

    always @(posedge clock) begin
        if(rst) begin
            SampleOut_Val <= 1'b0;
        end
        else begin
            SampleOut_Val <= interp4_L2_val;
        end
    end

endmodule