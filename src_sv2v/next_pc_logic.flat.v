module next_pc_logic (
	pc_curr_i,
	pc_plus_4_i,
	imm_i,
	alu_res_i,
	pc_src_i,
	pc_next_o
);
	reg _sv2v_0;
	input wire [31:0] pc_curr_i;
	input wire [31:0] pc_plus_4_i;
	input wire [31:0] imm_i;
	input wire [31:0] alu_res_i;
	input wire [1:0] pc_src_i;
	output reg [31:0] pc_next_o;
	wire [31:0] branch_target;
	wire [31:0] jalr_target;
	assign branch_target = pc_curr_i + imm_i;
	assign jalr_target = alu_res_i & 32'hfffffffe;
	always @(*) begin
		if (_sv2v_0)
			;
		case (pc_src_i)
			2'b10: pc_next_o = jalr_target;
			2'b01: pc_next_o = branch_target;
			2'b00: pc_next_o = pc_plus_4_i;
			default: pc_next_o = pc_plus_4_i;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
