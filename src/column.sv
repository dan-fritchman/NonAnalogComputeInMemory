//! 
//! # Behavioral / Synthesizable CIM Column 
//! 
module synth_column #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int LOG2_WORDLEN = 3  //! log2(WORDLEN). Gotta calculate this offline for now
    parameter int NROWS = 64,       //! Number of rows per column. Also equals the number of inputs to the adder tree. 
    parameter int LOG2_NROWS = 6    //! log2(NROWS). Gotta calculate this offline for now
) (
    input logic signed [NROWS-1:0][WORDLEN-1:0] weight,     //! Array of weights. In reality, stored in integrated SRAM array. 
    input logic [NROWS-1:0]   ia,                           //! Bit-serial input activation 
    input logic [WORDLEN-1:0] shift,                        //! Bit-incremented accumulator shift
    input logic clock, resetn,
    output logic signed [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] sum, 
);
    // Latch the input activations, generally so that we can time them
    logic [NROWS-1:0] ia_m1;
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            ia_m1 <= 0;
        end else begin 
            ia_m1 <= ia;
        end
    end

    // Single-Bit Multiplies 
    logic signed [NROWS-1:0][WORDLEN-1:0] products;
    always_comb begin : mult
        foreach (ia_m1[i]) begin
            // FIXME: is this *always* infering a single gate? Seems maybe not! 
            products[i][WORDLEN-1:0] = ia_m1[i] ? weight[i][WORDLEN-1:0] : 8'b0;
        end
    end

    // Adder Tree 
    logic signed [WORDLEN+LOG2_NROWS-1:0] treesum, treesum_m1;
    always_comb begin : adder_tree    
        treesum = 0;
        foreach (products[i]) begin
            treesum = treesum + products[i];
        end
    end
    // Also latch its outputs 
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            treesum_m1 <= 0;
        end else begin 
            treesum_m1 <= treesum;
        end
    end

    // Shift-Accumulate Multiplier 
    col_accum #(
        .INP_WIDTH(WORDLEN),
        .OUT_WIDTH(WORDLEN+LOG2_NROWS+LOG2_WORDLEN)
    ) i_accum (
        .inp(treesum_m1),
        .shift(shift),
        .sum(sum),
        .clock(clock),
        .resetn(resetn)
    ); 
endmodule 

//! # Gate-Level Ripple Adder 
//! Parameterized by bit-width
module ripple_add #(
    parameter int WIDTH = 8        //! Input width 
) (
    input logic signed [WIDTH-1:0] a,b,     //! Primary inputs
    output logic signed [WIDTH:0] s,  //! Output, (WIDTH+1) bits wide
);  
    // Create a carry-bit array, and assign carry-in to its first entry 
    logic [WIDTH:0] carry;
    assign carry[0] = 1'b0;
    // Generate the gate-level full-adders
    genvar k;
    generate
        for (k=0; k<WIDTH; k=k+1) begin
            fa fa(.A (a[k]), .B (b[k]), .CI(carry[k]), .CO (carry[k+1]), .S (s[k]));
        end
    endgenerate
    // And assign the carry-out MSB
    assign s[WIDTH] = carry[WIDTH];

endmodule 

//! 
//! # Gate-Level Ripple-Adder-Tree Column
//! Column using a tree of the gate-level ripple-adders defined above, rather than synthesized adders 
//! 
module ripple_add_column #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int LOG2_WORDLEN = 3  //! log2(WORDLEN). Gotta calculate this offline for now
    parameter int NROWS = 128,       //! Number of rows per column. Also equals the number of inputs to the adder tree. 
    parameter int LOG2_NROWS = 7    //! log2(NROWS). Gotta calculate this offline for now
) (
    input logic signed [NROWS-1:0][WORDLEN-1:0] weight,     //! Array of weights. In reality, stored in integrated SRAM array. 
    input logic [NROWS-1:0]   ia,                           //! Bit-serial input activation 
    input logic [WORDLEN-1:0] shift,                        //! Bit-incremented accumulator shift
    input logic clock,
    input logic resetn,
    output logic signed [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] sum, 
);
    // Latch the input activations, generally so that we can time them
    logic [NROWS-1:0] ia_m1;
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            ia_m1 <= 0;
        end else begin 
            ia_m1 <= ia;
        end
    end

    // Single-Bit Multiplies 
    logic signed [NROWS-1:0][WORDLEN-1:0] products;
    genvar j, k;
    generate
        for (j=0; j<NROWS; j=j+1) begin
            for (k=0; k<WORDLEN; k=k+1) begin
                mult1b mult1b(.A1 (ia_m1[j]), .A2 (weight[j][k]), .ZN (products[j][k]));
            end
        end
    endgenerate 

    // Adder Tree 
    logic signed [WORDLEN+LOG2_NROWS-1:0] treesum, treesum_m1;
    ripple_adder_tree tree (
        .summands(products),
        .sum(treesum)
    );
    // Also latch its outputs 
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            treesum_m1 <= 0;
        end else begin 
            treesum_m1 <= treesum;
        end
    end

    // Shift-Accumulate Multiplier 
    col_accum #(
        .INP_WIDTH(WORDLEN),
        .OUT_WIDTH(WORDLEN+LOG2_NROWS+LOG2_WORDLEN)
    ) i_accum (
        .inp(treesum_m1),
        .shift(shift),
        .sum(sum),
        .clock(clock),
        .resetn(resetn)
    ); 

endmodule 

