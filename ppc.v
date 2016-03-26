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

    wire [0:60]readAddr0;
    wire [0:63]readData0;
    wire [0:60]readAddr1;
    wire [0:63]readData1;
    
    mem mem0(readAddr0,readData0,readAddr1,readData1);

    /*********************************/
    /* Your implementation goes here */
    /*********************************/
    reg [0:63]pc = 0;
    wire [0:63]nextPC;

    always @(posedge clk) begin
        pc <= nextPC;
    end

    assign nextPC = isBranching ? branchTarget : pc + 4;

    assign readAddr0 = pc[0:60];
    wire [0:31]inst = pc[61] ? readData0[32:63] : readData0[0:31];

    wire [0:5]op = inst[0:5];
    wire [0:8]xop9 = inst[22:30];
    wire [0:9]xop10 = inst[21:30];
    wire [0:4]rt = inst[6:10];
    wire [0:4]ra = inst[11:15];
    wire [0:4]rb = inst[16:20];
    wire oe = inst[20:21];
    wire rc = inst[30:31];
    wire [0:15]imm = inst[16:31];
    wire [0:63]simm = {{48{imm[0]}}, imm};
    wire [0:23]li = inst[6:29];
    wire [0:63]extendLI = {{40{li[0]}}, li};
    wire aa = inst[29:30];
    wire lk = inst[30:31];
    wire [0:4]bo = inst[6:10];
    wire [0:4]bi = inst[6:10];
    wire [0:13]bd = inst[16:29];
    wire [0:63]extendBD = {{{48{bd[0]}}, bd[0:13]}, 2'b00};
    wire [0:13]ds = inst[16:29];
    wire [0:63]extendDS = {{{48{ds[0]}}, ds}, 2'b00};
    wire [0:63]extendLR = {lr[0:61], 2'b00};

    //Mnemonic specifics
    wire isOE = oe;
    wire isRC = rc;
    wire isAA = aa;
    wire isLK = lk;

    //Instructions
    wire isAdd = (op == 31) & (xop9 == 266) & ~isOE & ~isRC;
    wire isAddDot = (op == 31) & (xop9 == 266) & ~isOE & isRC;
    wire isAddO = (op == 31) & (xop9 == 266) & isOE & ~isRC;
    wire isAddODot = (op == 31) & (xop9 == 266) & isOE & isRC;
    wire isOr = (op == 31) & (xop10 == 444) & ~isRC;
    wire isOrDot = (op == 31) & (xop10 == 444) & isRC;
    wire isAddi = op == 14;
    wire isB = (op == 18) & ~isAA & ~isLK;
    wire isBa = (op == 18) & isAA & ~isLK;
    wire isBl = (op == 18) & ~isAA & isLK;
    wire isBla = (op == 18) & isAA & isLK;
    wire isBc = (op == 16) & ~isAA & ~isLK;
    wire isBca = (op == 16) & isAA & ~isLK;
    wire isBcl = (op == 16) & ~isAA & isLK;
    wire isBcla = (op == 16) & isAA & isLK;
    wire isBclr = (op == 19) & ~isLK;
    wire isBclrl = (op == 19) & isLK;
    wire isLd = (op == 58) & ~isLK;
    wire isLdu = (op == 58) & isLK;
    wire isSc = op == 17;
    wire isNone = ~(allAdd | allOr | isAddi | allB | allBc | allBclr | isLd | isLdu | isSc); //Unexpected instruction

    //Combined instructions
    wire allAdd = isAdd | isAddDot | isAddO | isAddODot;
    wire allOr = isOr | isOrDot;
    wire allB = isB | isBa | isBl | isBla;
    wire allBc = isBc | isBca | isBcl | isBcla;
    wire allBclr = isBclr | isBclrl;

    //2D Array of registers
    reg [0:63]gprs[0:31];

    //Special purpose registers
    reg [0:63]lr;
    reg [0:3]cr;

    wire [0:63]ldAddr = (ra == 0) ? extendDS : (gprs[ra] + extendDS);
    wire [0:63]lduAddr = (ra == 0 | ra == rt) ? (pc + 4) : (gprs[ra] + extendDS);
    assign readAddr1 = isLd ? ldAddr[0:60] : lduAddr[0:60];

    //Results
    wire [0:63]addRes = gprs[ra] + gprs[rb];
    wire [0:63]orRes = gprs[rt] | gprs[rb];
    wire [0:63]addiRes = (ra == 0) ? simm : (gprs[ra] + simm);
    wire [0:63]ldRes = readData1;

    //Branching
    wire [0:63]branchTarget = allBc ? (isAA ? (pc + extendBD) : extendBD) : (allB ? ((isAA ? (pc + extendLI) : extendLI)) : extendLR);
    wire less = (bo == 1 & bi == 0 & cr != 8) | (bo == 3 & bi == 0 & cr ==8);
    wire greater = (bo == 1 & bi == 1 & cr != 4) | (bo == 3 & bi == 1 & cr == 4);
    wire equals = (bo == 1 & bi == 2 & cr != 2) | (bo == 3 & bi == 1 & cr == 2);
    wire isBranching = allB | (allBc & (less | greater | equals)) | (allBclr & (less | greater | equals));

    wire updateRegs = allAdd | allOr | isAddi | isLd | isLdu;
    wire updateLink = (allB & isLK) | (allBc & isLK) | (allBclr & isLK);
    //Fix this line
    //Take into account ldu which updates both ra and rt
    wire [0:4]targetReg = isOr ? ra : rt;
    wire [0:4]targetRegLdu = ra;
    wire [0:63]targetVal;
    wire [0:63]targetValLdu;
    wire [0:63]targetLink = pc + 4;

    /*always @(posedge clk) begin
        if (isAdd) begin
            $display ("add");
            targetVal <= gprs[ra] + gprs[rb];
        end else if (isAddDot) begin
            $display ("add.");
            targetVal <= gprs[ra] + gprs[rb];
            //Update cr
        end else if (isAddO) begin
            $display ("addo");
            targetVal <= gprs[ra] + gprs[rb];
            //Update xer
        end else if (isAddODot) begin
            targetVal <= gprs[ra] + gprs[rb];
            $display ("addo.");
            //Update cr and xer
        end else if (isOr) begin
            targetVal <= gprs[rt] | gprs[rb];
            $display ("or");
        end else if (isOrDot) begin
            targetVal <= gprs[rt] | gprs[rb];
            $display ("or.");
            //Update cr 
        end else if (isAddi) begin
            //Make sure to sign extend simm
            $display ("addi");
            $display (ra);
            $display (gprs[ra]);
            $display (addr);
            targetVal <= gprs[ra] + simm;
        end else if (isB) begin
            branchTarget <= pc + addr;
            $display ("b");
        end else if (isBa) begin
            branchTarget <= addr;
            $display ("ba");
        end else if (isBl) begin
            branchTarget <= pc + addr;
            $display ("bl");
            targetLink <= pc + 4;
        end else if (isBla) begin
            branchTarget <= addr;
            $display ("bla");
            targetLink <= pc + 4;
        end else if (isBc) begin
            //Do stuff here
            $display ("bc");
        end else if (isBca) begin
            //Do stuff here
            $display ("bca");
        end else if (isBcl) begin
            //Do stuff here
            $display ("bcl");
        end else if (isBcla) begin
            //Do stuff here
            $display ("bcla");
        end else if (isBclr) begin
            //Do stuff here
            $display ("bclr");
        end else if (isBclrl) begin
            //Do stuff here
            $display ("bclrl");
        end else if (isLd) begin
            //Do stuff here
            $display ("ld");
        end else if (isLdu) begin
            //Do stuff here
            $display ("ldu");
        end else if (isSc) begin
            //Do stuff here
            $display ("sc");
        end
    end*/

    //Sign extend li by 2 bits
    /*always @(posedge clk) begin
        addr[0:25] <= {li[0:23], 2'b00};
    end*/

    //Add, or, addi
    assign targetVal = isAdd ? addRes : (isOr ? orRes : addiRes);

    //System call
    wire [0:63]scNum = gprs[0];
    //Change to ASCII character
    wire [0:7]print0 = gprs[3][56:63];
    wire [0:63]print2 = gprs[3];

    always @(posedge clk) begin
        if (isSc & scNum == 0) begin
            $display("%c", print0);
        end else if (isSc & scNum == 1) begin
            $finish;
        end else if (isSc & scNum == 2) begin
            $display("%h", print2);
        end
    end    
    
    //Update target register
    always @(posedge clk) begin
        if (updateRegs) begin
            gprs[targetReg] <= targetVal;
        end
    end

    //Ld, ldu
    always @(posedge clk) begin
        if (isLd) begin
            gprs[targetReg] <= ldRes;
        end else if (isLdu) begin
            gprs[targetReg] <= ldRes;
            gprs[targetRegLdu] <= targetValLdu;
        end
    end

    //Update lr
    always @(posedge clk) begin
        if (updateLink) begin
            lr <= targetLink;
        end
    end

endmodule
