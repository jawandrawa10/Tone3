module moduleName (
    
);
    RegisterFile #(.BW(BW)
    )RF(
        .read_addr_1(read_addr_1),
        .read_addr_2(read_addr_2),
        .write_addr(write_addr),
        .data_in(data_in),
        .clk(clk),
        .rst_n(rst_n),
        .write_en_n(write_en_n),
        .chip_en(chip_en),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2)
    );

    ALU#(.BW(BW)
    )ALU(
        .in_a(a),
        .in_b(b),
        .out(o),
        .flags(flags),
        .opcode(opcode)
    );

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
    .in(),
    .fun(),
    .off(),
    .out()
    );

    SelectiveNegator SelectiveNegator(
        .in(),
        .invertion_en(),
        .out()    
    );

    StoreControl StoreControl (
        .datain(),
        .offset(),
        .func3(),
        .we(),
        .dataout(),
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