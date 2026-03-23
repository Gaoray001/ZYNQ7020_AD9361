module Resample_Down_Deci2 #(
    parameter INPUT_DWIDTH  = 16,
    parameter OUTPUT_DWIDTH = 16,
    parameter CHANNEL       = 2 
)(
    input  wire clock,
    input  wire rst,

    input  wire [INPUT_DWIDTH*CHANNEL-1:0] SampleIn_Dat,
    input  wire                      SampleIn_Val,

    output wire [OUTPUT_DWIDTH*CHANNEL-1:0] SampleOut_Dat,
    output wire                      SampleOut_Val
);



    genvar g;

    wire [39:0] firOut_dat [CHANNEL-1:0];
    wire [CHANNEL-1:0] firOut_val;

    generate
        for(g=0; g<CHANNEL; g=g+1) begin
            Rx_ReSample_FIR_F2 ReSample_FIR (
                .aclk              ( clock                          ),
                .aresetn           ( ~rst                           ),
                .s_axis_data_tready(                                ),
                .s_axis_data_tvalid( SampleIn_Val                   ),
                .s_axis_data_tdata ( SampleIn_Dat[INPUT_DWIDTH*g+:INPUT_DWIDTH] ),
                .m_axis_data_tvalid( firOut_val[g]                  ),
                .m_axis_data_tdata ( firOut_dat[g]                  ) 
            );

            if(g==0) begin
                assign SampleOut_Val = firOut_val[g];
            end

            assign SampleOut_Dat[OUTPUT_DWIDTH*g+:OUTPUT_DWIDTH] = firOut_dat[g][(37)-:OUTPUT_DWIDTH];
        end
    endgenerate


endmodule