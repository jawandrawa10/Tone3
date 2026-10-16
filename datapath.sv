module datapath (

    input logic clk,
    input logic rst_n,
    //from controller
    input logic         IRload,
    input logic [1:0]   RFdin,
    input logic         RFwe_n,
    input logic         RFce,
    input logic         ALUsrcA,
    input logic         ALUsrcB,
    input logic [1:0]   PCsrc,
    input logic         PCload,
    input logic         ADDRsrc,
    input logic         RAMwrite,

    //to controller
    output logic instrID,
    output logic zeroFlag,
    output logic flagTarget,

    //from Memory System
    input logic[31:0]   data_in,

    //to Memory System
    output logic[31:0]  addr,
    output logic[31:0]  data_out,
    output logic[3:0]   write_en,
);
    logic[31:0] IRout,
    logic[31:0] ALUina,
    logic[31:0] ALUinb, 
    logic[3:0]  ALUopcode,
    logic[31:0] ALUout,
    logic[2:0]  ALUflags,
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
    logic[31:0] JLRmodOut
    localparam BW = 32;
    localparam WE_BW = 2;
    RegisterFile #(.BW(BW)
    )RF(
        .read_addr_1(IRout[19:15]),
        .read_addr_2(IRout[24:20]),
        .write_addr(IRout[11:7]),
        .data_in(RFdin),
        .clk(clk),
        .rst_n(rst_n),
        .write_en_n(RFwe_n),
        .chip_en(RFce),
        .data_out_1(RFout1),
        .data_out_2(RFout2)
    );

    ALU#(.BW(BW)
    )ALU(
        .in_a(ALUina),
        .in_b(ALUinb),
        .out(ALUout),
        .flags(ALUflags), //creo q hay q hacer una señal de 3 bits pero luego pasar solo un bit a zeroFlag
        .opcode(ALUopcode)
    );

    DECODER#(.BW(BW)
    )DECODER(
        .data_in(IRout),
        .imm(imm),
        .alu_opcode(ALUopcode),
        .flagTarget(flagTarget),
        .instrID(instrID)
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

    mux2to1 #(.N(BW))
    muxADDR(
        .in0(PCout),
        .in1(ALUout),
        .sel(ADDRsrc),
        .out(addr)
    );

    mux2to1 #(.N(BW))
    muxALUa(
        .in0(RFout1),
        .in1(PCout),
        .sel(ALUsrcA),
        .out(ALUina)
    );

    mux2to1 #(.N(BW))
    muxALUb(
        .in0(imm),
        .in1(RFout2),
        .sel(ALUsrcB),
        .out(ALUinb)
    );
    
    mux3to1 #(.N(BW))
    muxPC(
        .in0(PC_plus4),
        .in1(ALUout),
        .in2(JLRmodOut),
        .sel(PCsrc),
        .out(PCin)
    );

    mux3to1 #(.N(BW))
    muxRF(
        .in0(ALUout),
        .in1(PC_plus4),
        .in2(LoadControlOut),
        .sel(RFdin),
        .out(RFdin)
    );

    INC PC4(
        .in(PCout),
        .inc_val(32'd4),
        .out(PC_plus4)
    );

    Register #(.BW(BW)
    )PC(
        .clk(clk),
        .rst(rst_n),
        .ld(PCload),
        .in(PCin),
        .out(PCout)
    );

    Register #(.BW(BW)
    )IR(
        .clk(clk),
        .rst(rst_n),
        .ld(IRload),
        .in(data_in),
        .out(IRout)
    );

    //TODO el  BW debe ser 2 bits
    Register #(.BW(WE_BW)
    )offset(
        .clk(clk),
        .rst(rst_n),
        .ld(1),
        .in(ALUout[1:0]),
        .out(LoadControlOffset)
    );

    JLRmodule JLRmodule(
        .in(ALUout),
        .out(JLRmodOut)
    );
    assign zeroFlag = ALUflags[0]; //TODO checkear que sea la zeroflag

endmodule