module alu_in_muxes (
	pc_curr_i,
	rs1_val_i,
	rs2_val_i,
	imm_i,
	s1_sel_i,
	s2_sel_i,
	alu_a_o,
	alu_b_o
);
	reg _sv2v_0;
	parameter signed [31:0] WIDTH = 32;
	input wire [WIDTH - 1:0] pc_curr_i;
	input wire [WIDTH - 1:0] rs1_val_i;
	input wire [WIDTH - 1:0] rs2_val_i;
	input wire [WIDTH - 1:0] imm_i;
	input wire [1:0] s1_sel_i;
	input wire s2_sel_i;
	output reg [WIDTH - 1:0] alu_a_o;
	output wire [WIDTH - 1:0] alu_b_o;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (s1_sel_i)
			2'b00: alu_a_o = pc_curr_i;
			2'b01: alu_a_o = rs1_val_i;
			2'b10: alu_a_o = 1'sb0;
			default: alu_a_o = 1'sb0;
		endcase
	end
	assign alu_b_o = (s2_sel_i == 1'b1 ? imm_i : rs2_val_i);
	initial _sv2v_0 = 0;
endmodule
