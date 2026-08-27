module decoder (
	instr_i,
	op_o,
	rd_o,
	f3_o,
	rs1_o,
	rs2_o,
	f7_o,
	imm_o
);
	reg _sv2v_0;
	input wire [31:0] instr_i;
	output wire [6:0] op_o;
	output wire [4:0] rd_o;
	output wire [2:0] f3_o;
	output wire [4:0] rs1_o;
	output wire [4:0] rs2_o;
	output wire [6:0] f7_o;
	output reg [31:0] imm_o;
	assign op_o = instr_i[6:0];
	assign rd_o = instr_i[11:7];
	assign f3_o = instr_i[14:12];
	assign rs1_o = instr_i[19:15];
	assign rs2_o = instr_i[24:20];
	assign f7_o = instr_i[31:25];
	wire i31 = instr_i[31];
	wire [11:0] i31_20 = instr_i[31:20];
	wire [6:0] i31_25 = instr_i[31:25];
	wire [4:0] i11_7 = instr_i[11:7];
	wire i7 = instr_i[7];
	wire [5:0] i30_25 = instr_i[30:25];
	wire [3:0] i11_8 = instr_i[11:8];
	wire [19:0] i31_12 = instr_i[31:12];
	wire [7:0] i19_12 = instr_i[19:12];
	wire i20 = instr_i[20];
	wire [9:0] i30_21 = instr_i[30:21];
	always @(*) begin
		if (_sv2v_0)
			;
		imm_o = 1'sb0;
		case (op_o)
			7'h33: imm_o = 1'sb0;
			7'h13, 7'h03, 7'h67: imm_o = {{20 {i31}}, i31_20};
			7'h23: imm_o = {{20 {i31}}, i31_25, i11_7};
			7'h63: imm_o = {{19 {i31}}, i31, i7, i30_25, i11_8, 1'b0};
			7'h37, 7'h17: imm_o = {i31_12, 12'b000000000000};
			7'h6f: imm_o = {{11 {i31}}, i31, i19_12, i20, i30_21, 1'b0};
			default: imm_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
