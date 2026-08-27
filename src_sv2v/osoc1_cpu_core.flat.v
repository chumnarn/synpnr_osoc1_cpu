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
module lau (
	mem_data_i,
	adrs_1_i,
	adrs_0_i,
	funct3_i,
	aligned_data_o
);
	reg _sv2v_0;
	input wire [31:0] mem_data_i;
	input wire adrs_1_i;
	input wire adrs_0_i;
	input wire [2:0] funct3_i;
	output reg [31:0] aligned_data_o;
	wire [31:0] stage1_mux_out;
	wire [31:0] stage2_mux_out;
	assign stage1_mux_out = (adrs_1_i ? mem_data_i >> 16 : mem_data_i);
	assign stage2_mux_out = (adrs_0_i ? stage1_mux_out >> 8 : stage1_mux_out);
	wire [7:0] s2_byte = stage2_mux_out[7:0];
	wire s2_byte_sign = stage2_mux_out[7];
	wire [15:0] s2_hw = stage2_mux_out[15:0];
	wire s2_hw_sign = stage2_mux_out[15];
	always @(*) begin
		if (_sv2v_0)
			;
		aligned_data_o = 1'sb0;
		case (funct3_i)
			3'b000: aligned_data_o = {{24 {s2_byte_sign}}, s2_byte};
			3'b001: aligned_data_o = {{16 {s2_hw_sign}}, s2_hw};
			3'b010: aligned_data_o = stage2_mux_out;
			3'b100: aligned_data_o = {24'b000000000000000000000000, s2_byte};
			3'b101: aligned_data_o = {16'b0000000000000000, s2_hw};
			default: aligned_data_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
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
module osoc1_cpu_core (
	clk_i,
	rst_ni,
	pc_o,
	instr_i,
	dmem_we_o,
	dmem_addr_o,
	dmem_wdata_o,
	dmem_rdata_i
);
	input wire clk_i;
	input wire rst_ni;
	output wire [31:0] pc_o;
	input wire [31:0] instr_i;
	output wire [3:0] dmem_we_o;
	output wire [31:0] dmem_addr_o;
	output wire [31:0] dmem_wdata_o;
	input wire [31:0] dmem_rdata_i;
	wire [31:0] pc_curr;
	wire [31:0] pc_next;
	wire [31:0] pc_plus_4;
	assign pc_o = pc_curr;
	wire [6:0] op;
	wire [4:0] rd;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [2:0] f3;
	wire [6:0] f7;
	wire [31:0] imm;
	wire [2:0] imm_src;
	wire [1:0] s1_sel;
	wire [1:0] pc_src;
	wire is_br;
	wire is_jal;
	wire is_jalr;
	wire s2_sel;
	wire mem_re;
	wire rf_we;
	wire master_mem_we;
	wire [3:0] alu_op;
	wire [1:0] d2r;
	wire [31:0] rs1_val;
	wire [31:0] rs2_val;
	wire [31:0] rf_wd;
	wire [31:0] alu_a;
	wire [31:0] alu_b;
	wire [31:0] alu_res;
	wire z_flag;
	wire s_flag;
	wire ov_flag;
	wire carry_flag;
	wire [3:0] flags;
	wire [31:0] aligned_wdata;
	wire [31:0] lau_res;
	wire adrs_1;
	wire adrs_0;
	pc_reg u_pc_reg(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.pc_d_i(pc_next),
		.pc_q_o(pc_curr)
	);
	pc_plus_4 u_pc_plus_4(
		.pc_curr_i(pc_curr),
		.pc_plus_4_o(pc_plus_4)
	);
	decoder u_decoder(
		.instr_i(instr_i),
		.op_o(op),
		.rd_o(rd),
		.rs1_o(rs1),
		.rs2_o(rs2),
		.f3_o(f3),
		.f7_o(f7),
		.imm_o(imm)
	);
	ctrl u_ctrl(
		.opcode_i(op),
		.funct3_i(f3),
		.funct7_i(f7),
		.is_cond_branch_o(is_br),
		.is_jal_o(is_jal),
		.is_jalr_o(is_jalr),
		.imm_src_o(imm_src),
		.alu_src1_ctrl_o(s1_sel),
		.alu_src2_ctrl_o(s2_sel),
		.alu_ctrl_o(alu_op),
		.datamem_re_o(mem_re),
		.datamem_we_o(master_mem_we),
		.dataMem2Reg_o(d2r),
		.regfile_we_o(rf_we)
	);
	reg_file u_reg_file(
		.clk_i(clk_i),
		.we_i(rf_we),
		.rs1_i(rs1),
		.rs2_i(rs2),
		.rd_i(rd),
		.wd_i(rf_wd),
		.rd1_o(rs1_val),
		.rd2_o(rs2_val)
	);
	alu_in_muxes u_alu_muxes(
		.pc_curr_i(pc_curr),
		.rs1_val_i(rs1_val),
		.rs2_val_i(rs2_val),
		.imm_i(imm),
		.s1_sel_i(s1_sel),
		.s2_sel_i(s2_sel),
		.alu_a_o(alu_a),
		.alu_b_o(alu_b)
	);
	alu u_alu(
		.src1_i(alu_a),
		.src2_i(alu_b),
		.alu_op_i(alu_op),
		.res_o(alu_res),
		.z_o(z_flag),
		.s_o(s_flag),
		.ovfl_o(ov_flag),
		.carry_o(carry_flag)
	);
	assign flags = {z_flag, s_flag, ov_flag, carry_flag};
	assign adrs_1 = alu_res[1];
	assign adrs_0 = alu_res[0];
	assign dmem_addr_o = alu_res;
	sau u_sau(
		.mem_we_i(master_mem_we),
		.rs2_val_i(rs2_val),
		.adrs_1_i(adrs_1),
		.adrs_0_i(adrs_0),
		.f3_i(f3),
		.wdata_o(aligned_wdata),
		.strobe_o(dmem_we_o)
	);
	assign dmem_wdata_o = aligned_wdata;
	lau u_lau(
		.mem_data_i(dmem_rdata_i),
		.adrs_1_i(adrs_1),
		.adrs_0_i(adrs_0),
		.funct3_i(f3),
		.aligned_data_o(lau_res)
	);
	rf_wb_mux u_rf_wb_mux(
		.alu_res_i(alu_res),
		.lau_res_i(lau_res),
		.pc_plus_4_i(pc_plus_4),
		.d2r_sel_i(d2r),
		.rf_wd_o(rf_wd)
	);
	bcu u_bcu(
		.f3_i(f3),
		.flags_i(flags),
		.is_cond_branch_i(is_br),
		.is_jal_i(is_jal),
		.is_jalr_i(is_jalr),
		.pc_src_o(pc_src)
	);
	next_pc_logic u_next_pc_logic(
		.pc_curr_i(pc_curr),
		.pc_plus_4_i(pc_plus_4),
		.imm_i(imm),
		.alu_res_i(alu_res),
		.pc_src_i(pc_src),
		.pc_next_o(pc_next)
	);
