typedef enum logic [6:0] {
    R_TYPE  = 7'b0110011,
    I_TYPE  = 7'b0010011,
    LUI     = 7'b0110111, //U type
    AUIPC   = 7'b0010111, //U type
    LOAD    = 7'b0000011,
    STORE   = 7'b0100011,
    SB_TYPE = 7'b1100011,
    JAL     = 7'b1101111, //UJ type
    JALR    = 7'b1100111 //I type
} instruction_opcode;

module controller
(
    input logic         clk,
    input logic         rst_n,

    // From datapath
    input logic         zeroFlag,  // ALU flags[0]
    input logic         flagTarget,
    input logic [6:0]   instrID,
    // To datapath
    output logic         IRload,
    output logic [1:0]   RFdin,
    output logic         RFwe_n,
    output logic         RFce,
    output logic         ALUsrcA,
    output logic         ALUsrcB,
    output logic [1:0]   PCsrc,
    output logic         PCload,
    output logic         ADDRsrc,
    output logic         RAMwrite,
    
    // From memory
    input logic mem_ready,
    // To memory
    output logic read_en
);

  typedef enum logic [1:0] {
    FETCH,
    EXECUTE1,
    EXECUTE2
  } state_t;

  state_t p_state, n_state;

  always_comb begin
    n_state     = p_state;
    ADDRsrc     = 1'b0;
    ALUsrcA     = 1'b0;
    ALUsrcB     = 1'b0;
    RFdin       = 2'b00;
    PCsrc       = 2'b00;
    IRload      = 1'b0;
    PCload      = 1'b0;
    RFwe_n      = 1'b1;
    RFce        = 1'b0;
    RAMwrite    = 1'b0;
    read_en     = 1'b0;
    case (p_state)
      FETCH: begin
        read_en = 1'b1;
        if (mem_ready) begin
          read_en   = 1'b0;
          IRload    = 1'b1;
          n_state   = EXECUTE1;
        end
      end

      EXECUTE1: begin
        n_state = FETCH;
        PCload = 1'b1;
        case (instrID)
          SB_TYPE: begin
            RFce    = 1'b1;
            ALUsrcB = 1'b1;
            PCSrc   = (zeroFlag == flagTarget) ? 2'b01 : 2'b00;
          end
          JALR: begin
            RFwe_n  = 1'b0;
            RFce    = 1'b1;
            RFdin   = 2'b01;
            PCSrc   = 2'b10;
          end
          I_TYPE: begin
            RFwe_n  = 1'b0;
            RFce    = 1'b1;
          end
          R_TYPE: begin
            RFwe_n  = 1'b0;
            RFce    = 1'b1;
            ALUsrcB = 1'b1;
          end
          AUIPC,LUI: begin
            RFwe_n  = 1'b0;
            RFce    = 1'b1;
            ALUsrcA = 1'b1;
          end
          JAL: begin
            RFwe_n  = 1'b0;
            RFce    = 1'b1;
            RFdin   = 2'b01;
            PCSrc   = 2'b01;
          end
          //TODO check the states of the load/store
          LOAD: begin
            ALUsrcB = 1'b1;
            PCload = 1'b0;
            n_state = EXECUTE2;
          end
          STORE: begin
            ALUsrcB = 1'b1;
            PCload = 1'b0;
            n_state = EXECUTE2;
          end
          default: ;
        endcase
      end

      EXECUTE2: begin
        /*no se muy bien para q se pone estas señales
        ALUsrcB = 1'b1;
        ADDRsrc  = 1'b1;
        */ 

        /*
        if (instrID == STORE) RAMwrite = 1'b1;
        else read_en = 1'b1;
        if (mem_ready) begin
          RAMwrite = 1'b0;
          read_en  = 1'b0;
          PCload  = 1'b1;
          if (instrID == LOAD) begin
            RFdin = 2'b10;
            RFce  = 1'b1;
            RFwe_n = 1'b0;
          end
          n_state = FETCH;
        end
        */
      end

      default: n_state = FETCH;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) p_state <= FETCH;
    else p_state <= n_state;
  end
endmodule
 