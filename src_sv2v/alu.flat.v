module alu (
	src1_i,
	src2_i,
	alu_op_i,
	res_o,
	z_o,
	s_o,
	ovfl_o,
	carry_o
);
	reg _sv2v_0;
	parameter signed [31:0] WIDTH = 32;
	input wire [WIDTH - 1:0] src1_i;
	input wire [WIDTH - 1:0] src2_i;
	input wire [3:0] alu_op_i;
	output reg [WIDTH - 1:0] res_o;
	output reg z_o;
	output reg s_o;
	output reg ovfl_o;
	output reg carry_o;
	wire [WIDTH:0] sum_res;
	wire [WIDTH:0] sub_res;
	wire [4:0] shamt;
	assign shamt = src2_i[4:0];
	assign sum_res = {1'b0, src1_i} + {1'b0, src2_i};
	assign sub_res = {1'b0, src1_i} - {1'b0, src2_i};
	wire sign_src1 = src1_i[WIDTH - 1];
	wire sign_src2 = src2_i[WIDTH - 1];
	wire sign_sum = sum_res[WIDTH - 1];
	wire sign_sub = sub_res[WIDTH - 1];
	wire [WIDTH - 1:0] sum_trunc = sum_res[WIDTH - 1:0];
	wire [WIDTH - 1:0] sub_trunc = sub_res[WIDTH - 1:0];
	wire carry_add = sum_res[WIDTH];
	wire carry_sub = sub_res[WIDTH];
	wire slt_bit = sign_sub ^ ((sign_src1 != sign_src2) & (sign_sub != sign_src1));
	wire sltu_bit = carry_sub;
	wire [WIDTH - 1:0] slt_res = {{WIDTH - 1 {1'b0}}, slt_bit};
	wire [WIDTH - 1:0] sltu_res = {{WIDTH - 1 {1'b0}}, sltu_bit};
	always @(*) begin
		if (_sv2v_0)
			;
		res_o = 1'sb0;
		carry_o = 1'b0;
		ovfl_o = 1'b0;
		case (alu_op_i)
			4'd0: begin
				res_o = sum_trunc;
				carry_o = carry_add;
				ovfl_o = (sign_src1 == sign_src2) & (sign_sum != sign_src1);
			end
			4'd1: begin
				res_o = sub_trunc;
				carry_o = ~carry_sub;
				ovfl_o = (sign_src1 != sign_src2) & (sign_sub != sign_src1);
			end
			4'd3: res_o = slt_res;
			4'd4: res_o = sltu_res;
			4'd2: res_o = src1_i << shamt;
			4'd6: res_o = src1_i >> shamt;
			4'd7: res_o = $signed(src1_i) >>> shamt;
			4'd5: res_o = src1_i ^ src2_i;
			4'd8: res_o = src1_i | src2_i;
			4'd9: res_o = src1_i & src2_i;
			default: res_o = src2_i;
		endcase
		z_o = res_o == {WIDTH {1'sb0}};
		s_o = res_o[WIDTH - 1];
	end
	initial _sv2v_0 = 0;
endmodule
