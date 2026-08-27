module pc_reg (
	clk_i,
	rst_ni,
	pc_d_i,
	pc_q_o
);
	input wire clk_i;
	input wire rst_ni;
	input wire [31:0] pc_d_i;
	output reg [31:0] pc_q_o;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			pc_q_o <= 32'h00000000;
		else
			pc_q_o <= pc_d_i;
endmodule
