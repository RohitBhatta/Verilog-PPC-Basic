module clock(
    output clk
);

    //
    // The clock -- sumulation only
    //
    reg theClock = 0;

    assign clk = theClock;

    always begin
        #1;
        theClock = ~clk;
    end

    // cycle counter
    reg [15:0]cycles = 0;

    always @(posedge clk) begin
        if (cycles == 1000) begin
            $display("ran for 1000 cycles");
            $finish;
        end
        cycles <= cycles + 1;
    end

endmodule
