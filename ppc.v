module main();

    integer i;
    initial begin
        $dumpfile("ppc.vcd");
        $dumpvars(0,main);
	for (i = 0; i < 32; i = i + 1) begin
            gprs[i] = 0;
        end
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
    reg [0:63]ctr = 0;
    wire [0:63]nextPC;

    always @(posedge clk) begin
        pc <= nextPC;
    end

    assign nextPC = isBranching ? branchTarget : (pc + 4);

    assign readAddr0 = pc[0:60];
    wire [0:31]inst = pc[61] ? readData0[32:63] : readData0[0:31];

    wire [0:5]op = inst[0:5];
    wire [0:8]xop9 = inst[22:30];
    wire [0:9]xop10 = inst[21:30];
    wire [0:4]rt = inst[6:10];
    wire [0:4]ra = inst[11:15];
    wire [0:4]rb = inst[16:20];
    //wire oe = inst[20:21];
    //wire rc = inst[30:31];
    wire oe = inst[21];
    wire rc = inst[31];
    wire [0:15]imm = inst[16:31];
    wire [0:63]simm = {{48{imm[0]}}, imm};
    wire [0:23]li = inst[6:29];
    wire [0:63]extendLI = {{{38{li[0]}}, li}, 2'b00};
    //wire aa = inst[29:30];
    //wire lk = inst[30:31];
    wire aa = inst[30];
    wire lk = inst[31];
    wire [0:4]bo = inst[6:10];
    wire [0:4]bi = inst[11:15];
    wire [0:13]bd = inst[16:29];
    wire [0:63]extendBD = {{{48{bd[0]}}, bd}, 2'b00};
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
    wire isBclr = (op == 19) & (xop10 == 16) & ~isLK;
    wire isBclrl = (op == 19) & (xop10 == 16) & isLK;
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
    reg [0:63]lr = 0;
    reg [0:31]cr = 0;
    reg xer = 0;

    wire [0:63]ldAddr = (ra == 0) ? extendDS : (gprs[ra] + extendDS);
    //wire [0:63]lduAddr = (ra == 0 | ra == rt) ? (pc + 4) : (gprs[ra] + extendDS);
    wire [0:63]lduAddr = gprs[ra] + extendDS;
    assign readAddr1 = isLd ? ldAddr[0:60] : lduAddr[0:60];

    //Results
    wire [0:63]addRes = gprs[ra] + gprs[rb];
    wire [0:63]orRes = (rb == 0) ? gprs[rt] : (gprs[rt] | gprs[rb]);
    wire [0:63]addiRes = (ra == 0) ? simm : (gprs[ra] + simm);
    wire [0:63]ldRes = readData1;

    //Branching
    wire [0:63]branchTarget = allB ? (isAA ? extendLI : (pc + extendLI)) : (allBc ? (isAA ? extendBD : (pc + extendBD)) : extendLR);
    wire ctr_ok = bo[2] | ((ctr != 1) ^ bo[3]);
    wire cond_ok = bo[0] | (cr[bi] == bo[1]);
    wire isBranching = allB | ((allBc | allBclr) & ctr_ok & cond_ok);

    wire updateRegs = allAdd | allOr | isAddi;
    wire updateLink = (allB & isLK) | (allBc & isLK) | (allBclr & isLK);
    wire updateCR = (allAdd & isRC) | isOrDot;
    wire updateXER = allAdd & isOE;
    wire [0:4]targetReg = isOr ? ra : rt;
    wire [0:4]targetRegLdu = ra;
    wire [0:63]targetVal = isAdd ? addRes : (isOr ? orRes : addiRes);

    wire isLess = targetVal[0];
    wire isGreater = ~targetVal[0] & targetVal != 0;
    wire isEqual = targetVal == 0;
    wire isOver = (isLess & (~gprs[ra][0] & ~gprs[rb][0])) | (isGreater & (gprs[ra][0] & gprs[rb][0]));
    //wire isOver = (targetVal[0] == targetVal[1]) ? 1 : 0;

    //System call
    wire [0:63]scNum = gprs[0];
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

    //Update conditional register
    always @(posedge clk) begin
        if (updateCR) begin
            cr[0] <= targetVal[0];
            cr[1] <= ~targetVal[0] & targetVal != 0;
            cr[2] <= targetVal == 0;
            cr[3] <= isOver | xer;
        end
    end
    /*always @(posedge clk) begin
        if (updateCR & isLess) begin
            cr[0] <= 1;
            cr[1] <= 0;
            cr[2] <= 0;
        end else if (updateCR & isGreater) begin
            cr[1] <= 1;
            cr[0] <= 0;
            cr[2] <= 0;
        end else if (updateCR & isEqual) begin
            cr[2] <= 1;
            cr[0] <= 0;
            cr[1] <= 0;
        end else if ((updateXER & isOver) | xer) begin
            cr[3] <= 1;
        end
    end*/

    //Ld, ldu
    always @(posedge clk) begin
        if (isLd) begin
            gprs[targetReg] <= ldRes;
        end else if (isLdu & ra != 0 & ra != rt) begin
            gprs[targetReg] <= ldRes;
            gprs[targetRegLdu] <= lduAddr;
        end
    end

    //Update lr
    always @(posedge clk) begin
        if (updateLink) begin
            lr <= pc + 4;
        end
    end

    //Update ctr
    always @(posedge clk) begin
        if (allBc & allBclr) begin
            ctr <= (bo[2] == 0) ? (ctr - 1) : ctr;
        end
    end

    //Update xer
    always @(posedge clk) begin
        if (updateXER) begin
            xer <= isOver | xer;
        end
    end

endmodule
