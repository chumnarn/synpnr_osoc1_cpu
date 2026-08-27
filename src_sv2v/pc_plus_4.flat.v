module pc_plus_4 (
	pc_curr_i,
	pc_plus_4_o
);
	input wire [31:0] pc_curr_i;
	output wire [31:0] pc_plus_4_o;
	assign pc_plus_4_o = pc_curr_i + 32'd4;
endmodule
