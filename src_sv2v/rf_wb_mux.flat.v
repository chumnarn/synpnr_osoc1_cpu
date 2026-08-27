module rf_wb_mux (
	alu_res_i,
	lau_res_i,
	pc_plus_4_i,
	d2r_sel_i,
	rf_wd_o
);
	reg _sv2v_0;
	parameter signed [31:0] WIDTH = 32;
	input wire [WIDTH - 1:0] alu_res_i;
	input wire [WIDTH - 1:0] lau_res_i;
	input wire [WIDTH - 1:0] pc_plus_4_i;
	input wire [1:0] d2r_sel_i;
	output reg [WIDTH - 1:0] rf_wd_o;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (d2r_sel_i)
			2'b00: rf_wd_o = alu_res_i;
			2'b01: rf_wd_o = lau_res_i;
			2'b10: rf_wd_o = pc_plus_4_i;
			default: rf_wd_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
