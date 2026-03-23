module ad9361_spi_if(
input rstn,
input clk,

input [9:0] addr,
input [7:0] din,
input din_en,
input wr_rdn,
output reg [7:0] dout,
output reg dout_en,
output reg spi_busy,

output sclk,
output reg sdi,
output reg csb,
input sdo
);

reg [4:0] state;
reg [23:0] cmd;
reg [4:0] shift_reg;
reg rd_en;
assign sclk=clk;
always @ (posedge clk or negedge rstn)
if(!rstn)
	begin
		sdi<=1'b0;
		csb<=1'b1;
		cmd<=24'd0;
		spi_busy<=1'b0;
		state<=5'd0;
		shift_reg<=5'd0;
		rd_en<=1'b0;
	end
else
	begin
		case(state)
			5'd0:
			begin
				if(din_en)
					begin
						cmd<={wr_rdn,3'd0,2'd0,addr,din};
						rd_en<=~wr_rdn;
						spi_busy<=1'b1;
						state<=5'd1;
					end
				else
					begin end
			end
			5'd1:
			begin
				csb<=1'b1;state<=5'd2;
			end
			5'd2:
			begin
				if(shift_reg<=5'd23)
					begin
						csb<=1'b0;sdi<=cmd[23];cmd<=cmd<<1;shift_reg<=shift_reg+1'b1;state<=5'd2;
					end
				else
					begin
						shift_reg<=5'd0;sdi<=1'b0;csb<=1'b1;state<=5'd4;
					end
				end
			5'd3:
			begin
				state<=5'd4;
			end
			5'd4:
			begin
				if(!din_en)
					begin spi_busy<=1'b0;state<=5'd0;end
				else
					begin spi_busy<=1'b1;state<=5'd4;end
			end
		endcase
	end
reg [7:0] dout_reg;
reg dout_en_reg;
always @ (negedge clk or negedge rstn)
if(!rstn)
	begin
		dout_reg<=8'd0;
		dout_en_reg<=1'b0;
	end
else if(rd_en)
	begin
		case(shift_reg)
			5'd17:begin dout_reg[7]<=sdo;dout_en_reg<=1'b0;end
			5'd18:begin dout_reg[6]<=sdo;dout_en_reg<=1'b0;end
			5'd19:begin dout_reg[5]<=sdo;dout_en_reg<=1'b0;end
			5'd20:begin dout_reg[4]<=sdo;dout_en_reg<=1'b0;end
			5'd21:begin dout_reg[3]<=sdo;dout_en_reg<=1'b0;end
			5'd22:begin dout_reg[2]<=sdo;dout_en_reg<=1'b0;end
			5'd23:begin dout_reg[1]<=sdo;dout_en_reg<=1'b0;end
			5'd24:begin dout_reg[0]<=sdo;dout_en_reg<=1'b1;end
			default:begin dout_reg<=8'd0;dout_en_reg<=1'b0;end
		endcase
	end
always @ (posedge clk or negedge rstn)
if(!rstn)
	begin
		dout<=8'd0;
		dout_en<=1'b0;
	end
else
	begin
		dout<=dout_reg;
		dout_en<=dout_en_reg;
	end
endmodule
