module ctrl (
	opcode_i,
	funct3_i,
	funct7_i,
	is_cond_branch_o,
	is_jal_o,
	is_jalr_o,
	imm_src_o,
	alu_src1_ctrl_o,
	alu_src2_ctrl_o,
	alu_ctrl_o,
	datamem_re_o,
	datamem_we_o,
	dataMem2Reg_o,
	regfile_we_o
);
	reg _sv2v_0;
	input wire [6:0] opcode_i;
	input wire [2:0] funct3_i;
	input wire [6:0] funct7_i;
	output reg is_cond_branch_o;
	output reg is_jal_o;
	output reg is_jalr_o;
	output reg [2:0] imm_src_o;
	output reg [1:0] alu_src1_ctrl_o;
	output reg alu_src2_ctrl_o;
	output reg [3:0] alu_ctrl_o;
	output reg datamem_re_o;
	output reg datamem_we_o;
	output reg [1:0] dataMem2Reg_o;
	output reg regfile_we_o;
	wire [6:0] op;
	assign op = opcode_i & 7'h7f;
	always @(*) begin
		if (_sv2v_0)
			;
		is_cond_branch_o = 1'b0;
		is_jal_o = 1'b0;
		is_jalr_o = 1'b0;
		imm_src_o = 3'd0;
		alu_src1_ctrl_o = 2'd1;
		alu_src2_ctrl_o = 1'b0;
		alu_ctrl_o = 4'd0;
		datamem_re_o = 1'b0;
		datamem_we_o = 1'b0;
		dataMem2Reg_o = 2'd0;
		regfile_we_o = 1'b0;
		case (op)
			7'd51: begin
				regfile_we_o = 1'b1;
				case (funct3_i)
					3'd0: alu_ctrl_o = (funct7_i == 7'd32 ? 4'd1 : 4'd0);
					3'd1: alu_ctrl_o = 4'd2;
					3'd2: alu_ctrl_o = 4'd3;
					3'd3: alu_ctrl_o = 4'd4;
					3'd4: alu_ctrl_o = 4'd5;
					3'd5: alu_ctrl_o = (funct7_i == 7'd32 ? 4'd7 : 4'd6);
					3'd6: alu_ctrl_o = 4'd8;
					3'd7: alu_ctrl_o = 4'd9;
				endcase
			end
			7'd19: begin
				regfile_we_o = 1'b1;
				alu_src2_ctrl_o = 1'b1;
				case (funct3_i)
					3'd0: alu_ctrl_o = 4'd0;
					3'd1: alu_ctrl_o = 4'd2;
					3'd2: alu_ctrl_o = 4'd3;
					3'd3: alu_ctrl_o = 4'd4;
					3'd4: alu_ctrl_o = 4'd5;
					3'd5: alu_ctrl_o = (funct7_i == 7'd32 ? 4'd7 : 4'd6);
					3'd6: alu_ctrl_o = 4'd8;
					3'd7: alu_ctrl_o = 4'd9;
				endcase
			end
			7'd3: begin
				regfile_we_o = 1'b1;
				alu_src2_ctrl_o = 1'b1;
				datamem_re_o = 1'b1;
				dataMem2Reg_o = 2'd1;
			end
			7'd35: begin
				imm_src_o = 3'd1;
				alu_src2_ctrl_o = 1'b1;
				datamem_we_o = 1'b1;
			end
			7'd99: begin
				is_cond_branch_o = 1'b1;
				imm_src_o = 3'd2;
				alu_ctrl_o = 4'd1;
			end
			7'd55: begin
				regfile_we_o = 1'b1;
				imm_src_o = 3'd3;
				alu_src1_ctrl_o = 2'd2;
				alu_src2_ctrl_o = 1'b1;
			end
			7'd23: begin
				regfile_we_o = 1'b1;
				imm_src_o = 3'd3;
				alu_src1_ctrl_o = 2'd0;
				alu_src2_ctrl_o = 1'b1;
			end
			7'd103: begin
				is_jalr_o = 1'b1;
				regfile_we_o = 1'b1;
				alu_src1_ctrl_o = 2'd1;
				alu_src2_ctrl_o = 1'b1;
				alu_ctrl_o = 4'd0;
				dataMem2Reg_o = 2'd2;
			end
			7'd111: begin
				is_jal_o = 1'b1;
				regfile_we_o = 1'b1;
				imm_src_o = 3'd4;
				dataMem2Reg_o = 2'd2;
			end
			default:
				;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
