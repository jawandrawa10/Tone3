`timescale 1ns/1ps
//==============================================================================
// CPU_top_tb.sv  -  Milestone 3, Part 3, tarea 5
//
// Testbench auto-verificable que prueba CADA instruccion de forma INDIVIDUAL:
//   * Cada test: reset del DUT -> programa de preparacion (LUI/ADDI para dejar
//     los registros con los operandos) -> UNA instruccion bajo test.
//   * (5a) Para la instruccion bajo test se comprueba, ciclo a ciclo y por estado
//     (FETCH / EXEC1 / EXEC2), que las señales de control son las esperadas.
//   * (5b) Se compara el resultado (registros, memoria, PC siguiente) contra un
//     modelo de referencia de la ISA escrito en este mismo testbench.
//   * La memoria esta emulada aqui dentro (lectura/escritura por palabra con
//     byte-enable y handshake mem_ready con latencia configurable).
//   * Toda la suite se repite con varias latencias de memoria.
//
// Referencias jerarquicas usadas (ajustalas con los dos `define de abajo si tus
// nombres son distintos):
//   dut.CONTROLLER.p_state     estado del controlador (FETCH=0, EXECUTE1=1, EXECUTE2=2)
//   dut.DATAPATH.RF.arr_regs   banco de registros
//   dut.<señal de control>     nets declaradas en CPU_top (IRload, RFdin, ...)
//
// FSM esperada para LOAD/STORE (tabla en la funcion exp_ctrl):
//   EXEC1: solo calcula; PCload=0, RFwe_n=1, RAMwrite=0.
//   EXEC2: ADDRsrc=1, RFce=1 y se mantiene read_en (load) o RAMwrite (store)
//          hasta mem_ready; PCload y RFwe_n (load) solo cuando mem_ready=1.
//==============================================================================

`define CPU_STATE  dut.CONTROLLER.p_state
`define RF_REGS    dut.DATAPATH.RF.arr_regs

