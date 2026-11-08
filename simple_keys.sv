module simple_keys(
    input reset,

    input [10:0] ps2_key,

    output [8:0]    ps2_scancode,
    output          ps2_toggle,
    output reg      ps2_ready,
    output reg[7:0] ascii_code,
    output reg      ascii_ready,
    output reg      arrow_left,
    output reg      arrow_right,
    output reg      arrow_up,
    output reg      arrow_down
);


// Based on: https://github.com/vadixidav/ps2_ascii/blob/master/scancode_ascii.v

function logic [7:0] scancode_to_ascii (input [7:0] scan_code, logic shift_mode);
    case (scan_code)
        8'h1C: scancode_to_ascii = shift_mode ? "A" : "a";
        8'h32: scancode_to_ascii = shift_mode ? "B" : "b";
        8'h21: scancode_to_ascii = shift_mode ? "C" : "c";
        8'h23: scancode_to_ascii = shift_mode ? "D" : "d";
        8'h24: scancode_to_ascii = shift_mode ? "E" : "e";
        8'h2B: scancode_to_ascii = shift_mode ? "F" : "f";
        8'h34: scancode_to_ascii = shift_mode ? "G" : "g";
        8'h33: scancode_to_ascii = shift_mode ? "H" : "h";
        8'h43: scancode_to_ascii = shift_mode ? "I" : "i";
        8'h3B: scancode_to_ascii = shift_mode ? "J" : "j";
        8'h42: scancode_to_ascii = shift_mode ? "K" : "k";
        8'h4B: scancode_to_ascii = shift_mode ? "L" : "l";
        8'h3A: scancode_to_ascii = shift_mode ? "M" : "m";
        8'h31: scancode_to_ascii = shift_mode ? "N" : "n";
        8'h44: scancode_to_ascii = shift_mode ? "O" : "o";
        8'h4D: scancode_to_ascii = shift_mode ? "P" : "p";
        8'h15: scancode_to_ascii = shift_mode ? "Q" : "q";
        8'h2D: scancode_to_ascii = shift_mode ? "R" : "r";
        8'h1B: scancode_to_ascii = shift_mode ? "S" : "s";
        8'h2C: scancode_to_ascii = shift_mode ? "T" : "t";
        8'h3C: scancode_to_ascii = shift_mode ? "U" : "u";
        8'h2A: scancode_to_ascii = shift_mode ? "V" : "v";
        8'h1D: scancode_to_ascii = shift_mode ? "W" : "w";
        8'h22: scancode_to_ascii = shift_mode ? "X" : "x";
        8'h35: scancode_to_ascii = shift_mode ? "Y" : "y";
        8'h1A: scancode_to_ascii = shift_mode ? "Z" : "z";
        8'h45: scancode_to_ascii = shift_mode ? ")" : "0";
        8'h16: scancode_to_ascii = shift_mode ? "!" : "1";
        8'h1E: scancode_to_ascii = shift_mode ? "@" : "2";
        8'h26: scancode_to_ascii = shift_mode ? "#" : "3";
        8'h25: scancode_to_ascii = shift_mode ? "$" : "4";
        8'h2E: scancode_to_ascii = shift_mode ? 8'h25 : "5";    // shift 5: %
        8'h36: scancode_to_ascii = shift_mode ? "^" : "6";
        8'h3D: scancode_to_ascii = shift_mode ? "&" : "7";
        8'h3E: scancode_to_ascii = shift_mode ? "*" : "8";
        8'h46: scancode_to_ascii = shift_mode ? "(" : "9";
        8'h0E: scancode_to_ascii = shift_mode ? "~" : "`";
        8'h4E: scancode_to_ascii = shift_mode ? "_" : "-";
        8'h55: scancode_to_ascii = shift_mode ? "+" : "=";
        8'h5D: scancode_to_ascii = shift_mode ? "|" : 8'h5c;   // backslash
        8'h66: scancode_to_ascii = 8'h08;   // Backspace
        8'h29: scancode_to_ascii = 8'h20;   // Space
        8'h0D: scancode_to_ascii = 8'h09;   // TAB
        8'h5A: scancode_to_ascii = 8'd10;   // ENTER
        8'h76: scancode_to_ascii = 8'h1B;   // ESC
        8'h54: scancode_to_ascii = shift_mode ? "{" : "[";
        8'h7C: scancode_to_ascii = "*";
        8'h7B: scancode_to_ascii = "-";
        8'h79: scancode_to_ascii = "+";
        8'h71: scancode_to_ascii = ".";
        8'h70: scancode_to_ascii = "0";
        8'h69: scancode_to_ascii = "1";
        8'h72: scancode_to_ascii = "2";
        8'h7A: scancode_to_ascii = "3";
        8'h6B: scancode_to_ascii = "4";
        8'h73: scancode_to_ascii = "5";
        8'h74: scancode_to_ascii = "6";
        8'h6C: scancode_to_ascii = "7";
        8'h75: scancode_to_ascii = "8";
        8'h7D: scancode_to_ascii = "9";
        8'h5B: scancode_to_ascii = shift_mode ? "}" : "]";
        8'h4C: scancode_to_ascii = shift_mode ? ":" : ";";
        8'h52: scancode_to_ascii = shift_mode ? "\"" : "'";
        8'h41: scancode_to_ascii = shift_mode ? "<" : ",";
        8'h49: scancode_to_ascii = shift_mode ? ">" : ".";
        8'h4A: scancode_to_ascii = "/";
        default: scancode_to_ascii = scan_code;
    endcase
endfunction

wire		ps2_action;
wire        ps2_extkey;

assign ps2_scancode = ps2_key[8:0];     // [7:0] : PS/2 (set 2) scan code
assign ps2_extkey = ps2_key[8];         // 1 = extended key (was prefixed by 0xE0)
assign ps2_action = ps2_key[9];         // 1 = key pressed, 0 = key released
assign ps2_toggle = ps2_key[10];        // flips on every press or release event

reg shift_state;
reg shift_L = 1'b0;
reg shift_R = 1'b0;

assign shift_state = shift_L | shift_R;

always_ff @(ps2_toggle, reset)
begin
    if (reset)
    begin
        ps2_ready     <= 1'b0;
        arrow_left    <= 1'b0;
        arrow_right   <= 1'b0;
        arrow_up      <= 1'b0;
        arrow_down    <= 1'b0;
        ascii_code    <= 8'd0;
        ascii_ready   <= 1'b0;
        shift_L       <= 1'b0;
        shift_R       <= 1'b0;
    end
    else
    begin
        if (ps2_action)
        begin
            if (ps2_scancode == 8'h12)
            begin
                shift_L <= 1'b1;
                ascii_ready <= 1'b0;
            end
            else
            if (ps2_scancode == 8'h59)
            begin
                shift_R <= 1'b1;
                ascii_ready <= 1'b0;
            end
            else
            begin
                ps2_ready <= 1'b1;
                ascii_code <= scancode_to_ascii(ps2_scancode[7:0], shift_state);
                if (ascii_code != ps2_scancode[7:0])
                    ascii_ready <=1'b1;
                else
                    ascii_ready <= 1'b0;
            end
        end
        else    // ps2_action  == 0
        begin
           if (ps2_scancode == 8'h12)
           begin
                shift_L <= 1'b0;
                ascii_ready <= 1'b0;
           end
            else
            if (ps2_scancode == 8'h59)
            begin
                shift_R <= 1'b0;
                ascii_ready <= 1'b0;
            end
            else
            begin
                ps2_ready <= 1'b0;
                ascii_ready <= 1'b0;
                ascii_code <= 1'b0;
            end
        end
    end
end


endmodule
