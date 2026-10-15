module LoadControl(
    input   logic[31:0] in,
    input   logic[2:0]  func3,
    input   logic[1:0]  offset,
    output  logic[31:0] out
);
    always_comb begin
        out='0;
        case (func3)
            3'b000: out = {{24{in[offset*8+7]}},  in[off*8+:8]};            // LB  : sign-extend byte
            3'b001: out = {{16{in[offset*16+15]}}, indata[off[1]*16+:16]};  // LH  : sign-extend half-word
            3'b010: out = in;                                               // LW  : word
            3'b100: out = {24'b0, in[off*8+:8]};                            // LBU : zero-extend byte
            3'b101: out = {16'b0, indata[off[1]*16+:16]};                   // LHU : zero-extend half-word
            default: out = '0;
        endcase
    end
endmodule
