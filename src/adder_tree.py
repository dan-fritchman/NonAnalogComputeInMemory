""" 
High-tech scripting to create verilog for a binary adder tree, 
consisting of custom (Verilog-parameterizable) adder modules. """

import numpy as np

log = lambda x: int(np.log2(x))

ADDERNAME = "ripple_add"
INPUTNAME = "summands"
OUTPUTNAME = "sum"
WORDLEN = 8
NROWS = 64
LOG2_NROWS = log(NROWS)

rv = ""
# Declare the module and port-list
rv += f"module ripple_adder_tree ( \n"
rv += f"    input logic signed [{NROWS-1}:0][{WORDLEN-1}:0] {INPUTNAME}, \n"
rv += f"    output logic signed [{WORDLEN+LOG2_NROWS-1}:0] {OUTPUTNAME} \n"
rv += f"); \n"

rv += f"// WORDLEN={WORDLEN} NROWS={NROWS} \n"
rv += f"logic signed [{NROWS-1}:0][{WORDLEN-1}:0] layer0out; // Alias for our input \n"

# Create each layer, starting from the inputs
for layer in range(1, log(NROWS) + 1):
    num_inputs = int(NROWS / (2 ** (layer - 1)))
    num_outputs = num_inputs // 2

    # Declare its output signal
    # The last stage defines a single word instead of a bus of them
    if num_outputs > 1:
        output_signal = f"[{num_outputs-1}:0] [{WORDLEN+layer-1}:0] layer{layer}out"
    else:
        output_signal = f"[{WORDLEN+layer-1}:0] layer{layer}out"
    rv += f"logic signed {output_signal}; \n"

    # Declare all of the adder instances
    for pair in range(num_inputs // 2):
        rv += (
            f"{ADDERNAME} #(.WIDTH({WORDLEN+layer-1})) ra_layer{layer}_pair{pair} ( \n"
        )
        rv += f"    .a(layer{layer-1}out[{2*pair}][{WORDLEN+layer-2}:0]), \n"
        rv += f"    .b(layer{layer-1}out[{2*pair+1}][{WORDLEN+layer-2}:0]), \n"

        # Wire up the output, which can be in a few forms
        if num_outputs > 1:
            rv += f"    .s(layer{layer}out[{pair}][{WORDLEN+layer-1}:0])"
        else:
            rv += f"    .s(layer{layer}out[{WORDLEN+layer-1}:0])"

        # Dont forget this!
        rv += f"); \n"

# Finally wire up the input and output signals
rv += f"assign layer0out = {INPUTNAME}; \n"
rv += f"assign {OUTPUTNAME} = layer{layer}out [{WORDLEN+LOG2_NROWS-1}:0]; \n"
rv += f"endmodule \n"

print(rv)
