module CPU_top (
    input logic         clk,
    input logic         rst_n,
    //from Memory System
    input logic[31:0]   data_in,
    input               mem_ready,
    //to Memory System
    output logic[31:0]  addr,
    output logic[31:0]  data_out,
    output logic[3:0]   write_en,
    output logic        read_en
);
    logic         IRload;
    logic [1:0]   RFdin;
    logic         RFwe_n;
    logic         RFce;
    logic         ALUsrcA;
    logic         ALUsrcB;
    logic [1:0]   PCsrc;
    logic         PCload;
    logic         ADDRsrc;
    logic         RAMwrite;
    logic [6:0]   instrID;
    logic         zeroFlag;
    logic         flagTarget;

    controller CONTROLLER(
       .clk(clk),
       .rst_n(rst_n),
       .zeroFlag(zeroFlag),
       .flagTarget(flagTarget),
       .instrID(instrID),
       .IRload(IRload),
       .RFdin(RFdin),
       .RFwe_n(RFwe_n),
       .RFce(RFce),
       .ALUsrcA(ALUsrcA),
       .ALUsrcB(ALUsrcB),
       .PCsrc(PCsrc),
       .PCload(PCload),
       .ADDRsrc(ADDRsrc),
       .RAMwrite(RAMwrite),
       .mem_ready(mem_ready),
       .read_en(read_en)
    );

    datapath DATAPATH(
        .clk(clk),
        .rst_n(rst_n),
        .IRload(IRload),
        .RFdin(RFdin),
        .RFwe_n(RFwe_n),
        .RFce(RFce),
        .ALUsrcA(ALUsrcA),
        .ALUsrcB(ALUsrcB),
        .PCsrc(PCsrc),
        .PCload(PCload),
        .ADDRsrc(ADDRsrc),
        .RAMwrite(RAMwrite),
        .instrID(instrID),
        .zeroFlag(zeroFlag),
        .flagTarget(flagTarget),
        .data_in(data_in),
        .addr(addr),
        .data_out(data_out),
        .write_en(write_en),
    );

endmodule