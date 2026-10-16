module moduleName (
    //from controller
    input logic IRload,
    input logic RFdin,
    input logic RFwe_n,
    input logic RFce,
    input logic ALUsrcB,
    input logic PCsrc,
    input logic PCload,
    input logic ADDRsrc,
    input logic RAMwrite,

    //to controller
    output logic instrID,
    output logic zeroFlag,
    //output logic zeroTarget,

    //from Memory System
    input logic[31:0]   data_in,

    //to Memory System
    output logic[31:0] addr,
    output logic[31:0] data_out,
    output logic[3:0]   write_en,
);
    logic[31:0] IRout,
    logic[31:0] ALUinb, 
    logic[3:0]  ALUopcode,
    logic[31:0] ALUout,
    logic[31:0] PCin,
    logic[31:0] PCout,
    logic[31:0] RFout1,
    logic[31:0] RFout2,
    logic[31:0] RFdin,
    logic[31:0] imm,
    logic[31:0] PC_plus4,
    logic[31:0] PC_plusImm,
    logic[1:0]  LoadControlOut, 
    logic[1:0]  LoadControlOffset,



    RegisterFile #(.BW(BW)
    )RF(
        .read_addr_1(IRout[19:15]),
        .read_addr_2(IRout[24:20]),
        .write_addr(IRout[11:7]),
        .data_in(RFdin),
        .clk(),
        .rst_n(),
        .write_en_n(RFwe_n),
        .chip_en(RFce),
        .data_out_1(RFout1),
        .data_out_2(RFout2)
    );

    ALU#(.BW(BW)
    )ALU(
        .in_a(RFout1),
        .in_b(ALUinb),
        .out(ALUout),
        .flags(), //creo q hay q hacer una señal de 3 bits pero luego pasar solo un bit a zeroFlag
        .opcode(ALUopcode)
    );

    //TODO hay que quitar los outputs de rs1,rs2 y rd. Falta crear instrID
    DECODER#(.BW(BW)
    )DECODER(
        .data_in(),
        .imm(),
        .alu_opcode(),
        .rs1(),
        .rs2(),
        .rd(),
        .instr_id()
    );

    LoadControl LoadControl(
    .datain(data_in),
    .func3(IRout[14:12]),
    .offset(LoadControlOffset),
    .dataout(LoadControlOut)
    );


    StoreControl StoreControl (
        .datain(RFout2),
        .offset(ALUout[1:0]),
        .func3(IRout[14:12]),
        .RAMwrite(RAMwrite),
        .we(write_en),
        .dataout(data_out)
    );

    mux2to1 #(.N(N))
    mux1(
        .in0()
        .in1()
        .sel0()
        .out()
    );

    mux2to1 #(.N(N))
    mux2(
        .in0()
        .in1()
        .sel0()
        .out()
    );

    mux2to1 #(.N(N))
    mux3(
        .in0()
        .in1()
        .sel0()
        .out()
    );

    mux2to1 #(.N(N))
    mux4(
        .in0()
        .in1()
        .sel0()
        .out()
    );

    INC incrementer(
    .in(),
    .inc_val(),
    .out()
    );

    Register #(.BW(BW)
    )PC(
        .clk(),
        .rst(),
        .ld(),
        .in(),
        .out()
    );

    Register #(.BW(BW)
    )IR(
        .clk(),
        .rst(),
        .ld(),
        .in(),
        .out()
    );

    Register #(.BW(BW)
    )ALUReg(
        .clk(),
        .rst(),
        .ld(),
        .in(),
        .out()
    );


endmodule