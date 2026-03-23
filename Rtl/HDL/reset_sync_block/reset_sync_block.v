module reset_sync_block(
    input  clock,
    input  rst,
    input  mmcm_locked,
    output sync_rst
);
    wire locked_sync0;
    sync_block sync_block (
        .clk        ( clock        ),
        .data_in    ( mmcm_locked  ),
        .data_out   ( locked_sync0 ) 
    );
    reset_sync reset_sync (
        .clk        ( clock        ),
        .reset_in   ( rst          ),
        .enable     ( locked_sync0 ),
        .reset_out  ( sync_rst     ) 
    );

endmodule