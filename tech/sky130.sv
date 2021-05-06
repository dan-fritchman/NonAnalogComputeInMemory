//! 
//! Tech-Specific Cell Wrappers
//! Skywater 130
//! 

//! Single-bit multiplier (NOR)
module mult1b (
    input  logic A1, A2,
    output logic ZN
);
    sky130_fd_sc_hd__nor2_1 mult1b(.A (A1), .B (A2), .Y (ZN));
endmodule

//! Single-bit full adder
module fa (
    input  logic A, B, CI, 
    output logic CO, S
);
    sky130_fd_sc_hd__fa_1 fa(.A (A), .B (B), .CIN(CI), .COUT (CO), .SUM (S));
endmodule

//! Bit-Cell-Replacement Latch
module bitcell_latch (
    input logic d, e,
    output logic q 
);
    sky130_fd_sc_hd__dlrtp lat (.Q(q), .RESET_B(1'b1), .D(d), .GATE(e));
    
endmodule

