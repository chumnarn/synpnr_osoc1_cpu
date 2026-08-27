module sau (
	mem_we_i,
	rs2_val_i,
	adrs_1_i,
	adrs_0_i,
	f3_i,
	wdata_o,
	strobe_o
);
	reg _sv2v_0;
	input wire mem_we_i;
	input wire [31:0] rs2_val_i;
	input wire adrs_1_i;
	input wire adrs_0_i;
	input wire [2:0] f3_i;
	output reg [31:0] wdata_o;
	output wire [3:0] strobe_o;
	reg [3:0] raw_strobe;
	wire [7:0] rs2_byte = rs2_val_i[7:0];
	wire [15:0] rs2_hw = rs2_val_i[15:0];
	always @(*) begin
		if (_sv2v_0)
			;
		wdata_o = rs2_val_i;
		raw_strobe = 4'b0000;
		case (f3_i)
			3'b000: begin
				wdata_o = {4 {rs2_byte}};
				raw_strobe = 4'b0001 << {adrs_1_i, adrs_0_i};
			end
			3'b001: begin
				wdata_o = {2 {rs2_hw}};
				raw_strobe = (adrs_1_i ? 4'b1100 : 4'b0011);
			end
			3'b010: begin
				wdata_o = rs2_val_i;
				raw_strobe = 4'b1111;
			end
			default: begin
				wdata_o = rs2_val_i;
				raw_strobe = 4'b0000;
			end
		endcase
	end
	assign strobe_o = (mem_we_i ? raw_strobe : 4'b0000);
	initial _sv2v_0 = 0;
endmodule
