`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/30 10:04:37
// Design Name: 
// Module Name: ad9361_spi_drv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "./AD9361_REG_SPI_PARAM.vh"

module ad9361_spi_drv #(
    parameter CLK_PARAM = 10_000_000  
)(
        input clk       ,
        input rstn      ,

        output mdio_sclk,
        output mdio_sdi ,
        output mdio_csb ,
        input  mdio_sdo ,

        input              AD9361_Ctrl_Enable,
        input  [3: 0]      Rx_VcoDivider,
        input  [3: 0]      Tx_VcoDivider,
        input  [10:0]      Rx_FreqInteger,
        input  [22:0]      Rx_FreqFractional,
        input  [10:0]      Tx_FreqInteger,
        input  [22:0]      Tx_FreqFractional ,

        input wire         TX_ATT_Valid    ,
        input wire [15:0]  Tx0_ATT_data    ,
        input wire [15:0]  Tx1_ATT_data                         
    );

    localparam AD9361_INIT_TIME = CLK_PARAM * 3;  //3S延时后开始初始化AD9361
    localparam SPI_CLK_US = CLK_PARAM / 1_000_000;

    reg AD9361_Ctrl_Enable_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            AD9361_Ctrl_Enable_r <= 1'b0;
        else 
            AD9361_Ctrl_Enable_r <= AD9361_Ctrl_Enable;
    end

    reg TX_ATT_Valid_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            TX_ATT_Valid_r <= 1'b0;
        else 
            TX_ATT_Valid_r <= TX_ATT_Valid;
    end

    reg [3:0] Rx_VcoDivider_r,Tx_VcoDivider_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) begin
            Rx_VcoDivider_r <= 4'b0; Tx_VcoDivider_r <= 4'b0;
        end
        else begin
            Rx_VcoDivider_r <= Rx_VcoDivider;
            Tx_VcoDivider_r <= Tx_VcoDivider;
        end
    end

    reg [10:0] Rx_FreqInteger_r;
    reg [22:0] Rx_FreqFractional_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) begin
            Rx_FreqInteger_r <= 11'b0; Rx_FreqFractional_r <= 23'b0;
        end
        else begin
            Rx_FreqInteger_r    <= Rx_FreqInteger;
            Rx_FreqFractional_r <= Rx_FreqFractional;
        end
    end

    reg [10:0] Tx_FreqInteger_r;
    reg [22:0] Tx_FreqFractional_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) begin
            Tx_FreqInteger_r <= 11'b0; Tx_FreqFractional_r <= 23'b0;
        end
        else begin
            Tx_FreqInteger_r    <= Tx_FreqInteger;
            Tx_FreqFractional_r <= Tx_FreqFractional;
        end
    end  

    reg [15:0] Tx0_ATT_data_r,Tx1_ATT_data_r;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) begin
            Tx0_ATT_data_r <= 'b0;
            Tx1_ATT_data_r <= 'b0;            
        end
        else begin
            Tx0_ATT_data_r <= Tx0_ATT_data;
            Tx1_ATT_data_r <= Tx1_ATT_data;
        end
    end  


    reg [7:0] AD9361_spi_cnt;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            AD9361_spi_cnt <= 8'd0;
        else if(AD9361_Ctrl_Enable_r)
            AD9361_spi_cnt <= AD9361_spi_cnt + 1'd1;
        else 
            AD9361_spi_cnt <= 8'd0;
    end

    reg AD9361_spi_Valid;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            AD9361_spi_Valid <= 1'd0;
        else if(AD9361_spi_cnt == (SPI_CLK_US>>1))  
            AD9361_spi_Valid <= 1'd1;
        else 
            AD9361_spi_Valid <= 1'd0;
    end  


    reg [7:0] AD9361_att_cnt;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            AD9361_att_cnt <= 8'd0;
        else if(TX_ATT_Valid_r)
            AD9361_att_cnt <= AD9361_att_cnt + 1'd1;
        else 
            AD9361_att_cnt <= 8'd0;
    end

    reg AD9361_att_Valid;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            AD9361_att_Valid <= 1'd0;
        else if(AD9361_att_cnt == (SPI_CLK_US>>1))  
            AD9361_att_Valid <= 1'd1;
        else 
            AD9361_att_Valid <= 1'd0;
    end  


    reg [31:0] time_delay_cnt;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn)
            time_delay_cnt <= 32'd0;
        else if(time_delay_cnt >= AD9361_INIT_TIME)
            time_delay_cnt <= time_delay_cnt;
        else 
            time_delay_cnt <= time_delay_cnt + 1'd1;
    end

    reg ad9361_spiEn;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn) 
            ad9361_spiEn <= 1'd0;
        else if(time_delay_cnt == (AD9361_INIT_TIME>>1))
            ad9361_spiEn <= 1'd1;
        else 
            ad9361_spiEn <= 1'd0;
    end

    wire [18:0] AD9361_CFGDATA[17:0];
    assign AD9361_CFGDATA[0 ]  = {1'b1,10'h233,Rx_FreqFractional_r[7:0]};     
    assign AD9361_CFGDATA[1 ]  = {1'b1,10'h234,Rx_FreqFractional_r[15:8]};         //20'h27300
    assign AD9361_CFGDATA[2 ]  = {1'b1,10'h235,{1'b0,Rx_FreqFractional_r[22:16]}};         //20'h27400
    assign AD9361_CFGDATA[3 ]  = {1'b1,10'h232,{4'h0,1'b0,Rx_FreqInteger_r[10:8]}};         //20'h27500
    assign AD9361_CFGDATA[4 ]  = {1'b1,10'h231,Rx_FreqInteger_r[7:0]};         //20'h27200
    assign AD9361_CFGDATA[5 ]  = {1'b1,10'h005,{Tx_VcoDivider_r,Rx_VcoDivider_r}};         //20'h27150
    assign AD9361_CFGDATA[6 ]  = {1'b1,10'h273,Tx_FreqFractional_r[7:0]};      
    assign AD9361_CFGDATA[7 ]  = {1'b1,10'h274,Tx_FreqFractional_r[15:8]};         //20'h27300
    assign AD9361_CFGDATA[8 ]  = {1'b1,10'h275,{1'b0,Tx_FreqFractional_r[22:16]}};         //20'h27400
    assign AD9361_CFGDATA[9 ]  = {1'b1,10'h272,{4'h0,1'b0,Tx_FreqInteger_r[10:8]}};         //20'h27500
    assign AD9361_CFGDATA[10]  = {1'b1,10'h271,Tx_FreqInteger_r[7:0]};         //20'h27200
    assign AD9361_CFGDATA[11]  = {1'b1,10'h005,{Tx_VcoDivider_r,Rx_VcoDivider_r}};         //20'h27150
    assign AD9361_CFGDATA[12]  = {1'b0,10'h247,8'h00};
    assign AD9361_CFGDATA[13]  = {1'b0,10'h287,8'h00};

    assign AD9361_CFGDATA[14]  = {1'b1,10'h073,Tx0_ATT_data_r[7:0]};
    assign AD9361_CFGDATA[15]  = {1'b1,10'h074,Tx0_ATT_data_r[15:8]};    
    assign AD9361_CFGDATA[16]  = {1'b1,10'h075,Tx1_ATT_data_r[7:0]};
    assign AD9361_CFGDATA[17]  = {1'b1,10'h076,Tx1_ATT_data_r[15:8]}; 

    wire [11:0] index_bon=`NUM_ALL_REG;
    wire [11:0] index_spi_end = `INTERFACE_SPI_REG_END;
    wire [7:0] dout;
    wire dout_en; 
    wire spi_busy;
    wire [18:0] ad9361_data_reg;
    wire [11:0] index;

    reg [7:0] state; 
    reg [31:0] wait_cnt;
    reg [11:0] index_r;
    reg [18:0] spi_data_r;
    reg [31:0] delay_time;

    reg [7:0] din;
    reg din_en;
    reg wr_rdn;
    reg [9:0] addr;
    reg spi_ok;
    reg spi_end;
    reg [11:0] index_cnt;
    always @ (posedge clk or negedge rstn)begin
	    if(!rstn)begin
            state<=5'd0;
            delay_time <= 32'd0;
            wait_cnt<=32'd0;
            index_r <= 12'd0;
            spi_data_r <= 19'd0;
            spi_end <= 1'd0;
            index_cnt <= 12'd0;
        end
        else begin
            case(state)
                8'd0:       begin
                    if(ad9361_spiEn) 
                        state <= state + 1'd1;
                    else ;
                end
                8'd1:       begin
                    index_r <= index_r;
                    spi_data_r <= ad9361_data_reg;
                    wait_cnt<=32'd0;
                    state <= state + 1'd1;
                end
                8'd2:       begin
                    if(!spi_busy) begin
						wr_rdn <= spi_data_r[18];
						addr <= spi_data_r[17:8];
						din <= spi_data_r[7:0];
						din_en <= 1'b1;  
                        state <= state + 1'd1;                      
                    end
                    else ;
                end
                8'd3:       begin
					if(spi_busy)begin 
						din_en<=1'b0;
                        state <= state + 1'd1; 
					end 
                    else ;                   
                end
                8'd4:       begin
					if(!wr_rdn)begin 
						state <= state + 8'd1;
					end else begin 
						state <= state + 8'd2;
					end                    
                end
                8'd5:       begin
					wait_cnt<=32'd0;
					if(dout_en)begin
						case(index_r)
							`BBPLL_INDEX  			:begin if( dout[7]	) state<=5'd6;else state<=5'd0;end
							`RX_CPCAL_INDEX			:begin if( dout[7]	) state<=5'd6;else state<=5'd0;end
							`TX_CPCAL_INDEX			:begin if( dout[7]	) state<=5'd6;else state<=5'd0;end
							`RX_PLL_LOCK_INDEX		:begin if( dout[1]	) state<=5'd6;else state<=5'd0;end
							`TX_PLL_LOCK_INDEX		:begin if( dout[1]	) state<=5'd6;else state<=5'd0;end
							`RX_FIR_TUNE_INDEX		:begin if(!dout[7]	) state<=5'd6;else state<=5'd0;end
							`TX_FIR_TUNE_INDEX		:begin if(!dout[6]	) state<=5'd6;else state<=5'd0;end
							`BBDC_OFFSET_CAL_INDEX	:begin if(!dout[0]	) state<=5'd6;else state<=5'd0;end
							`MASKED_READ_INDEX		:begin if(!dout[1]	) state<=5'd6;else state<=5'd0;end
							`TX_QUAD_CAL_INDEX		:begin if(!dout[4]	) state<=5'd6;else state<=5'd0;end
							default 				:begin state<=8'd6;end
						endcase
					end
                    else ;                    
                end
                8'd6:       begin
                    if(index_r==index_bon) begin
						state<=8'd8;
						wait_cnt<=32'd0;                        
                    end
                    else if(index_r == 9) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;                        
                    end
                    else if(index_r== 25) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;                      
                    end
                    else if(index_r == 1623) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 1624) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 1625) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 1626) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 1628) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 2454) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 2461) begin
                        delay_time <= 32'd200_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 2521) begin
                        delay_time <= 32'd6_000_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 2529) begin
                        delay_time <= 32'd8_000_000;
                        state<=8'd7;            
                    end
                    else if(index_r == 2542) begin
                        delay_time <= 32'd2_000_000;
                        state<=8'd7;            
                    end                    
                    else if(index_r == 2566) begin
                        delay_time <= 32'd8_000_000;
                        state<=8'd7;            
                    end
                    else begin
                        delay_time <= 32'd10_000;
                        state<=8'd7;                                             
                    end
                end
                8'd7:       begin
					if(wait_cnt < delay_time) begin  //20ms
						wait_cnt<=wait_cnt+1'b1;
					end else begin 
						wait_cnt<=32'd0;
						index_r<=index_r+1'b1;
						state<=8'd1;
					end                      
                end
                8'd8:       begin
                    spi_ok <= 1'b1;
                    wait_cnt<=32'd0;
                    index_r <= 12'd0;
                    spi_data_r <= 19'd0;
                    index_cnt <= 0;                    
                    state<=8'd9;
                end
                8'd9:begin
                    if(AD9361_spi_Valid) begin
                        index_cnt <= 0;
                        state <= state + 1;
                    end
                    else if(AD9361_att_Valid) begin
                        index_cnt <= 14;
                        state <= state + 1;
                    end
                    else 
                        spi_end <= 1'd0;
                end
                8'd10:begin
                    index_cnt <= index_cnt;
                    spi_data_r <= AD9361_CFGDATA[index_cnt];
                    wait_cnt<=32'd0;
                    state <= state + 1'd1;                    
                end
                8'd11:begin
                    if(!spi_busy) begin
						wr_rdn <= spi_data_r[18];
						addr <= spi_data_r[17:8];
						din <= spi_data_r[7:0];
						din_en <= 1'b1;  
                        state <= state + 1'd1;                      
                    end
                    else ;                    
                end
                8'd12:begin
					if(spi_busy)begin 
						din_en<=1'b0;
                        state <= state + 1'd1; 
					end 
                    else ;                       
                end
                8'd13:begin
					if(!wr_rdn)begin 
						state <= state + 4'd1;
					end else begin 
						state <= state + 4'd2;
					end                      
                end
                8'd14:begin
					wait_cnt<=32'd0;
					if(dout_en)begin
						case(index_cnt)
							`RX_PLL_LOCK_INDEX_SPI		:begin if( dout[1]	) state<=8'd15;else state<=8'd0;end
							`TX_PLL_LOCK_INDEX_SPI		:begin if( dout[1]	) state<=8'd15;else state<=8'd0;end
							default 				:begin state<=8'd15;end
						endcase
					end
                    else ;                     
                end
                8'd15:begin
                    if(index_cnt == index_spi_end) begin
						state<=8'd17;
						wait_cnt<=32'd0;                            
                    end
                    else begin
                        delay_time <= 32'd10_000;
                        state<=8'd16;  
                    end                     
                end
                8'd16:begin
					if(wait_cnt < delay_time) begin  //20ms
						wait_cnt<=wait_cnt+1'b1;
					end else begin 
						wait_cnt<=32'd0;
						index_cnt<=index_cnt+1'b1;
						state<=8'd10;
					end                        
                end
                8'd17:begin
                    spi_end <= 1'b1;
                    wait_cnt<=32'd0;
                    index_cnt <= 12'd0;
                    spi_data_r <= 19'd0;                    
                    state<=8'd8;                    
                end
                default:    begin
                    state<=8'd0;
                    delay_time <= 32'd0;
                    wait_cnt<=32'd0;
                    index_r <= 12'd0;
                    index_cnt <= 12'd0;
                    spi_data_r <= 19'd0;
                end
            endcase
        end
    end
    assign index = index_r;

    ad9361_lut ad9361_lut(
        .index          ( index             ),
        .data           ( ad9361_data_reg   )
    );     

    ad9361_spi_if ad9361_modio(
        .rstn           ( rstn              ),
        .clk            ( clk               ),
        .addr           ( addr              ),
        .din            ( din               ),
        .din_en         ( din_en            ),
        .wr_rdn         ( wr_rdn            ),
        .dout           ( dout              ),
        .dout_en        ( dout_en           ),
        .spi_busy       ( spi_busy          ),
        .sclk           ( mdio_sclk         ),
        .sdi            ( mdio_sdi          ),
        .csb            ( mdio_csb          ),
        .sdo            ( mdio_sdo          )
    );

// ila_256Xbit ila_spi (
// 	.clk(clk), // input wire clk

// 	.probe0({
//         'b0,
//         // spiEn_vio_pos,
//         spi_ok,
//         index_r,
//         spi_data_r,
//         state,
//         spi_busy,
//         wr_rdn,
//         din_en,
//         dout_en,
//         wait_cnt,
//         dout,
//         din_en,
//         spi_end,
//         index_cnt,
//         AD9361_CFGDATA[16],
//         AD9361_att_Valid,
//         Tx1_ATT_data_r,
//         TX_ATT_Valid
//     }) // input wire [255:0] probe0
// );
    
endmodule
