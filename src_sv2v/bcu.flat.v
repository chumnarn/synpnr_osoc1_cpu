module bcu (
	f3_i,
	flags_i,
	is_cond_branch_i,
	is_jal_i,
	is_jalr_i,
	pc_src_o
);
	reg _sv2v_0;
	input wire [2:0] f3_i;
	input wire [3:0] flags_i;
	input wire is_cond_branch_i;
	input wire is_jal_i;
	input wire is_jalr_i;
	output reg [1:0] pc_src_o;
	wire z_i;
	wire s_i;
	wire o_i;
	wire c_i;
	reg take_branch;
	assign {z_i, s_i, o_i, c_i} = flags_i;
	always @(*) begin
		if (_sv2v_0)
			;
		take_branch = 1'b0;
		if (is_cond_branch_i)
			case (f3_i)
				3'b000: take_branch = z_i == 1'b1;
				3'b001: take_branch = z_i == 1'b0;
				3'b100: take_branch = s_i != o_i;
				3'b101: take_branch = s_i == o_i;
				3'b110: take_branch = c_i == 1'b0;
				3'b111: take_branch = c_i == 1'b1;
				default: take_branch = 1'b0;
			endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (is_jalr_i)
			pc_src_o = 2'b10;
		else if (is_jal_i || take_branch)
			pc_src_o = 2'b01;
		else
			pc_src_o = 2'b00;
	end
	initial _sv2v_0 = 0;
endmodule
