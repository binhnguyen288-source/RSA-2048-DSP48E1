`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/11/2023 11:39:05 PM
// Design Name: 
// Module Name: powmod
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module mul1024x1024(
    input rst,
    input clk,
    input[1023:0] a,
    input[1023:0] b,
    output[2047:0] out,
    output done
);
    
    reg[526:0] loA = 527'd0;
    reg[527:0] loB = 528'd0;
    reg[526:0] hiA = 527'd0;
    reg[527:0] hiB = 528'd0;
    reg[526:0] miA = 527'd0;
    reg[527:0] miB = 528'd0;
    
    
    reg[1054:0] z2;
    reg[1054:0] z0;
    reg[1054:0] z1;
    
    
    
    reg[9:0] base_mult      = 10'd528;
    reg[9:0] base_mult_prev = 10'd528;
    
    wire[550:0] outmulz0, outmulz1, outmulz2;
    mulx24 #(.widtha17(31)) submulz0(.clk(clk), .rst(1'b0), .a(loA), .b(loB[base_mult+:24]), .out(outmulz0));
    mulx24 #(.widtha17(31)) submulz1(.clk(clk), .rst(1'b0), .a(miA), .b(miB[base_mult+:24]), .out(outmulz1));
    mulx24 #(.widtha17(31)) submulz2(.clk(clk), .rst(1'b0), .a(hiA), .b(hiB[base_mult+:24]), .out(outmulz2));
    
    localparam INIT = 0,
               SETUP = 1,
               CALC = 2,
               FINAL = 3;
    reg[3:0] state = FINAL;
    reg[3:0] nextstate;
    always @(*) begin
        case (state)
            INIT: nextstate = SETUP;
            SETUP: nextstate = CALC;
            CALC: nextstate = base_mult_prev == 10'd504 ? FINAL : CALC;
            default: nextstate = FINAL;
        endcase
       nextstate = rst ? INIT : nextstate;
    end
    
    
    always @(posedge clk) begin
        state <= nextstate;
        if (state == INIT) begin
            z2 <= 0;
            z1 <= 0;
            z0 <= 0;
          
            // loA <= 0;
            // loB <= 0;
            // hiA <= 0;
            // hiB <= 0;
            // miA <= 0;
            // miB <= 0;
            
 
            base_mult <= 0;
            base_mult_prev <= 0;
        end
        if (state == SETUP) begin
                       
            loA[511:0] <= a[511:0];
            loB[511:0] <= b[511:0];
            hiA[511:0] <= a[1023:512];
            hiB[511:0] <= b[1023:512];
            miA[512:0] <= a[511:0] + a[1023:512];
            miB[512:0] <= b[511:0] + b[1023:512];
        end
        if (state == CALC) begin
            if (base_mult != 0) begin
                z2[base_mult_prev+:551] <= z2[base_mult_prev+:527] + outmulz2;
                z1[base_mult_prev+:551] <= z1[base_mult_prev+:527] + outmulz1;
                z0[base_mult_prev+:551] <= z0[base_mult_prev+:527] + outmulz0;
            end
            base_mult <= base_mult + 24;
            base_mult_prev <= base_mult;
        end
    end
    
    wire[1024:0] mid = z1[1025:0] - z0[1023:0] - z2[1023:0];
    wire[2048:0] addout;
    adder2048 finaladd(.clk(clk), .a({z2[1023:0], z0[1023:0]}), .b({{511{1'b0}}, mid, {512{1'b0}}}), .c(addout), .cin(1'b0));
    assign out = addout[2047:0];
    assign done = state == FINAL;
endmodule



module mulmod(
    input rst,
    input clk,
    input[1023:0] a,
    input[1023:0] b,
    output[1023:0] out,
    output done
);
    reg[1023:0] regout = 1024'd0;
    parameter[1023:0] Np = 1024'h1137cf13778c5ea7f113b840f57bd8a8b9e6a0680386c9da1400fce73192c3ce66ea84a080ed16323ecfd5c17daaf118574f6634ad143c51867c04d1e9fdc6738b7905276b072cfd311afb790c0e080e009ab3cbdaf84edc1c6100ed13e37a873358f0a7e97669b2f932393aaf1ce6dd11a61a3d557c76ca7c0e65ca3815e9f3;
    parameter[1023:0] N  = 1024'hf9e774504f55c359e3f505e3c09353585afb7060908942ce199fb74ecb03ecacb57c074c7b6ccca6f42521abb63e5a52c23105143dc40eae9bba07ca669267bf22aa2301ba8fd323f4b9b52f7cf93d28bab96abf0d0d808f7ec3e8f04d54bc656fa2b4f964dd076afa93ac39be13f9e00d3315a3c87e681015995b08b35728c5;
    localparam[2047:0] notN = ~{1024'h0, N};
    reg[1023:0] mulopA;
    reg[1023:0] mulopB;
    wire[2047:0] mulRes;
    wire mulrst;
    wire muldone;
    mul1024x1024 mulblock(.rst(mulrst), .clk(clk), .a(mulopA), .b(mulopB), .out(mulRes), .done(muldone));
    
    reg[2047:0] addopA;
    reg[2047:0] addopB;
    reg addcin;
    wire[2048:0] addRes;// = addopA + addopB + addcin;
    adder2048 addblock(.clk(clk), .a(addopA), .b(addopB), .c(addRes), .cin(addcin));

    typedef enum {
        CALC_T, // T = a * b
        CALC_m, // m = T[1023:0] * Np
        CALC_mN, // mN = m * N
        CALC_num, // num = T + mN
        CALC_out, // upper = num[2048:1024]; out = upper < N ? upper : upper - N
        CALC_DONE
    } STATE;
    
    
    STATE state = CALC_DONE;
    STATE nextstate;     
    reg[2047:0] T = 0;
    reg[1023:0] m = 0;
    reg[2047:0] mN = 0;
    reg[2048:0] num = 0;
    always_comb begin
        case (state)
            CALC_T: {mulopA, mulopB} = {a, b};
            CALC_m: {mulopA, mulopB} = {T[1023:0], Np};
            CALC_mN: {mulopA, mulopB} = {m, N};
            default: {mulopA, mulopB} = {2048{1'b0}};
        endcase
    end
    
    
    always_comb begin
        case (state)
            CALC_num: {addcin, addopA, addopB} = {1'b0, T, mN};
            CALC_out: {addcin, addopA, addopB} = {1'b1, {1023'h0, num[2048:1024]}, notN};
            default: {addcin, addopA, addopB} = {4097{1'b0}};
        endcase
    end
    
    always_comb begin
        case (state)
            CALC_T: nextstate = muldone ? CALC_m : CALC_T;
            CALC_m: nextstate = muldone ? CALC_mN : CALC_m;
            CALC_mN: nextstate = muldone ? CALC_num : CALC_mN;
            CALC_num: nextstate = CALC_out;
            CALC_out: nextstate = CALC_DONE;
            CALC_DONE: nextstate = CALC_DONE;
            default: nextstate = CALC_DONE;
        endcase
        nextstate = rst ? CALC_T : nextstate;
    end
        
    always_ff @(posedge clk) begin
        state <= nextstate;
        case (state)
            CALC_T: if (muldone) T <= mulRes;
            CALC_m: if (muldone) m <= mulRes[1023:0];
            CALC_mN: if (muldone) mN <= mulRes;
            CALC_num: num <= addRes;
            CALC_out: regout <= addRes[1024] ? num[2047:1024] : addRes[1023:0];
            default: ;
        endcase
    end
    assign mulrst = state != nextstate;
    assign out = regout;
    assign done = state == CALC_DONE; 
endmodule

module powmod(
    input rst,
    input clk,
    input[1023:0] m,
    output[1023:0] out,
    output done
);
    parameter[1023:0] expo = 1024'hddfed7fa879f5e1c3a3e6d6ef6a1694671fc2ec5f95f95b2d45c67505d542d28f747288cae8fe5f4e1a922921120aec819adc61f4707252bc336acb9060944942c4d0b2ffbf4cbd183127d7ba3ff1c6f5400666d35412b554d7ce72ea0e387406cbd131b0098c0802dfc84dffe946c42b6370d202378f72462ab8a8cde13ad29;
    parameter[1023:0] mont_one = 1024'h6188bafb0aa3ca61c0afa1c3f6caca7a5048f9f6f76bd31e66048b134fc13534a83f8b3849333590bdade5449c1a5ad3dcefaebc23bf1516445f835996d9840dd55dcfe45702cdc0b464ad08306c2d745469540f2f27f70813c170fb2ab439a905d4b069b22f895056c53c641ec061ff2ccea5c378197efea66a4f74ca8d73b;
    parameter expo_bits = 4;
    reg[1023:0] signature = 1024'd0;
    reg[15:0] idx = expo_bits;
    reg[1023:0] base = 1024'd0;
    wire[1023:0] next_acc;
    wire[1023:0] next_base;
    wire done_iteration;
    mulmod accumulate(.rst(done_iteration && idx != expo_bits), .clk(clk), .a(signature), .b(base), .out(next_acc), .done(done_iteration));
    mulmod basesquare(.rst(done_iteration && idx != expo_bits), .clk(clk), .a(base), .b(base), .out(next_base), .done());
    always @(posedge clk) begin
        if (rst) begin
            idx <= 0;
            base <= m;
            signature <= mont_one;
        end else if (idx != expo_bits) begin
            if (done_iteration) begin
                signature <= expo[idx] ? next_acc : signature;
                base      <= next_base;
                idx       <= idx + 1;
            end
        end
    end
    assign out = signature;
    assign done = idx == expo_bits;
    
endmodule
