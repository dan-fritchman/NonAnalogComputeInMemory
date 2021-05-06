module column #(
    parameter int WORDLEN = 8,      //! Weight word-length. Note input activations are always 1b, fed serially. 
    parameter int LOG2_WORDLEN = 3  //! log2(WORDLEN). Gotta calculate this offline for now
    parameter int NROWS = 64,       //! Number of rows per column. Also equals the number of inputs to the adder tree. 
    parameter int LOG2_NROWS = 6    //! log2(NROWS). Gotta calculate this offline for now
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

    // Single-Bit Multiplies 
    logic signed [NROWS-1:0][WORDLEN-1:0] products;
    always_comb begin : mult
        foreach (ia_m1[i]) begin
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

    // Accumulator 
    logic signed [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] shifted, accum;
    assign shifted = (treesum_m1 << shift);
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            accum <= 0;
            treesum_m1 <= 0;
            ia_m1 <= 0;
        end else begin 
            accum <= accum + shifted;
            treesum_m1 <= treesum;
            ia_m1 <= ia;
        end
    end
    assign sum = accum;
endmodule 

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
    generate;
        for (k=0; k<WIDTH; k=k+1) begin
            FA1D1BWP30P140LVT fa(.A (a[k]), .B (b[k]), .CI(carry[k]), .CO (carry[k+1]), .S (s[k]));
        end
    endgenerate
    // And assign the carry-out MSB
    assign s[WIDTH] = carry[WIDTH];

endmodule 

//! Column using a tree of the gate-level ripple-adders defined above, rather than synthesized adders 
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

    // Single-Bit Multiplies 
    logic signed [NROWS-1:0][WORDLEN-1:0] products;
    genvar j, k;
    generate;
        for (j=0; j<NROWS; j=j+1) begin
            for (k=0; k<WORDLEN; k=k+1) begin
                // products[i][WORDLEN-1:0] = ia_m1[i] ? weight[i][WORDLEN-1:0] : 8'b0;
                NR2OPTIBD1BWP30P140LVT mult1b(.A1 (ia_m1[j]), .A2 (weight[j][k]), .ZN (products[j][k]));
            end
        end
    endgenerate
    // always_comb begin : mult
    //     foreach (ia_m1[i]) begin
    //         products[i][WORDLEN-1:0] = ia_m1[i] ? weight[i][WORDLEN-1:0] : 8'b0;
    //     end
    // end

    // Adder Tree 
    logic signed [WORDLEN+LOG2_NROWS-1:0] treesum, treesum_m1;
    ripple_adder_tree tree (
        .summands(products),
        .sum(treesum)
    );
    
    // Accumulator 
    logic signed [WORDLEN+LOG2_NROWS+LOG2_WORDLEN-1:0] shifted, accum;
    assign shifted = (treesum_m1 << shift);
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            accum <= 0;
            treesum_m1 <= 0;
            ia_m1 <= 0;
        end else begin 
            accum <= accum + shifted;
            treesum_m1 <= treesum;
            ia_m1 <= ia;
        end
    end
    assign sum = accum;
endmodule 
