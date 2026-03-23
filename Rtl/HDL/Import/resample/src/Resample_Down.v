module Resample_Down #(
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



    //// /4
    wire [(DWIDTH+2)*CHANNEL-1:0] deci4_L1_dat;
    wire                          deci4_L1_val;

    Resample_Down_Deci4_1 #(
        .INPUT_DWIDTH  ( DWIDTH   ),
        .OUTPUT_DWIDTH ( DWIDTH+2 ),
        .CHANNEL       ( 2        ))
    Resample_Down_Deci4_1 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( SampleIn_Dat    ),
        .SampleIn_Val      ( SampleIn_Val    ),

        .SampleOut_Dat     ( deci4_L1_dat    ),
        .SampleOut_Val     ( deci4_L1_val    )
    );


    //// /4
    wire [(DWIDTH+4)*CHANNEL-1:0] deci4_L2_dat;
    wire                          deci4_L2_val;

    Resample_Down_Deci4_2 #(
        .INPUT_DWIDTH  ( DWIDTH+2 ),
        .OUTPUT_DWIDTH ( DWIDTH+4 ),
        .CHANNEL       ( 2        ))
    Resample_Down_Deci4_2 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( deci4_L1_dat    ),
        .SampleIn_Val      ( deci4_L1_val    ),

        .SampleOut_Dat     ( deci4_L2_dat    ),
        .SampleOut_Val     ( deci4_L2_val    )
    );

    //// /5
    wire [(DWIDTH+6)*CHANNEL-1:0] deci5_dat;
    wire                          deci5_val;

    Resample_Down_Deci5 #(
        .INPUT_DWIDTH  ( DWIDTH+4 ),
        .OUTPUT_DWIDTH ( DWIDTH+6 ),
        .CHANNEL       ( 2        ))
    Resample_Down_Deci5 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( deci4_L2_dat    ),
        .SampleIn_Val      ( deci4_L2_val    ),

        .SampleOut_Dat     ( deci5_dat       ),
        .SampleOut_Val     ( deci5_val       )
    );

    //// /2
    wire [(DWIDTH+8)*CHANNEL-1:0] deci2_dat;
    wire                          deci2_val;

    Resample_Down_Deci2 #(
        .INPUT_DWIDTH  ( DWIDTH+6 ),
        .OUTPUT_DWIDTH ( DWIDTH+8 ),
        .CHANNEL       ( 2        ))
    Resample_Down_Deci2 (
        .clock             ( clock           ),
        .rst               ( rst             ),
        .SampleIn_Dat      ( deci5_dat       ),
        .SampleIn_Val      ( deci5_val       ),

        .SampleOut_Dat     ( deci2_dat       ),
        .SampleOut_Val     ( deci2_val       )
    );

    genvar g;

    generate
        for(g=0; g<CHANNEL; g=g+1) begin
            always @(posedge clock) begin
                if(rst) begin
                    SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= {DWIDTH{1'b0}};
                end
                else begin
                    if(deci2_val) begin
                        SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= 
                            deci2_dat[((DWIDTH+8)*(g+1)-1-4)-:DWIDTH];
                    end
                    // else begin
                    //     SampleOut_Dat[(DWIDTH*g)+:DWIDTH] <= {DWIDTH{1'b0}};
                    // end
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
            SampleOut_Val <= deci2_val;
        end
    end

endmodule