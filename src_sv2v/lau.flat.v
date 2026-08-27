module lau (
	mem_data_i,
	adrs_1_i,
	adrs_0_i,
	funct3_i,
	aligned_data_o
);
	reg _sv2v_0;
	input wire [31:0] mem_data_i;
	input wire adrs_1_i;
	input wire adrs_0_i;
	input wire [2:0] funct3_i;
	output reg [31:0] aligned_data_o;
	wire [31:0] stage1_mux_out;
	wire [31:0] stage2_mux_out;
	assign stage1_mux_out = (adrs_1_i ? mem_data_i >> 16 : mem_data_i);
	assign stage2_mux_out = (adrs_0_i ? stage1_mux_out >> 8 : stage1_mux_out);
	wire [7:0] s2_byte = stage2_mux_out[7:0];
	wire s2_byte_sign = stage2_mux_out[7];
	wire [15:0] s2_hw = stage2_mux_out[15:0];
	wire s2_hw_sign = stage2_mux_out[15];
	always @(*) begin
		if (_sv2v_0)
			;
		aligned_data_o = 1'sb0;
		case (funct3_i)
			3'b000: aligned_data_o = {{24 {s2_byte_sign}}, s2_byte};
			3'b001: aligned_data_o = {{16 {s2_hw_sign}}, s2_hw};
			3'b010: aligned_data_o = stage2_mux_out;
			3'b100: aligned_data_o = {24'b000000000000000000000000, s2_byte};
			3'b101: aligned_data_o = {16'b0000000000000000, s2_hw};
			default: aligned_data_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
