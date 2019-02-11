// use update_control as the control module

module update_cell_datapath(
    // master input
    CLOCK,

    // screen inputs
    board_x, board_y,
    board_side,
    // game pieces
    player1_ship_piece,
    player1_guess_piece,
    player2_ship_piece,
    player2_guess_piece,
    // input control signals
    START_DRAWING,
    CURSOR,
    VALID_SIDE,
    CHOOSE_SHIP,

    // output controls
    cell_counter,
    // VGA outputs
    cell_x_out, cell_y_out,
    cell_colour_out
);

    input            CLOCK;
    input            START_DRAWING, CURSOR, VALID_SIDE, CHOOSE_SHIP, board_side;
    input  [3:0]     board_x, board_y;
    input            player1_ship_piece,
                     player1_guess_piece,
                     player2_ship_piece,
                     player2_guess_piece;

    output [8:0]     cell_x_out;
    output [7:0]     cell_y_out;
    output reg [2:0] cell_colour_out;
    output reg [7:0] cell_counter;


    reg [63:0]       piece, cursor, ex;


    coordinate_decoder CD(
        .board_x   (board_x),
        .board_y   (board_y),
        .board_side(board_side),
        .counter   (cell_counter),
        .cell_x_out(cell_x_out),
        .cell_y_out(cell_y_out)
    );


    initial
        begin //            0       1       2       3       4       5       6       7       8
            ex      <= 64'b1111111111000011101001011001100110011001101001011100001111111111;
            piece   <= 64'b0000000000011000001111000111111001111110001111000001100000000000;
            cursor  <= 64'b1111111110000001100000011000000110000001100000011000000111111111;
        end


    assign ship_piece = (board_side ? player2_ship_piece:player1_ship_piece);
    assign guess_piece = (board_side ? player1_guess_piece:player2_guess_piece);


    always @(posedge CLOCK)
        // reset the counter once you start drawing
        if (START_DRAWING)
            begin
                cell_counter <= 8'd0;
            end

            // else, draw it
        else
            begin
                if (CURSOR & cursor[cell_counter])
                    // green
                    cell_colour_out <= 3'b010;

                else
                    if (guess_piece & ex[cell_counter])
                        begin
                            if (ship_piece)
                                // HIT - red
                                cell_colour_out <= 3'b100;
                            else
                                // MISSED - yellow
                                cell_colour_out <= 3'b110;
                        end

                    else
                        begin
                            if (ship_piece & (VALID_SIDE ~^ CHOOSE_SHIP))
                                // SHIP - white
                                cell_colour_out <= 3'b111;
                            else
                                // NONE - black
                                cell_colour_out <= 3'b001;
                        end

                cell_counter <= cell_counter+8'd1;
            end

endmodule


module coordinate_decoder(
    // input coordinates
    board_x, board_y,
    // game inputs
    board_side,
    counter,

    // output coordinates
    cell_x_out, cell_y_out
);

    input  [3:0] board_x, board_y;
    input        board_side;
    input  [6:0] counter;

    output [8:0] cell_x_out;
    output [7:0] cell_y_out;


    assign cell_x_out = (board_side ? (board_x*10+190+counter[2:0]):(board_x*10+40+counter[2:0]));
    assign cell_y_out = (board_y*10+70+counter[5:3]);

endmodule