module LoadControl(
    input   logic[31:0] datain,
    input   logic[2:0]  func3,
    input   logic[1:0]  offset,
    output  logic[31:0] dataout
);
    always_comb begin
        dataout='0;
        case (func3)
            3'b000: dataout = {{24{datain[offset*8+7]}},  datain[offset*8+:8]};            // LB  : sign-extend byte
            3'b001: dataout = {{16{datain[offset[1]*16+15]}}, datain[offset[1]*16+:16]};  // LH  : sign-extend half-word
            3'b010: dataout = datain;                                               // LW  : word
            3'b100: dataout = {24'b0, datain[offset*8+:8]};                            // LBU : zero-extend byte
            3'b101: dataout = {16'b0, datain[offset[1]*16+:16]};                   // LHU : zero-extend half-word
            default: dataout = '0;
        endcase
    end
endmodule