module CPU_top_tb;

    // ========================================================== CONFIGURACION
    localparam int CLK_PERIOD = 10;
    localparam int MEM_WORDS  = 2048;               // 8 KB -> addr[12:2]
    localparam int AW         = $clog2(MEM_WORDS);
    localparam int PAD_WORDS  = 16;                 // la instruccion bajo test queda en PC = 0x40
    localparam int PH_TIMEOUT = 600;                // ciclos maximos por fase
    localparam int N_LATS     = 4;                  // latencias de memoria a probar
    localparam int MAX_MSG    = 8;                  // mensajes de error maximos por test
    localparam bit VERBOSE    = 1'b0;               // 1: imprime tambien los tests que pasan
    localparam bit CHECK_CTRL = 1'b1;               // 0: no comprueba señales de control
    localparam logic [31:0] JUNK = 32'hBAD0_C0DE;   // lo que ve data_in si mem_ready=0

    localparam int S_FETCH = 0, S_EXEC1 = 1, S_EXEC2 = 2;
    localparam int DC = -1;                         // "don't care" en la tabla de control

    // ================================================================= SEÑALES
    logic        clk, rst_n;
    logic [31:0] data_in, addr, data_out;
    logic        mem_ready, read_en;
    logic [3:0]  write_en;

    CPU_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .mem_ready(mem_ready),
        .addr     (addr),
        .data_out (data_out),
        .write_en (write_en),
        .read_en  (read_en)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============================================================ MEMORIA EMULADA
    // La peticion se captura en el primer ciclo en que se ve read_en o write_en
    // (como hace la FSM del SRAMcontroller) y mem_ready llega mem_lat ciclos despues.
    logic [31:0] mem [0:MEM_WORDS-1];
    int          mem_lat;
    logic        busy;
    int          cnt;
    logic [31:0] rdata_q;
    int          txn_n;                              // transacciones vistas
    logic [31:0] txn_addr [0:7];
    logic        txn_wr   [0:7];

    assign data_in = mem_ready ? rdata_q : JUNK;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            busy      <= 1'b0;
            cnt       <= 0;
        end else begin
            mem_ready <= 1'b0;
            if (busy) begin
                if (cnt >= mem_lat-1) begin
                    mem_ready <= 1'b1;
                    busy      <= 1'b0;
                end else
                    cnt <= cnt + 1;
            end else if (!mem_ready && (read_en || (|write_en))) begin
                if (txn_n < 8) begin
                    txn_addr[txn_n] = addr;
                    txn_wr[txn_n]   = |write_en;
                end
                txn_n = txn_n + 1;
                if (|write_en) begin
                    for (int i = 0; i < 4; i++)
                        if (write_en[i]) mem[addr[AW+1:2]][8*i +: 8] = data_out[8*i +: 8];
                end else begin
                    rdata_q = mem[addr[AW+1:2]];
                end
                if (mem_lat <= 1) mem_ready <= 1'b1;
                else begin
                    busy <= 1'b1;
                    cnt  <= 1;
                end
            end
        end
    end

    // ======================================================= ENSAMBLADOR RV32I
    function automatic logic [31:0] R(input logic [6:0] f7, input int rs2, input int rs1,
                                      input logic [2:0] f3, input int rd);
        return {f7, 5'(rs2), 5'(rs1), f3, 5'(rd), 7'b0110011};
    endfunction

    function automatic logic [31:0] I_ALU(input logic [2:0] f3, input int rd,
                                          input int rs1, input int imm);
        return {12'(imm), 5'(rs1), f3, 5'(rd), 7'b0010011};
    endfunction

    function automatic logic [31:0] SHI(input logic [6:0] f7, input logic [2:0] f3,
                                        input int rd, input int rs1, input int shamt);
        return {f7, 5'(shamt), 5'(rs1), f3, 5'(rd), 7'b0010011};
    endfunction

    function automatic logic [31:0] LD(input logic [2:0] f3, input int rd,
                                       input int rs1, input int imm);
        return {12'(imm), 5'(rs1), f3, 5'(rd), 7'b0000011};
    endfunction

    function automatic logic [31:0] ST(input logic [2:0] f3, input int rs2,
                                       input int rs1, input int imm);
        logic [11:0] i;
        i = 12'(imm);
        return {i[11:5], 5'(rs2), 5'(rs1), f3, i[4:0], 7'b0100011};
    endfunction

    function automatic logic [31:0] BR(input logic [2:0] f3, input int rs1,
                                       input int rs2, input int imm);
        logic [12:0] i;
        i = 13'(imm);
        return {i[12], i[10:5], 5'(rs2), 5'(rs1), f3, i[4:1], i[11], 7'b1100011};
    endfunction

    function automatic logic [31:0] LUI_(input int rd, input int imm20);
        return {20'(imm20), 5'(rd), 7'b0110111};
    endfunction

    function automatic logic [31:0] AUIPC_(input int rd, input int imm20);
        return {20'(imm20), 5'(rd), 7'b0010111};
    endfunction

    function automatic logic [31:0] JAL_(input int rd, input int imm);
        logic [20:0] i;
        i = 21'(imm);
        return {i[20], i[10:1], i[11], i[19:12], 5'(rd), 7'b1101111};
    endfunction

    function automatic logic [31:0] JALR_(input int rd, input int rs1, input int imm);
        return {12'(imm), 5'(rs1), 3'b000, 5'(rd), 7'b1100111};
    endfunction

    localparam logic [31:0] NOP = 32'h0000_0013;     // addi x0,x0,0

    // ================================================= CLASES DE INSTRUCCION
    typedef enum int {C_R, C_I, C_LUI, C_AUIPC, C_LOAD, C_STORE, C_BR, C_JAL, C_JALR, C_IGN} cls_t;

    localparam int PH_FETCH_WAIT = 0, PH_FETCH_DONE = 1, PH_EXEC1 = 2,
                   PH_EXEC2_WAIT = 3, PH_EXEC2_DONE = 4;

    function automatic string phase_name(input int ph);
        case (ph)
            PH_FETCH_WAIT: return "FETCH (esperando mem_ready)";
            PH_FETCH_DONE: return "FETCH (ciclo con mem_ready)";
            PH_EXEC1:      return "EXEC1";
            PH_EXEC2_WAIT: return "EXEC2 (esperando mem_ready)";
            default:       return "EXEC2 (ciclo con mem_ready)";
        endcase
    endfunction

    // ======================================================== TABLA DE CONTROL
    // Vector de control: {IRload, RFdin[1:0], RFwe_n, RFce, ALUsrcA, ALUsrcB,
    //                     PCsrc[1:0], PCload, ADDRsrc, RAMwrite, read_en}  (13 bits)
    // cv() devuelve {mascara[12:0], valor[12:0]}; DC (-1) = no se comprueba.
    function automatic logic [25:0] cv(input int f0, input int f1, input int f2, input int f3,
                                       input int f4, input int f5, input int f6, input int f7,
                                       input int f8, input int f9, input int f10);
        logic [12:0] v, m;
        v = {f0[0], f1[1:0], f2[0], f3[0], f4[0], f5[0], f6[1:0], f7[0], f8[0], f9[0], f10[0]};
        m = {{1{f0>=0}}, {2{f1>=0}}, {1{f2>=0}}, {1{f3>=0}}, {1{f4>=0}}, {1{f5>=0}},
             {2{f6>=0}}, {1{f7>=0}}, {1{f8>=0}}, {1{f9>=0}}, {1{f10>=0}}};
        return {m, v};
    endfunction

    //                 IRl  RFdin we_n ce  A   B  PCsrc PCl ADDR RAMw ren
    function automatic logic [25:0] exp_ctrl(input cls_t c, input int ph, input bit tk);
        logic [25:0] r;
        int pcs;
        pcs = tk ? 1 : 0;
        r = '0;
        case (ph)
            PH_FETCH_WAIT: r = cv(DC, DC, 1,  DC, DC, DC, DC, 0, 0, 0, 1);
            PH_FETCH_DONE: r = cv(1,  DC, 1,  DC, DC, DC, DC, 0, 0, 0, DC);
            PH_EXEC1: begin
                case (c)
                    C_R:     r = cv(0, 0,  0, 1,  0,  1,  0,   1, 0,  0, 0);
                    C_I:     r = cv(0, 0,  0, 1,  0,  0,  0,   1, 0,  0, 0);
                    C_LUI:   r = cv(0, 0,  0, 1,  DC, 0,  0,   1, 0,  0, 0);
                    C_AUIPC: r = cv(0, 0,  0, 1,  1,  0,  0,   1, 0,  0, 0);
                    C_JAL:   r = cv(0, 1,  0, 1,  DC, DC, 1,   1, 0,  0, 0);
                    C_JALR:  r = cv(0, 1,  0, 1,  0,  0,  2,   1, 0,  0, 0);
                    C_BR:    r = cv(0, DC, 1, 1,  0,  1,  pcs, 1, 0,  0, 0);
                    C_LOAD:  r = cv(0, DC, 1, DC, DC, DC, DC,  0, DC, 0, DC);
                    C_STORE: r = cv(0, DC, 1, DC, DC, DC, DC,  0, DC, 0, DC);
                    default: r = cv(0, DC, 1, DC, DC, DC, 0,   1, 0,  0, 0);   // FENCE/ECALL: PC+4
                endcase
            end
            PH_EXEC2_WAIT: begin
                if (c == C_LOAD) r = cv(0, DC, 1, 1, 0, 0, DC, 0, 1, 0, 1);
                else             r = cv(0, DC, 1, 1, 0, 0, DC, 0, 1, 1, 0);
            end
            default: begin   // PH_EXEC2_DONE
                if (c == C_LOAD) r = cv(0, 2,  0, 1,  DC, DC, 0, 1, 1, 0,  DC);
                else             r = cv(0, DC, 1, DC, DC, DC, 0, 1, 1, DC, DC);
            end
        endcase
        return r;
    endfunction

    function automatic string fld_name(input int f);
        case (f)
            0: return "IRload";  1: return "RFdin";   2: return "RFwe_n";  3: return "RFce";
            4: return "ALUsrcA"; 5: return "ALUsrcB"; 6: return "PCsrc";   7: return "PCload";
            8: return "ADDRsrc"; 9: return "RAMwrite"; default: return "read_en";
        endcase
    endfunction
    function automatic int fld_hi(input int f);
        case (f)
            0: return 12; 1: return 11; 2: return 9; 3: return 8; 4: return 7; 5: return 6;
            6: return 5;  7: return 3;  8: return 2; 9: return 1; default: return 0;
        endcase
    endfunction
    function automatic int fld_lo(input int f);
        case (f)
            0: return 12; 1: return 10; 2: return 9; 3: return 8; 4: return 7; 5: return 6;
            6: return 4;  7: return 3;  8: return 2; 9: return 1; default: return 0;
        endcase
    endfunction

    function automatic string ctrl_diff(input logic [12:0] got, input logic [12:0] ev,
                                        input logic [12:0] em);
        string s, g, x;
        s = "";
        for (int f = 0; f < 11; f++) begin
            bit bad;
            bad = 0;
            for (int b = fld_lo(f); b <= fld_hi(f); b++)
                if (em[b] && (got[b] !== ev[b])) bad = 1;
            if (bad) begin
                g = ""; x = "";
                for (int b = fld_hi(f); b >= fld_lo(f); b--) begin
                    g = {g, $sformatf("%b", got[b])};
                    x = {x, $sformatf("%b", ev[b])};
                end
                s = {s, $sformatf(" %s=%s(esperado %s)", fld_name(f), g, x)};
            end
        end
        return s;
    endfunction

    // ================================================= MODELO DE REFERENCIA ISA
    logic [31:0] rb [0:31];          // registros ANTES de la instruccion
    logic [31:0] ra [0:31];          // registros DESPUES
    logic [31:0] gmem [0:MEM_WORDS-1];

    cls_t        cls;
    logic [31:0] exp_val, exp_npc, exp_ea, exp_sdata;
    logic [4:0]  exp_rd;
    logic [3:0]  exp_strb;
    bit          exp_we, is_load, is_store, taken;

    function automatic logic [31:0] merge_w(input logic [31:0] oldw, input logic [31:0] neww,
                                            input logic [3:0] strb);
        logic [31:0] r;
        r = oldw;
        for (int i = 0; i < 4; i++)
            if (strb[i]) r[8*i +: 8] = neww[8*i +: 8];
        return r;
    endfunction

    task automatic compute_expected(input logic [31:0] ins, input logic [31:0] pc);
        logic [6:0]  op;
        logic [4:0]  rd, rs1, rs2, shamt;
        logic [2:0]  f3;
        logic [31:0] a, b, imm_i, imm_s, imm_b, imm_u, imm_j, w, sh_w, sh_h;
        logic signed [31:0] sa, sb;

        op  = ins[6:0];   rd  = ins[11:7];  f3 = ins[14:12];
        rs1 = ins[19:15]; rs2 = ins[24:20];
        a   = (rs1 == 0) ? 32'h0 : rb[rs1];
        b   = (rs2 == 0) ? 32'h0 : rb[rs2];
        sa  = a;  sb = b;
        imm_i = {{20{ins[31]}}, ins[31:20]};
        imm_s = {{20{ins[31]}}, ins[31:25], ins[11:7]};
        imm_b = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
        imm_u = {ins[31:12], 12'h0};
        imm_j = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

        cls = C_IGN; exp_we = 0; exp_rd = rd; exp_val = 32'h0; exp_npc = pc + 32'd4;
        is_load = 0; is_store = 0; taken = 0; exp_ea = 32'h0; exp_strb = 4'h0; exp_sdata = 32'h0;

        case (op)
            7'b0110011: begin                                   // R-type
                cls = C_R; exp_we = 1; shamt = b[4:0];
                case (f3)
                    3'b000: if (ins[30]) exp_val = a - b; else exp_val = a + b;
                    3'b001: exp_val = a << shamt;
                    3'b010: exp_val = (sa < sb) ? 32'd1 : 32'd0;
                    3'b011: exp_val = (a < b)   ? 32'd1 : 32'd0;
                    3'b100: exp_val = a ^ b;
                    3'b101: if (ins[30]) exp_val = sa >>> shamt; else exp_val = a >> shamt;
                    3'b110: exp_val = a | b;
                    default: exp_val = a & b;
                endcase
            end
            7'b0010011: begin                                   // I-type ALU
                cls = C_I; exp_we = 1; shamt = ins[24:20];
                case (f3)
                    3'b000: exp_val = a + imm_i;
                    3'b001: exp_val = a << shamt;
                    3'b010: exp_val = (sa < $signed(imm_i)) ? 32'd1 : 32'd0;
                    3'b011: exp_val = (a < imm_i)           ? 32'd1 : 32'd0;
                    3'b100: exp_val = a ^ imm_i;
                    3'b101: if (ins[30]) exp_val = sa >>> shamt; else exp_val = a >> shamt;
                    3'b110: exp_val = a | imm_i;
                    default: exp_val = a & imm_i;
                endcase
            end
            7'b0110111: begin cls = C_LUI;   exp_we = 1; exp_val = imm_u;      end
            7'b0010111: begin cls = C_AUIPC; exp_we = 1; exp_val = pc + imm_u; end
            7'b0000011: begin                                   // loads
                cls = C_LOAD; is_load = 1; exp_we = 1;
                exp_ea = a + imm_i;
                w    = gmem[exp_ea[AW+1:2]];
                sh_w = w >> (8  * exp_ea[1:0]);
                sh_h = w >> (16 * exp_ea[1]);
                case (f3)
                    3'b000:  exp_val = {{24{sh_w[7]}},  sh_w[7:0]};    // LB
                    3'b001:  exp_val = {{16{sh_h[15]}}, sh_h[15:0]};   // LH
                    3'b010:  exp_val = w;                              // LW
                    3'b100:  exp_val = {24'h0, sh_w[7:0]};             // LBU
                    default: exp_val = {16'h0, sh_h[15:0]};            // LHU
                endcase
            end
            7'b0100011: begin                                   // stores
                cls = C_STORE; is_store = 1;
                exp_ea = a + imm_s;
                case (f3)
                    3'b000: begin exp_strb = 4'b0001 << exp_ea[1:0];            exp_sdata = {4{b[7:0]}};  end
                    3'b001: begin exp_strb = exp_ea[1] ? 4'b1100 : 4'b0011;     exp_sdata = {2{b[15:0]}}; end
                    default: begin exp_strb = 4'b1111;                          exp_sdata = b;            end
                endcase
            end
            7'b1100011: begin                                   // branches
                cls = C_BR;
                case (f3)
                    3'b000: taken = (a == b);
                    3'b001: taken = (a != b);
                    3'b100: taken = (sa <  sb);
                    3'b101: taken = (sa >= sb);
                    3'b110: taken = (a <  b);
                    3'b111: taken = (a >= b);
                    default: taken = 0;
                endcase
                if (taken) exp_npc = pc + imm_b;
            end
            7'b1101111: begin                                   // JAL
                cls = C_JAL; exp_we = 1; exp_val = pc + 32'd4; exp_npc = pc + imm_j;
            end
            7'b1100111: begin                                   // JALR
                cls = C_JALR; exp_we = 1; exp_val = pc + 32'd4;
                exp_npc = (a + imm_i) & 32'hFFFF_FFFC;
            end
            default: cls = C_IGN;                               // FENCE / ECALL: se ignoran
        endcase
    endtask

    // ====================================================== ESTADO DE UN TEST
    string       cur_grp, cur_desc;
    int          test_err;
    int          n_f, n_1, n_2, cyc_n;
    logic [31:0] test_pc;
    int          pc_idx;
    bit          poison_mode;

    int          n_pre;  int pre_idx [0:15];  logic [31:0] pre_val [0:15];
    int          n_pm;   logic [31:0] pm_addr [0:15];  logic [31:0] pm_val [0:15];

    int          grp_pass [string];
    int          grp_fail [string];
    string       grp_order [$];
    int          lat_tests, lat_fail, tot_tests, tot_fail;

    task automatic fail(input string msg);
        if (test_err < MAX_MSG)
            $display("[FAIL][lat=%0d] %s | %s\n           -> %s", mem_lat, cur_grp, cur_desc, msg);
        else if (test_err == MAX_MSG)
            $display("           ... (se omiten mas errores de este test)");
        test_err++;
    endtask

    task automatic tally(input string g, input bit ok);
        if (!grp_pass.exists(g)) begin
            grp_pass[g] = 0;
            grp_fail[g] = 0;
            grp_order.push_back(g);
        end
        if (ok) grp_pass[g] = grp_pass[g] + 1;
        else    grp_fail[g] = grp_fail[g] + 1;
        lat_tests++;  tot_tests++;
        if (!ok) begin lat_fail++; tot_fail++; end
        if (ok && VERBOSE) $display("[ OK ][lat=%0d] %s | %s", mem_lat, g, cur_desc);
    endtask

    task automatic emit(input logic [31:0] w);
        mem[pc_idx] = w;
        pc_idx++;
    endtask

    // x[rd] = v  (1 o 2 instrucciones)
    task automatic emit_li(input int rd, input logic [31:0] v);
        logic [19:0] hi;
        logic [11:0] lo;
        lo = v[11:0];
        hi = 20'((v + 32'h800) >> 12);
        if (v[31:11] == 21'h0 || v[31:11] == 21'h1FFFFF)
            emit(I_ALU(3'b000, rd, 0, int'($signed(lo))));
        else begin
            emit(LUI_(rd, int'(hi)));
            if (lo != 12'h0) emit(I_ALU(3'b000, rd, rd, int'($signed(lo))));
        end
    endtask

    task automatic clr_pre();
        n_pre = 0;  n_pm = 0;
    endtask
    task automatic pre_reg(input int idx, input logic [31:0] v);
        if (idx != 0) begin pre_idx[n_pre] = idx; pre_val[n_pre] = v; n_pre++; end
    endtask
    task automatic pre_mem(input logic [31:0] a, input logic [31:0] v);
        pm_addr[n_pm] = a; pm_val[n_pm] = v; n_pm++;
    endtask

    // ------------------------------------------------ comprobacion de un ciclo
    task automatic check_cycle(output logic [1:0] stv);
        int          ph;
        logic [12:0] got, ev, em;
        logic [25:0] e;

        stv = `CPU_STATE;
        cyc_n++;
        if ($isunknown(stv)) begin
            fail($sformatf("ciclo %0d: el estado del controlador es X", cyc_n));
            return;
        end

        case (stv)
            2'd0: begin
                n_f++;
                ph = mem_ready ? PH_FETCH_DONE : PH_FETCH_WAIT;
                if (addr !== test_pc)
                    fail($sformatf("ciclo %0d: addr en FETCH = 0x%08h, esperado PC = 0x%08h", cyc_n, addr, test_pc));
            end
            2'd1: begin
                n_1++;
                ph = PH_EXEC1;
            end
            2'd2: begin
                n_2++;
                ph = mem_ready ? PH_EXEC2_DONE : PH_EXEC2_WAIT;
                if ((is_load || is_store) && addr[31:2] !== exp_ea[31:2])
                    fail($sformatf("ciclo %0d: addr en EXEC2 = 0x%08h, esperado 0x%08h (rs1+imm)", cyc_n, addr, exp_ea));
            end
            default: begin
                fail($sformatf("ciclo %0d: estado ilegal %0d", cyc_n, stv));
                return;
            end
        endcase

        // --- (5a) señales de control
        got = {dut.IRload, dut.RFdin, dut.RFwe_n, dut.RFce, dut.ALUsrcA, dut.ALUsrcB,
               dut.PCsrc, dut.PCload, dut.ADDRsrc, dut.RAMwrite, read_en};
        e  = exp_ctrl(cls, ph, taken);
        em = e[25:13];
        ev = e[12:0];
        if (CHECK_CTRL && (((got ^ ev) & em) !== 13'b0))
            fail($sformatf("ciclo %0d, %s: señales de control incorrectas:%s",
                           cyc_n, phase_name(ph), ctrl_diff(got, ev, em)));

        // --- bus de memoria: write_en solo en el EXEC2 de un store
        if (is_store && stv == 2'd2) begin
            if (ph == PH_EXEC2_WAIT && write_en !== exp_strb)
                fail($sformatf("ciclo %0d: write_en = %b, esperado %b", cyc_n, write_en, exp_strb));
        end else if (write_en !== 4'b0000) begin
            fail($sformatf("ciclo %0d, %s: write_en = %b (solo debe activarse en el EXEC2 de un store)",
                           cyc_n, phase_name(ph), write_en));
        end
        if (read_en && (|write_en))
            fail($sformatf("ciclo %0d: read_en y write_en activos a la vez", cyc_n));
    endtask

    // ------------------------------------------------------ test completo
    task automatic run_core(input logic [31:0] ins);
        int          n, exp_txn;
        bit          found, done, seen_exec;
        logic [1:0]  stv;
        logic [31:0] next_pc, exp_w, exp_r, pre_exp;

        // ---- 1) programa en memoria
        for (int i = 0; i < MEM_WORDS; i++) mem[i] = 32'h0;
        pc_idx = 0;
        if (poison_mode) begin                       // intenta escribir en x0
            emit(I_ALU(3'b000, 0, 0, 2047));
            emit(LUI_(0, 20'hFFFFF));
        end
        for (int k = 0; k < n_pre; k++) emit_li(pre_idx[k], pre_val[k]);
        if (pc_idx > PAD_WORDS) $fatal(1, "La preparacion no cabe en PAD_WORDS");
        while (pc_idx < PAD_WORDS) emit(NOP);
        test_pc = pc_idx * 4;
        emit(ins);
        for (int k = 0; k < n_pm; k++) begin
            if (pm_addr[k] < test_pc + 32'd4) $fatal(1, "pre_mem pisa el programa");
            mem[pm_addr[k][AW+1:2]] = pm_val[k];
        end

        // ---- 2) reset y ejecucion hasta el FETCH de la instruccion bajo test
        txn_n = 0;
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1 rst_n = 1'b1;

        n = 0; found = 0;
        while (!found && n < PH_TIMEOUT) begin
            @(negedge clk);
            n++;
            if (int'(`CPU_STATE) == S_FETCH && addr === test_pc) found = 1;
        end
        if (!found) begin
            fail($sformatf("TIMEOUT: la CPU no llego a hacer fetch de 0x%08h (fallo en la preparacion LUI/ADDI/NOP)", test_pc));
            return;
        end

        // ---- 3) foto del estado inicial y valores esperados
        for (int i = 0; i < 32; i++) rb[i] = `RF_REGS[i];
        for (int i = 0; i < MEM_WORDS; i++) gmem[i] = mem[i];
        txn_n = 0;
        compute_expected(ins, test_pc);

        if (rb[0] !== 32'h0)
            fail($sformatf("SETUP: x0 = 0x%08h tras intentar escribirlo; el RF debe tener x0 cableado a 0", rb[0]));
        for (int i = 1; i < 32; i++) begin
            pre_exp = 32'h0;
            for (int k = 0; k < n_pre; k++) if (pre_idx[k] == i) pre_exp = pre_val[k];
            if (rb[i] !== pre_exp)
                fail($sformatf("SETUP: x%0d = 0x%08h antes de la instruccion, esperado 0x%08h (fallan LUI/ADDI de la preparacion)",
                               i, rb[i], pre_exp));
        end

        // ---- 4) traza de la instruccion (FETCH + EXEC1 [+ EXEC2])
        n_f = 0; n_1 = 0; n_2 = 0; cyc_n = 0;
        n = 0; done = 0; seen_exec = 0;
        while (!done && n < PH_TIMEOUT) begin
            check_cycle(stv);
            if (stv != 2'd0) seen_exec = 1;
            @(negedge clk);
            n++;
            if (seen_exec && int'(`CPU_STATE) == S_FETCH) done = 1;
        end
        if (!done) begin
            fail("TIMEOUT: la instruccion no termina (el controlador no vuelve a FETCH)");
            return;
        end
        next_pc = addr;
        for (int i = 0; i < 32; i++) ra[i] = `RF_REGS[i];

        // ---- 5) (5b) comportamiento segun la ISA
        if (next_pc !== exp_npc)
            fail($sformatf("PC siguiente = 0x%08h, esperado 0x%08h", next_pc, exp_npc));

        if (ra[0] !== 32'h0)
            fail($sformatf("x0 = 0x%08h, debe ser 0", ra[0]));
        for (int i = 1; i < 32; i++) begin
            exp_r = (exp_we && exp_rd == i) ? exp_val : rb[i];
            if (ra[i] !== exp_r)
                fail($sformatf("x%0d = 0x%08h, esperado 0x%08h%s", i, ra[i], exp_r,
                               (exp_we && exp_rd == i) ? " (registro destino)" : " (no debia cambiar)"));
        end

        for (int i = 0; i < MEM_WORDS; i++) begin
            exp_w = gmem[i];
            if (is_store && i == int'(exp_ea[AW+1:2])) exp_w = merge_w(gmem[i], exp_sdata, exp_strb);
            if (mem[i] !== exp_w)
                fail($sformatf("memoria[0x%08h] = 0x%08h, esperado 0x%08h", i*4, mem[i], exp_w));
        end

        exp_txn = 1 + ((is_load || is_store) ? 1 : 0);
        if (txn_n != exp_txn)
            fail($sformatf("accesos a memoria = %0d, esperados %0d", txn_n, exp_txn));
        else begin
            if (txn_wr[0] || txn_addr[0] !== test_pc)
                fail($sformatf("el fetch debia ser una lectura en 0x%08h (visto: %s 0x%08h)",
                               test_pc, txn_wr[0] ? "escritura" : "lectura", txn_addr[0]));
            if (is_load && (txn_wr[1] || txn_addr[1][31:2] !== exp_ea[31:2]))
                fail($sformatf("el load debia ser una lectura en 0x%08h (visto: %s 0x%08h)",
                               exp_ea, txn_wr[1] ? "escritura" : "lectura", txn_addr[1]));
            if (is_store && (!txn_wr[1] || txn_addr[1][31:2] !== exp_ea[31:2]))
                fail($sformatf("el store debia ser una escritura en 0x%08h (visto: %s 0x%08h)",
                               exp_ea, txn_wr[1] ? "escritura" : "lectura", txn_addr[1]));
        end

        // ---- 6) secuencia de estados
        if (n_1 != 1)
            fail($sformatf("EXEC1 dura %0d ciclos, esperado 1", n_1));
        if (n_f != mem_lat + 1)
            fail($sformatf("FETCH dura %0d ciclos, esperado %0d (latencia %0d + 1)", n_f, mem_lat + 1, mem_lat));
        if (is_load || is_store) begin
            if (n_2 != mem_lat + 1)
                fail($sformatf("EXEC2 dura %0d ciclos, esperado %0d", n_2, mem_lat + 1));
        end else if (n_2 != 0)
            fail($sformatf("EXEC2 solo debe usarse en load/store (duro %0d ciclos)", n_2));
    endtask

    task automatic run_test(input string grp, input string desc, input logic [31:0] ins);
        cur_grp  = grp;
        cur_desc = poison_mode ? {desc, " [x0 envenenado]"} : desc;
        test_err = 0;
        run_core(ins);
        tally(grp, test_err == 0);
    endtask

    // ===================================================== VALORES DE PRUEBA
    localparam int N_PAIRS = 16;
    function automatic logic [31:0] pa(input int k);
        case (k)
            0:  return 32'h0000_0000;  1:  return 32'h0000_0001;
            2:  return 32'h7FFF_FFFF;  3:  return 32'h8000_0000;
            4:  return 32'hFFFF_FFFF;  5:  return 32'hFFFF_FFFF;
            6:  return 32'h1234_5678;  7:  return 32'h8000_0000;
            8:  return 32'h7FFF_FFFF;  9:  return 32'h0000_0005;
            10: return 32'hFFFF_FFFD;  11: return 32'hA5A5_A5A5;
            12: return 32'hF0F0_F0F0;  13: return 32'h8000_0001;
            14: return 32'hDEAD_BEEF;  default: return 32'h0000_0000;
        endcase
    endfunction
    function automatic logic [31:0] pb(input int k);
        case (k)
            0:  return 32'h0000_0000;  1:  return 32'h0000_0001;
            2:  return 32'h0000_0001;  3:  return 32'h0000_0001;
            4:  return 32'h0000_0001;  5:  return 32'hFFFF_FFFF;
            6:  return 32'h0FED_CBA9;  7:  return 32'h7FFF_FFFF;
            8:  return 32'h8000_0000;  9:  return 32'hFFFF_FFFD;
            10: return 32'h0000_0005;  11: return 32'h5A5A_5A5A;
            12: return 32'h0000_0004;  13: return 32'h0000_001F;
            14: return 32'hFFFF_FFE5;  default: return 32'hFFFF_FFFF;
        endcase
    endfunction

    localparam int N_IP = 14;
    function automatic logic [31:0] ia(input int k);
        case (k)
            0: return 32'h0;          1: return 32'h0;          2: return 32'h1;
            3: return 32'h7FFF_FFFF;  4: return 32'hFFFF_FFFF;  5: return 32'h1234_5678;
            6: return 32'h1234_5678;  7: return 32'h8000_0000;  8: return 32'hA5A5_A5A5;
            9: return 32'hFFFF_FFF0;  10: return 32'h5;         11: return 32'hFFFF_FFFD;
            12: return 32'hDEAD_BEEF; default: return 32'hDEAD_BEEF;
        endcase
    endfunction
    function automatic int iimm(input int k);
        case (k)
            0: return 0;      1: return -1;     2: return 1;      3: return 1;
            4: return 1;      5: return 2047;   6: return -2048;  7: return -1;
            8: return 'h5A5;  9: return 15;     10: return -3;    11: return 5;
            12: return 'h555; default: return -'h556;
        endcase
    endfunction

    function automatic int bo(input int k);               // offsets de branch
        case (k)
            0: return 4;      1: return 8;       2: return 'h7C;   3: return -'h40;
            4: return 'hFFC;  5: return -'h1000; 6: return 'h554;  7: return -'h558;
            8: return 'hAA8;  default: return -'h2AC;
        endcase
    endfunction
    function automatic int jo(input int k);               // offsets de JAL
        case (k)
            0: return 4;        1: return 8;           2: return 'h7C;        3: return -'h40;
            4: return 'hFFFFC;  5: return -'h100000;   6: return 'h55554;     7: return -'h55558;
            8: return 'hAAAA8;  default: return 'h3F7FC;
        endcase
    endfunction

    function automatic logic [31:0] lword(input int i);
        case (i)
            0: return 32'h8081_F2F3;
            1: return 32'h7F7E_0D0C;
            default: return 32'h7F80_FF00;
        endcase
    endfunction
    function automatic logic [31:0] sval(input int i);
        case (i)
            0: return 32'h1122_33A5;
            default: return 32'hFFFF_FF5A;
        endcase
    endfunction

    // ============================================================ TESTS (tipos)
    task automatic rtest(input string m, input logic [6:0] f7, input logic [2:0] f3,
                         input int rd, input int rs1, input int rs2,
                         input logic [31:0] a, input logic [31:0] b);
        clr_pre();
        if (rs1 == rs2) pre_reg(rs1, a);
        else begin pre_reg(rs1, a); pre_reg(rs2, b); end
        run_test(m, $sformatf("%s x%0d,x%0d,x%0d  rs1=0x%08h rs2=0x%08h", m, rd, rs1, rs2, a,
                              (rs1 == rs2) ? a : b),
                 R(f7, rs2, rs1, f3, rd));
    endtask

    task automatic itest(input string m, input logic [2:0] f3, input int rd, input int rs1,
                         input logic [31:0] a, input int imm);
        clr_pre();
        pre_reg(rs1, a);
        run_test(m, $sformatf("%s x%0d,x%0d,%0d  rs1=0x%08h", m, rd, rs1, imm, a),
                 I_ALU(f3, rd, rs1, imm));
    endtask

    task automatic shtest(input string m, input logic [6:0] f7, input logic [2:0] f3,
                          input int rd, input int rs1, input logic [31:0] a, input int shamt);
        clr_pre();
        pre_reg(rs1, a);
        run_test(m, $sformatf("%s x%0d,x%0d,%0d  rs1=0x%08h", m, rd, rs1, shamt, a),
                 SHI(f7, f3, rd, rs1, shamt));
    endtask

    task automatic utest(input string m, input bit auipc, input int rd, input int imm20);
        clr_pre();
        run_test(m, $sformatf("%s x%0d,0x%05h", m, rd, imm20),
                 auipc ? AUIPC_(rd, imm20) : LUI_(rd, imm20));
    endtask

    task automatic ltest(input string m, input logic [2:0] f3, input int rd, input int rs1,
                         input logic [31:0] base, input int imm, input logic [31:0] word);
        logic [31:0] ea, wa;
        ea = base + 32'(imm);
        wa = {ea[31:2], 2'b00};
        clr_pre();
        pre_reg(rs1, base);
        pre_mem(wa - 32'd4, 32'h1BAD_1DEA);
        pre_mem(wa + 32'd4, 32'hC0DE_F00D);
        pre_mem(wa,         word);
        run_test(m, $sformatf("%s x%0d,%0d(x%0d)  base=0x%08h ea=0x%08h mem=0x%08h", m, rd, imm, rs1, base, ea, word),
                 LD(f3, rd, rs1, imm));
    endtask

    task automatic sttest(input string m, input logic [2:0] f3, input int rs2, input int rs1,
                          input logic [31:0] base, input int imm, input logic [31:0] val,
                          input logic [31:0] oldw);
        logic [31:0] ea, wa;
        ea = base + 32'(imm);
        wa = {ea[31:2], 2'b00};
        clr_pre();
        if (rs1 == rs2) pre_reg(rs1, base);
        else begin pre_reg(rs1, base); pre_reg(rs2, val); end
        pre_mem(wa - 32'd4, 32'h1BAD_1DEA);
        pre_mem(wa + 32'd4, 32'hC0DE_F00D);
        pre_mem(wa,         oldw);
        run_test(m, $sformatf("%s x%0d,%0d(x%0d)  base=0x%08h ea=0x%08h rs2=0x%08h mem=0x%08h",
                              m, rs2, imm, rs1, base, ea, (rs1 == rs2) ? base : val, oldw),
                 ST(f3, rs2, rs1, imm));
    endtask

    task automatic brtest(input string m, input logic [2:0] f3, input int rs1, input int rs2,
                          input logic [31:0] a, input logic [31:0] b, input int off);
        clr_pre();
        if (rs1 == rs2) pre_reg(rs1, a);
        else begin pre_reg(rs1, a); pre_reg(rs2, b); end
        run_test(m, $sformatf("%s x%0d,x%0d,%0d  rs1=0x%08h rs2=0x%08h", m, rs1, rs2, off, a,
                              (rs1 == rs2) ? a : b),
                 BR(f3, rs1, rs2, off));
    endtask

    task automatic jtest(input int rd, input int off);
        clr_pre();
        run_test("JAL", $sformatf("JAL x%0d,%0d", rd, off), JAL_(rd, off));
    endtask

    task automatic jrtest(input int rd, input int rs1, input logic [31:0] a, input int imm);
        clr_pre();
        pre_reg(rs1, a);
        run_test("JALR", $sformatf("JALR x%0d,%0d(x%0d)  rs1=0x%08h", rd, imm, rs1, a),
                 JALR_(rd, rs1, imm));
    endtask

    // ======================================================= SUITES POR GRUPO
    task automatic do_r(input string m, input logic [6:0] f7, input logic [2:0] f3);
        for (int k = 0; k < N_PAIRS; k++) rtest(m, f7, f3, 7, 5, 6, pa(k), pb(k));
        rtest(m, f7, f3, 10, 10, 11, pa(6), pb(6));            // rd == rs1
        rtest(m, f7, f3, 12, 13, 12, pa(9), pb(9));            // rd == rs2
        rtest(m, f7, f3, 14, 15, 15, 32'h89AB_CDEF, 32'h0);    // rs1 == rs2
        rtest(m, f7, f3, 0,  5,  6,  pa(6), pb(6));            // rd = x0 (no se escribe)
        rtest(m, f7, f3, 8,  0,  6,  32'h0, pb(14));           // rs1 = x0
        rtest(m, f7, f3, 8,  5,  0,  pa(14), 32'h0);           // rs2 = x0
    endtask

    task automatic suite_rtype();
        do_r("ADD",  7'h00, 3'b000);
        do_r("SUB",  7'h20, 3'b000);
        do_r("SLL",  7'h00, 3'b001);
        do_r("SLT",  7'h00, 3'b010);
        do_r("SLTU", 7'h00, 3'b011);
        do_r("XOR",  7'h00, 3'b100);
        do_r("SRL",  7'h00, 3'b101);
        do_r("SRA",  7'h20, 3'b101);
        do_r("OR",   7'h00, 3'b110);
        do_r("AND",  7'h00, 3'b111);
    endtask

    task automatic do_i(input string m, input logic [2:0] f3);
        for (int k = 0; k < N_IP; k++) itest(m, f3, 7, 5, ia(k), iimm(k));
        itest(m, f3, 10, 10, ia(8), iimm(8));                  // rd == rs1
        itest(m, f3, 0,  5,  ia(8), iimm(8));                  // rd = x0
        itest(m, f3, 8,  0,  32'h0, iimm(10));                 // rs1 = x0
    endtask

    task automatic suite_itype();
        do_i("ADDI",  3'b000);
        do_i("SLTI",  3'b010);
        do_i("SLTIU", 3'b011);
        do_i("XORI",  3'b100);
        do_i("ORI",   3'b110);
        do_i("ANDI",  3'b111);
    endtask

    task automatic do_sh(input string m, input logic [6:0] f7, input logic [2:0] f3);
        logic [31:0] av;
        for (int i = 0; i < 6; i++) begin
            case (i)
                0: av = 32'h8000_0001;  1: av = 32'hF0F0_F0F0;  2: av = 32'h0000_0001;
                3: av = 32'h7FFF_FFFF;  4: av = 32'hFFFF_FFFF;  default: av = 32'h1234_5678;
            endcase
            for (int s = 0; s < 5; s++) begin
                int sh;
                case (s) 0: sh = 0; 1: sh = 1; 2: sh = 5; 3: sh = 16; default: sh = 31; endcase
                shtest(m, f7, f3, 7, 5, av, sh);
            end
        end
        shtest(m, f7, f3, 10, 10, 32'hA5A5_A5A5, 7);           // rd == rs1
        shtest(m, f7, f3, 0,  5,  32'hA5A5_A5A5, 7);           // rd = x0
    endtask

    task automatic suite_shift_imm();
        do_sh("SLLI", 7'h00, 3'b001);
        do_sh("SRLI", 7'h00, 3'b101);
        do_sh("SRAI", 7'h20, 3'b101);
    endtask

    task automatic suite_lui_auipc();
        logic [19:0] iv;
        for (int k = 0; k < 8; k++) begin
            case (k)
                0: iv = 20'h00000;  1: iv = 20'h00001;  2: iv = 20'h12345;  3: iv = 20'h7FFFF;
                4: iv = 20'h80000;  5: iv = 20'hFFFFF;  6: iv = 20'hABCDE;  default: iv = 20'h55555;
            endcase
            utest("LUI",   0, 9, int'(iv));
            utest("AUIPC", 1, 9, int'(iv));
        end
        utest("LUI",   0, 31, 'h12345);  utest("AUIPC", 1, 31, 'h12345);
        utest("LUI",   0, 0,  'h12345);  utest("AUIPC", 1, 0,  'h12345);   // rd = x0
    endtask

    task automatic do_load(input string m, input logic [2:0] f3, input int nofs, input int step);
        for (int w = 0; w < 3; w++)
            for (int o = 0; o < nofs; o++) begin
                int off;
                off = o * step;
                ltest(m, f3, 7, 5, 32'h1100,  off,        lword(w));    // imm positivo
                ltest(m, f3, 7, 5, 32'h1200, -256 + off,  lword(w));    // imm negativo
            end
    endtask

    task automatic suite_loads();
        do_load("LB",  3'b000, 4, 1);
        do_load("LBU", 3'b100, 4, 1);
        do_load("LH",  3'b001, 2, 2);
        do_load("LHU", 3'b101, 2, 2);
        do_load("LW",  3'b010, 1, 4);
        ltest("LW",  3'b010, 5, 5, 32'h1180, 0,     32'hCAFE_BABE);    // rd == rs1
        ltest("LW",  3'b010, 0, 5, 32'h1180, 0,     32'hCAFE_BABE);    // rd = x0
        ltest("LW",  3'b010, 6, 0, 32'h0,    'h400, 32'h0123_4567);    // rs1 = x0: addr = imm
        ltest("LB",  3'b000, 6, 0, 32'h0,    'h403, 32'h89AB_CDEF);
        ltest("LHU", 3'b101, 6, 0, 32'h0,    'h402, 32'h89AB_CDEF);
        ltest("LB",  3'b000, 6, 5, 32'h1800, 2047,  32'h89AB_CDEF);    // imm maximo
        ltest("LW",  3'b010, 6, 5, 32'h1800, -2048, 32'h89AB_CDEF);    // imm minimo
        ltest("LHU", 3'b101, 6, 5, 32'h1800, 2046,  32'h89AB_CDEF);
    endtask

    task automatic do_store(input string m, input logic [2:0] f3, input int nofs, input int step);
        for (int v = 0; v < 2; v++)
            for (int o = 0; o < nofs; o++) begin
                int off;
                off = o * step;
                sttest(m, f3, 6, 5, 32'h1100,  off,       sval(v), 32'hAABB_CCDD);
                sttest(m, f3, 6, 5, 32'h1200, -256 + off, sval(v), 32'hAABB_CCDD);
            end
    endtask

    task automatic suite_stores();
        do_store("SB", 3'b000, 4, 1);
        do_store("SH", 3'b001, 2, 2);
        do_store("SW", 3'b010, 1, 4);
        sttest("SW", 3'b010, 0, 5, 32'h1100, 0,    32'h0, 32'hAABB_CCDD);   // guarda x0
        sttest("SH", 3'b001, 0, 5, 32'h1100, 2,    32'h0, 32'hAABB_CCDD);
        sttest("SB", 3'b000, 0, 5, 32'h1100, 3,    32'h0, 32'hAABB_CCDD);
        sttest("SW", 3'b010, 6, 0, 32'h0,    'h500, sval(0), 32'hAABB_CCDD); // rs1 = x0: addr = imm
        sttest("SH", 3'b001, 6, 0, 32'h0,    'h502, sval(1), 32'hAABB_CCDD);
        sttest("SB", 3'b000, 6, 0, 32'h0,    'h501, sval(0), 32'hAABB_CCDD);
        sttest("SW", 3'b010, 5, 5, 32'h1100, 0,    32'h0, 32'hAABB_CCDD);   // rs1 == rs2
        sttest("SB", 3'b000, 5, 5, 32'h1100, 1,    32'h0, 32'hAABB_CCDD);
        sttest("SW", 3'b010, 6, 5, 32'h1800, -2048, sval(0), 32'hAABB_CCDD); // imm minimo
        sttest("SB", 3'b000, 6, 5, 32'h1800, 2047,  sval(1), 32'hAABB_CCDD); // imm maximo
    endtask

    task automatic do_br(input string m, input logic [2:0] f3);
        for (int k = 0; k < N_PAIRS; k++) brtest(m, f3, 5, 6, pa(k), pb(k), bo(k % 10));
        for (int j = 0; j < 10; j++) begin                      // todos los offsets, tomado y no tomado
            brtest(m, f3, 5, 6, 32'h1234_5678, 32'h1234_5678, bo(j));
            brtest(m, f3, 5, 6, 32'h0000_0001, 32'h0000_0002, bo(j));
            brtest(m, f3, 5, 6, 32'hFFFF_FFFE, 32'h0000_0002, bo(j));
        end
        brtest(m, f3, 0, 0, 32'h0, 32'h0, 8);                   // x0 vs x0
        brtest(m, f3, 0, 6, 32'h0, 32'h5, 8);                   // rs1 = x0
        brtest(m, f3, 5, 0, 32'h5, 32'h0, 8);                   // rs2 = x0
    endtask

    task automatic suite_branches();
        do_br("BEQ",  3'b000);
        do_br("BNE",  3'b001);
        do_br("BLT",  3'b100);
        do_br("BGE",  3'b101);
        do_br("BLTU", 3'b110);
        do_br("BGEU", 3'b111);
    endtask

    task automatic suite_jal();
        for (int k = 0; k < 10; k++) jtest(1, jo(k));
        jtest(31, 8);   jtest(31, -'h40);
        jtest(0,  8);   jtest(0,  'h7C);                        // rd = x0: no se escribe
    endtask

    task automatic suite_jalr();
        jrtest(1, 5, 32'h2000, 0);
        jrtest(1, 5, 32'h2000, 4);
        jrtest(1, 5, 32'h2000, -4);
        jrtest(1, 5, 32'h2001, 0);                              // bits [1:0] se ponen a 0
        jrtest(1, 5, 32'h2002, 0);
        jrtest(1, 5, 32'h2003, 0);
        jrtest(1, 5, 32'h2000, 1);
        jrtest(1, 5, 32'h2000, 2);
        jrtest(1, 5, 32'h2000, 3);
        jrtest(1, 5, 32'h2000, 2047);
        jrtest(1, 5, 32'h2000, -2048);
        jrtest(5, 5, 32'h3000, 8);                              // rd == rs1
        jrtest(0, 1, 32'h4000, 0);                              // "ret" (rd = x0)
        jrtest(1, 0, 32'h0,    'h7FC);                          // rs1 = x0
        jrtest(31, 30, 32'hFFFF_FFFC, 8);                       // desbordamiento de 32 bits
        jrtest(31, 30, 32'h1234_5678, 'h123);
    endtask

    task automatic ign_test(input string m, input logic [31:0] w);
        clr_pre();
        pre_reg(5, 32'h1111_2222);
        pre_reg(6, 32'h3333_4444);
        run_test(m, $sformatf("%s (0x%08h)", m, w), w);
    endtask

    task automatic suite_ignored();                             // FENCE / ECALL se ignoran
        ign_test("FENCE",   32'h0000_000F);
        ign_test("FENCE",   32'h0FF0_000F);
        ign_test("FENCE.I", 32'h0000_100F);
        ign_test("ECALL",   32'h0000_0073);
        ign_test("EBREAK",  32'h0010_0073);
    endtask

    // x0 cableado a 0: antes de la instruccion se intenta escribir en x0
    task automatic suite_x0();
        poison_mode = 1;
        rtest("ADD",  7'h00, 3'b000, 8, 0, 6, 32'h0, pb(6));
        rtest("ADD",  7'h00, 3'b000, 8, 5, 0, pa(6), 32'h0);
        rtest("ADD",  7'h00, 3'b000, 8, 0, 0, 32'h0, 32'h0);
        itest("ADDI",  3'b000, 8, 0, 32'h0, 5);
        itest("SLTIU", 3'b011, 8, 0, 32'h0, 1);
        sttest("SW", 3'b010, 0, 5, 32'h1100, 0, 32'h0, 32'hFFFF_FFFF);
        brtest("BEQ", 3'b000, 0, 0, 32'h0, 32'h0, 8);
        brtest("BNE", 3'b001, 0, 5, 32'h0, pa(6), 8);
        ltest("LW", 3'b010, 8, 0, 32'h0, 'h400, 32'h0123_4567);
        jrtest(1, 0, 32'h0, 'h7FC);
        poison_mode = 0;
    endtask

    // direccionamiento del banco de registros: rd, rs1 y rs2 recorren x1..x31
    task automatic suite_regsweep();
        for (int i = 1; i <= 31; i++) begin
            int r1, r2;
            r1 = 1 + (i % 31);
            r2 = 1 + ((i + 13) % 31);
            rtest("ADD", 7'h00, 3'b000, i, r1, r2,
                  32'h1000_0000 + i * 32'h0001_0101, 32'h0000_0F0F ^ (i * 32'h0101_0001));
        end
    endtask

    task automatic run_suite();
        suite_rtype();
        suite_itype();
        suite_shift_imm();
        suite_lui_auipc();
        suite_loads();
        suite_stores();
        suite_branches();
        suite_jal();
        suite_jalr();
        suite_ignored();
        suite_x0();
        suite_regsweep();
    endtask

    function automatic int lat_of(input int i);
        case (i)
            0: return 2;
            1: return 1;
            2: return 3;
            default: return 6;
        endcase
    endfunction

    // ================================================================ PRINCIPAL
`ifdef DUMP
    initial begin
        $dumpfile("CPU_top_tb.vcd");
        $dumpvars(0, CPU_top_tb);
    end
`endif

    initial begin
        rst_n = 1'b0;
        mem_lat = 2;  txn_n = 0;  poison_mode = 0;
        tot_tests = 0;  tot_fail = 0;
        for (int i = 0; i < MEM_WORDS; i++) mem[i] = 32'h0;
        #(CLK_PERIOD * 2);

        $display("==================================================================");
        $display(" Testbench CPU_top: una prueba aislada por instruccion");
        $display("==================================================================");

        for (int li = 0; li < N_LATS; li++) begin
            mem_lat = lat_of(li);
            lat_tests = 0;  lat_fail = 0;
            $display("--- latencia de memoria = %0d ciclos ---", mem_lat);
            run_suite();
            $display("    %0d tests, %0d con fallos", lat_tests, lat_fail);
        end

        $display("==================================================================");
        $display(" %-10s %8s %8s %8s", "Instr.", "Tests", "OK", "FALLOS");
        foreach (grp_order[i])
            $display(" %-10s %8d %8d %8d", grp_order[i],
                     grp_pass[grp_order[i]] + grp_fail[grp_order[i]],
                     grp_pass[grp_order[i]], grp_fail[grp_order[i]]);
        $display("------------------------------------------------------------------");
        $display(" TOTAL: %0d tests, %0d con fallos", tot_tests, tot_fail);
        if (tot_fail == 0) $display(" TEST PASSED");
        else               $display(" TEST FAILED");
        $display("==================================================================");
        $finish;
    end

endmodule
