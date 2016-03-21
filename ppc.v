module main();

    initial begin
        $dumpfile("ppc.vcd");
        $dumpvars(0,main);
    end

    wire clk;

    clock clock0(clk);

    /********************/
    /* Memory interface */
    /********************/

    wire [63:3]readAddr0;
    wire [63:0]readData0;
    wire [63:3]readAddr1;
    wire [63:0]readData1;

    mem mem0(readAddr0,readData0,readAddr1,readData1);

    /*********************************/
    /* Your implementation goes here */
    /*********************************/

endmodule