//! 
//! # Shift-and-Accumulate Multiplier
//! 
module col_accum #(
    parameter int INP_WIDTH, OUT_WIDTH 
) (
    input logic signed [INP_WIDTH-1:0] inp,  //! Primary accumulation input 
    input logic [INP_WIDTH-1:0] shift,       //! Bit-incremented accumulator shift
    input logic clock, resetn,
    output logic signed [OUT_WIDTH-1:0] sum, //! Accumulated Sum
);
    logic signed [OUT_WIDTH-1:0] shifted, accum;
    assign shifted = (inp << shift);
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            accum <= 0;
        end else begin 
            accum <= accum + shifted;
        end
    end
    assign sum = accum;
endmodule

//! 
//! # Latch-Based Bit-Cell Column
//! 
module latch_bitcell_column #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int NROWS = 128       //! Number of rows per column. 
) (
    input logic bl, //! Bit Line
    input logic [NROWS-1:0] wl, //! NROWS Word Lines 
    output logic signed [NROWS-1:0][WORDLEN-1:0] weight     //! Array of weights 
);
    genvar j, k;
    generate
        for (j=0; j<NROWS; j=j+1) begin
            for (k=0; k<WORDLEN; k=k+1) begin
                bitcell_latch i_bitcell_latch (.d(bl), .e(wl[j]), .q(weight[j][k]));
            end
        end
    endgenerate 

endmodule 

module array3 #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int LOG2_WORDLEN = 3  //! log2(WORDLEN). Gotta calculate this offline for now
    parameter int NROWS = 128,       //! Number of rows per column. Also equals the number of inputs to the adder tree. 
    parameter int LOG2_NROWS = 7    //! log2(NROWS). Gotta calculate this offline for now
    parameter int NCOLS = 128       //! Number of cols
    parameter int LOG2_NCOLS = 7    //! log2(NCOLS). Gotta calculate this offline for now
) (
    input logic [NCOLS-1:0] bl, //! Bit Lines
    input logic [NROWS-1:0] wl, //! Word Lines
    input logic [NROWS-1:0]   ia,                           //! Bit-serial input activation 
    input logic [WORDLEN-1:0] shift,                        //! Bit-incremented accumulator shift
    input logic clock, resetn,
    output logic signed [NCOLS-1:0] [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] sums, 
);

    // Latch the input activations, generally so that we can time them
    logic [NROWS-1:0] ia_m1;
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            ia_m1 <= 0;
        end else begin 
            ia_m1 <= ia;
        end
    end

    logic signed [NCOLS-1:0][NROWS-1:0][WORDLEN-1:0] weights;
    genvar j, k;
    generate
        for (k=0; k<NCOLS; k=k+1) begin
            latch_bitcell_column #(
                .WORDLEN(WORDLEN), .NROWS(NROWS)
            ) i_latch_bitcell_column (
                .bl(bl[k]), .wl(wl), .weight(weights[k][NROWS-1:0][WORDLEN-1:0])
            );
            column3 #(
                .WORDLEN(WORDLEN), 
                .NROWS(NROWS),
                .LOG2_NROWS(LOG2_NROWS)
            ) i_column (
                .weight(weights[k][NROWS-1:0][WORDLEN-1:0]),
                .ia(ia_m1),
                .shift(shift),
                .clock(clock),
                .resetn(resetn),
                .sum(sums[k][WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0])
            );
        end
    endgenerate 
    
endmodule

//! 
//! # Another Gate-Level Ripple-Adder-Tree Column
//! This time without the individual latching of a handful of things 
//! 
module column3 #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int LOG2_WORDLEN = 3  //! log2(WORDLEN). Gotta calculate this offline for now
    parameter int NROWS = 128,       //! Number of rows per column. Also equals the number of inputs to the adder tree. 
    parameter int LOG2_NROWS = 7    //! log2(NROWS). Gotta calculate this offline for now
) (
    input logic signed [NROWS-1:0][WORDLEN-1:0] weight,     //! Array of weights. In reality, stored in integrated SRAM array. 
    input logic [NROWS-1:0]   ia,                           //! Bit-serial input activation 
    input logic [WORDLEN-1:0] shift,                        //! Bit-incremented accumulator shift
    input logic clock,
    input logic resetn,
    output logic signed [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] sum, 
);
    // Single-Bit Multiplies 
    logic signed [NROWS-1:0][WORDLEN-1:0] products;
    genvar j, k;
    generate
        for (j=0; j<NROWS; j=j+1) begin
            for (k=0; k<WORDLEN; k=k+1) begin
                mult1b mult1b(.A1 (ia[j]), .A2 (weight[j][k]), .ZN (products[j][k]));
            end
        end
    endgenerate 

    // Adder Tree 
    logic signed [WORDLEN+LOG2_NROWS-1:0] treesum, treesum_m1;
    ripple_adder_tree tree (
        .summands(products),
        .sum(treesum)
    );
    // Also latch its outputs 
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin 
            treesum_m1 <= 0;
        end else begin 
            treesum_m1 <= treesum;
        end
    end

    // Shift-Accumulate Multiplier 
    col_accum #(
        .INP_WIDTH(WORDLEN),
        .OUT_WIDTH(WORDLEN+LOG2_NROWS+LOG2_WORDLEN)
    ) i_accum (
        .inp(treesum_m1),
        .shift(shift),
        .sum(sum),
        .clock(clock),
        .resetn(resetn)
    ); 

endmodule 
