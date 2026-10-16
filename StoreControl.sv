module StoreControl(
    input   logic[31:0] datain,
    input   logic[1:0]  offset,
    input   logic[2:0]  func3,
    input   logic       RAMwrite,
    output  logic[3:0]  we,
    output  logic[31:0] dataout
);
    always_comb begin
        we='0;
        dataout='0;
        if(RAMwrite == 1'b1)
        {
            case(func3)
                //SB
                3'b000: begin
                    dataout = datain[7:0] << (offset * 8);
                    we = 1 << offset;
                end
                //SH
                3'b001: begin
                    dataout = datain[15:0] << (offset[1] * 16);
                    we = 2'b11 << offset[1] * 2;
                end
                //SW
                3'b010: begin
                    dataout = datain;
                    we = '1;
                end
            endcase
        }
    end
endmodule