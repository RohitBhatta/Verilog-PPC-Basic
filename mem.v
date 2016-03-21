module mem(
    input [63:3] readAddr0,
    output [63:0] readData0,
    input [63:3] readAddr1,
    output [63:0] readData1);

    // memory
    reg [63:0]memory[0:1023];

    initial begin
        $readmemh("mem.bin",memory);
    end

    assign readData0 = memory[readAddr0];
    assign readData1 = memory[readAddr1];
    
endmodule
