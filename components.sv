module SelectiveNegator(
    input logic[31:0] in,
    input logic invertion_en,
    output logic out
);
    always_comb begin
        out=1'b0;
        if(invertion_en) begin
            if(in == '0)
                out = 1'b1;
            else 
                out = 1'b0;
        end
        else begin
            if(in == '0)
                out = 1'b0;
            else 
                out = 1'b1;
        end
    end
endmodule

module LoadControl(
    input   logic[31:0] in,
    input   logic[2:0]  func3,
    output  logic[31:0] out
);
    always_comb begin
        out='0;
        case (func3)
            3'b000: out = {{24{in[7]}},  in[7:0]};   // LB  : sign-extend byte
            3'b001: out = {{16{in[15]}}, in[15:0]};  // LH  : sign-extend half-word
            3'b010: out = in;                        // LW  : word
            3'b100: out = {24'b0, in[7:0]};          // LBU : zero-extend byte
            3'b101: out = {16'b0, in[15:0]};         // LHU : zero-extend half-word
            default: out = '0;
        endcase
    end
endmodule

module StoreControl(
    input   logic[31:0] in,
    input   logic[1:0]  control,
    output  logic[31:0] out
);
    
endmodule