endmodule
module pc_plus_4 (
	pc_curr_i,
	pc_plus_4_o
);
	input wire [31:0] pc_curr_i;
	output wire [31:0] pc_plus_4_o;
	assign pc_plus_4_o = pc_curr_i + 32'd4;
endmodule
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
module sau (
	mem_we_i,
	rs2_val_i,
	adrs_1_i,
	adrs_0_i,
	f3_i,
	wdata_o,
	strobe_o
);
	reg _sv2v_0;
	input wire mem_we_i;
	input wire [31:0] rs2_val_i;
	input wire adrs_1_i;
	input wire adrs_0_i;
	input wire [2:0] f3_i;
	output reg [31:0] wdata_o;
	output wire [3:0] strobe_o;
	reg [3:0] raw_strobe;
	wire [7:0] rs2_byte = rs2_val_i[7:0];
	wire [15:0] rs2_hw = rs2_val_i[15:0];
	always @(*) begin
		if (_sv2v_0)
			;
		wdata_o = rs2_val_i;
		raw_strobe = 4'b0000;
		case (f3_i)
			3'b000: begin
				wdata_o = {4 {rs2_byte}};
				raw_strobe = 4'b0001 << {adrs_1_i, adrs_0_i};
			end
			3'b001: begin
				wdata_o = {2 {rs2_hw}};
				raw_strobe = (adrs_1_i ? 4'b1100 : 4'b0011);
			end
			3'b010: begin
				wdata_o = rs2_val_i;
				raw_strobe = 4'b1111;
			end
			default: begin
				wdata_o = rs2_val_i;
				raw_strobe = 4'b0000;
			end
		endcase
	end
	assign strobe_o = (mem_we_i ? raw_strobe : 4'b0000);
	initial _sv2v_0 = 0;
endmodule
