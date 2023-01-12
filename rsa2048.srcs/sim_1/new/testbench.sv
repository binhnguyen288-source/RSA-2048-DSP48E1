`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/11/2023 11:46:21 PM
// Design Name: 
// Module Name: testbench
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


`define Np 1024'h1137cf13778c5ea7f113b840f57bd8a8b9e6a0680386c9da1400fce73192c3ce66ea84a080ed16323ecfd5c17daaf118574f6634ad143c51867c04d1e9fdc6738b7905276b072cfd311afb790c0e080e009ab3cbdaf84edc1c6100ed13e37a873358f0a7e97669b2f932393aaf1ce6dd11a61a3d557c76ca7c0e65ca3815e9f3
`define N 1024'hf9e774504f55c359e3f505e3c09353585afb7060908942ce199fb74ecb03ecacb57c074c7b6ccca6f42521abb63e5a52c23105143dc40eae9bba07ca669267bf22aa2301ba8fd323f4b9b52f7cf93d28bab96abf0d0d808f7ec3e8f04d54bc656fa2b4f964dd076afa93ac39be13f9e00d3315a3c87e681015995b08b35728c5
`define oneMont 1024'h6188bafb0aa3ca61c0afa1c3f6caca7a5048f9f6f76bd31e66048b134fc13534a83f8b3849333590bdade5449c1a5ad3dcefaebc23bf1516445f835996d9840dd55dcfe45702cdc0b464ad08306c2d745469540f2f27f70813c170fb2ab439a905d4b069b22f895056c53c641ec061ff2ccea5c378197efea66a4f74ca8d73b
module mulmodexpected(input[1023:0] a, input[1023:0] b, output[1023:0] out);
    wire[2047:0] T = a * b;
    wire[1023:0] m = T[1023:0] * `Np;
    wire[2047:0] mN = m * `N;
    wire[2048:0] num = T + mN;
    wire[1024:0] upper = num[2048:1024];
    assign out = upper < `N ? upper : upper - `N;
endmodule


module powmodexpected(input[1023:0] m, output bit[1023:0] signature);
    parameter[1023:0] expo = 1024'hddfed7fa879f5e1c3a3e6d6ef6a1694671fc2ec5f95f95b2d45c67505d542d28f747288cae8fe5f4e1a922921120aec819adc61f4707252bc336acb9060944942c4d0b2ffbf4cbd183127d7ba3ff1c6f5400666d35412b554d7ce72ea0e387406cbd131b0098c0802dfc84dffe946c42b6370d202378f72462ab8a8cde13ad29;
    
    
    function automatic [1023:0] mulmodfunc;
        input[1023:0] a, b;
        bit[2047:0] T;
        bit[1023:0] m;
        bit[2047:0] mN;
        bit[2048:0] num;
        bit[1024:0] upper;
        begin
            T = a * b;
            m = T[1023:0] * `Np;
            mN = m * `N;
            num = T + mN;
            upper = num[2048:1024];
            mulmodfunc = upper < `N ? upper : upper - `N;
        end
    endfunction
    
    
    integer i;
    bit[1023:0] base;
    
    always_comb begin
        base = m;
        signature = `oneMont;
        for (i = 0; i < 4; i = i + 1) begin
            if (expo[i]) signature = mulmodfunc(signature, base);
            base = mulmodfunc(base, base);
        end
        
    end
endmodule


module testbench();
        
    bit clk = 1'b0;
    always #5 clk = ~clk;
    bit[1023:0] a = 0;
    
    wire[1023:0] expected;
    powmodexpected test(.m(a), .signature(expected));

    wire[1023:0] mul_out;
    wire done;
    powmod multiplier(.rst(done), .clk(clk), .m(a), .out(mul_out), .done(done));
    
    
    
    genvar i;
    generate
        for (i = 0; i < 1024; i = i + 32) begin
            always_ff @(posedge clk) begin
                if (done) begin
                    //a[i+:32] <= $random;
                    a <= 1024'h2;
                end
            end
        end
    endgenerate
    
    
    bit[15:0] counter = 0;
    bit[15:0] count_errors = 0;
    
    always_ff @(posedge clk) begin
        counter <= counter + 1;
        if (done) begin
            if (expected !== mul_out) begin
                count_errors <= count_errors + 1;
            end
        end
    end
endmodule

