module reg_file (
	clk_i,
	we_i,
	rs1_i,
	rs2_i,
	rd_i,
	wd_i,
	rd1_o,
	rd2_o
);
	input wire clk_i;
	input wire we_i;
	input wire [4:0] rs1_i;
	input wire [4:0] rs2_i;
	input wire [4:0] rd_i;
	input wire [31:0] wd_i;
	output wire [31:0] rd1_o;
	output wire [31:0] rd2_o;
	reg [31:0] registers [31:0];
	assign rd1_o = (rs1_i == 5'd0 ? 32'h00000000 : registers[rs1_i]);
	assign rd2_o = (rs2_i == 5'd0 ? 32'h00000000 : registers[rs2_i]);
	always @(posedge clk_i)
		if (we_i && (rd_i != 5'd0))
			registers[rd_i] <= wd_i;
endmodule
