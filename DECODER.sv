typedef enum logic [3:0] {
    add = 4'b0000,
    sub = 4'b0001,
    sll = 4'b0010,
    slt = 4'b0100,
    sltu = 4'b0110,
    xor = 4'b1000,
    srl = 4'b1010,
    sra = 4'b1011,
    or_alu = 4'b1100,
    and_alu = 4'b1110,
    pass_b = 4'b1111
} alu_opcode_t;

typedef enum logic [6:0] {
    R_TYPE          = 7'b0110011,
    I_TYPE_ALU      = 7'b0010011,
    LUI             = 7'b0110111, //U type
    AUIPC           = 7'b0010111, //U type
    I_TYPE_LOADS    = 7'b0000011,
    S_TYPE          = 7'b0100011,
    SB_TYPE         = 7'b1100011,
    UJ_TYPE         = 7'b1101111, //JAL
    I_TYPE_CONTROL  = 7'b1100111 //JALR
} instruction_opcode;

typedef enum logic [2:0] {
    ADD_SUB     = 3'b000,
    SLT         = 3'b010,
    SLTU        = 3'b011,
    XOR         = 3'b100,
    OR          = 3'b110,
    AND         = 3'b111,
    SLL         = 3'b001,
    SRL_SRA   = 3'b101
} instruction_func3;


module DECODER #(
    parameter BW = 32,
    parameter AW = clog2(BW)
    )(
    input  logic [BW-1:0] data_in,
    output logic [BW-1:0] imm,
    output  logic [3:0] alu_opcode,
    output logic [AW-1:0] rs1,
    output logic [AW-1:0] rs2,
    output logic [AW-1:0] rd
);
    always_comb begin
        imm = '0;
        alu_opcode = '0;
        rs1 = '0;
        rs2 = '0;
        rd = '0;
        case (data_in[6:0])
            R_TYPE: begin
                rs1 = data_in[19:15];
                rs2 = data_in[24:20];
                rd = data_in[11:7];
                case (data_in[14:12]) //func3
                    ADD_SUB: begin
                        if (data_in[30]==1'b0)
                            alu_opcode = add;
                        else
                            alu_opcode = sub;
                    end
                    SLT: alu_opcode = slt;
                    SLTU: alu_opcode = sltu;
                    XOR: alu_opcode = xor;
                    OR: alu_opcode = or_alu;
                    AND: alu_opcode = and_alu;
                    SLL: alu_opcode = sll;
                    SRL_SRA: begin
                        if (data_in[30]==1'b0)
                            alu_opcode = srl;
                        else
                            alu_opcode = sra;
                    end
                endcase
            end
            I_TYPE_ALU: begin
                rs1 = data_in[19:15];
                rd = data_in[11:7];
                imm = data_in[31:20]; //TODO: add the bits to imm value
                case (data_in[14:12]) //func3
                    ADD_SUB: alu_opcode = add; //only exist ADDI
                    SLT: alu_opcode = slt;
                    SLTU: alu_opcode = sltu;
                    XOR: alu_opcode = xor;
                    OR: alu_opcode = or_alu;
                    AND: alu_opcode = and_alu;
                    SLL: alu_opcode = sll;
                    SRL_SRA: begin
                        if (data_in[30]==1'b0)
                            alu_opcode = srl;
                        else
                            alu_opcode = sra;
                    end
                endcase
            end
            //U-TYPE
            LUI: begin
                alu_opcode = pass_b;
                imm = data_in[31:12] << 12; //TODO: check this line
                rd = data_in[11:7];
            end
            AUIPC: begin
                alu_opcode = add;
                imm = data_in[31:12] << 12; //TODO: check this line
                rd = data_in[11:7];
            end
            I_TYPE_LOADS: begin
                rs1 = data_in[19:15];
                rd = data_in[11:7];
                imm = data_in[31:20]; //TODO: add the bits to imm value
                case (data_in[14:12])
                    3'b000: //LB
                    3'b001: //LH
                    3'b010: //LW
                    3'b100: //LBU
                    3'b101: //LHU
                endcase
            end
            S_TYPE: begin

            end
            SB_TYPE: begin
            end
            UJ_TYPE: begin
            end
            I_TYPE_CONTROL: begin
            end

        endcase
    end
endmodule