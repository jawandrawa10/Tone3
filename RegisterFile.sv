module RegisterFile #(
    parameter BW = 32
    parameter DEPTH = 32
)(
    //AW = log2(BW)
    input logic [$clog2(DEPTH)-1:0] read_addr_1,
    input logic [$clog2(DEPTH)-1:0] read_addr_2,
    input logic [$clog2(DEPTH)-1:0] write_addr,
    input logic [BW-1:0] data_in,
    input logic clk,
    input logic rst_n,
    input logic write_en_n,
    input logic chip_en,
    output logic [BW-1:0] data_out_1,
    output logic [BW-1:0] data_out_2
);
    logic [BW-1:0]arr_regs[BW]; //array of register

    /*
    always_comb begin 
        data_out_1 = '0;
        data_out_2 = '0;
        if(chip_en & rst_n) begin
            data_out_1 = arr_regs[read_addr_1];
            data_out_2 = arr_regs[read_addr_2];
        end 
    end
    */
    /*
    ---changed because data_out_1/2 has Uknow value---
    */
    assign data_out_1 = (chip_en & rst_n)? arr_regs[read_addr_1]:'0;
    assign data_out_2 = (chip_en & rst_n)? arr_regs[read_addr_2]:'0;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (int i = 0; i<BW; i++) begin
                arr_regs[i] <= '0;
            end
        end
        else if(chip_en & !write_en_n & (write_addr != '0)) begin
            arr_regs[write_addr] <= data_in;
        end
    end
endmodule
