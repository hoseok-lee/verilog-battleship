module draw_control(
    // master input
    CLOCK,
    RESET,

    // input control signals
    UPDATE,
    FINISH,

    // output control signals
    START_DRAWING
);

    input  CLOCK, RESET, UPDATE, FINISH;

    output START_DRAWING;


        // STATE DEFINITIONS
    localparam
    S_DRAW_START = 1'd0,
    S_DRAW_IDLE = 1'd1;


        // STATE PAIR
    reg    current_state, next_state;


    initial
            current_state = S_DRAW_START;


        // STATE TABLE
    always @(*)
        begin :state_table
            case (current_state)
                S_DRAW_START:
                    next_state = UPDATE ? S_DRAW_IDLE:S_DRAW_START;
                S_DRAW_IDLE:
                    next_state = FINISH ? S_DRAW_START:S_DRAW_IDLE;

                default:
                    next_state = S_DRAW_START;
            endcase
        end


        // CONTROL SIGNALS
    assign START_DRAWING = (current_state == S_DRAW_START);


        // STATE FFS
    always @(posedge CLOCK)
        begin : state_ffs
            // reset
            if (RESET)
                current_state <= S_DRAW_START;

                // pass on states
            else
                current_state <= next_state;
        end

endmodule

module update_board_datapath(
    // master input
    CLOCK,
    RESET,

    // game boards
    PLAYER1_guess_board,
    PLAYER1_ship_board,
    PLAYER2_guess_board,
    PLAYER2_ship_board,
    // input controls
    x_in, y_in,
    rotate,
    player1_ship_length
    player2_ship_length,
    // input control signals
    START_DRAWING,
    CHOOSE_SHIP,
    VALID_SPOT,
    VALID_MOVE,
    PLAYER1_MOVE,
    PLAYER1_VALID_PLACEMENT,
    PLAYER2_VALID_PLACEMENT,

    // output controls
    board_counter,
    // VGA outputs
    cell_x_out, cell_y_out,
    cell_colour_out
);

    input            CLOCK, RESET;
    input            START_DRAWING, CHOOSE_SHIP, VALID_SPOT, VALID_MOVE, PLAYER1_MOVE, PLAYER1_VALID_PLACEMENT, PLAYER2_VALID_PLACEMENT, rotate;
    input  [99:0]
                     PLAYER1_guess_board,
                     PLAYER1_ship_board,
                     PLAYER2_guess_board,
                     PLAYER2_ship_board;
    input  [3:0]     x_in, y_in;
    input  [2:0]     player1_ship_length, player2_ship_length;

    output [8:0]     cell_x_out;
    output [7:0]     cell_y_out;
    output [2:0]     cell_colour_out;
    output reg [7:0] board_counter;


    reg [3:0]        board_x, board_y;
    reg              idle, first_cell;


    wire             board_side, CURSOR, VALID_SIDE;
    wire   [6:0]     board_coordinate;
    wire             curr_player1_ship_piece, curr_player2_ship_piece;


        // determines which side to draw the board on
    assign board_side = (board_counter <= 8'd100);
        // determines if the proper player is playing on the proper side
    assign VALID_SIDE = (CHOOSE_SHIP ~^ (board_side ^ PLAYER1_MOVE));
        // determines if the cursor is on the right place at the right board side
    assign CURSOR = (VALID_SIDE & (board_x == x_in) & (board_y == y_in));
        // the current screen coordinate
    assign board_coordinate = (board_x+board_y*10);

        // determines if there is a ship piece (for either player) on the current cell that it is drawing
    assign curr_player1_ship_piece = (CHOOSE_SHIP ? (((rotate ? ((board_x == x_in) & (board_y >= y_in) & (board_y < (y_in+player1_ship_length))):((board_y == y_in) & (board_x >= x_in) & (board_x < (x_in+player1_ship_length)))) & VALID_MOVE & PLAYER1_MOVE & PLAYER1_VALID_PLACEMENT) | PLAYER1_ship_board[board_coordinate]):PLAYER1_ship_board[board_coordinate]);
    assign curr_player2_ship_piece = (CHOOSE_SHIP ? (((rotate ? ((board_x == x_in) & (board_y >= y_in) & (board_y < (y_in+player2_ship_length))):((board_y == y_in) & (board_x >= x_in) & (board_x < (x_in+player2_ship_length)))) & VALID_MOVE & ~PLAYER1_MOVE & PLAYER2_VALID_PLACEMENT) | PLAYER2_ship_board[board_coordinate]):PLAYER2_ship_board[board_coordinate]);


        // CELL FSM
        // cell drawing moculde connections
    wire   [7:0]     cell_counter;
    wire             START_DRAWING_CELL;


    assign UPDATE_CELL = (idle);
    assign FINISH_CELL = (cell_counter >= 8'd64);


    draw_control UCDC(
        // master input
        .CLOCK        (CLOCK),
        .RESET        (RESET),

        // input control signals
        .UPDATE       (UPDATE_CELL),
        .FINISH       (FINISH_CELL),

        // output control signals
        .START_DRAWING(START_DRAWING_CELL)
    );
    update_cell_datapath UCD(
        // master input
        .CLOCK              (CLOCK),

        // screen inputs
        .board_x            (board_x),
        .board_y            (board_y),
        .board_side         (board_side),
        // game pieces
        .player1_ship_piece (curr_player1_ship_piece),
        .player1_guess_piece(PLAYER1_guess_board[board_coordinate]),
        .player2_ship_piece (curr_player2_ship_piece),
        .player2_guess_piece(PLAYER2_guess_board[board_coordinate]),
        // input control signals
        .START_DRAWING      (START_DRAWING_CELL),
        .CURSOR             (CURSOR),
        .VALID_SIDE         (VALID_SIDE),
        .CHOOSE_SHIP        (CHOOSE_SHIP),

        // output controls
        .cell_counter       (cell_counter),
        // VGA outputs
        .cell_x_out         (cell_x_out),
        .cell_y_out         (cell_y_out),
        .cell_colour_out    (cell_colour_out)
    );


        // the actual counting and drawing happens here
    always @(posedge CLOCK)
        // reset the counter once you start drawing
        if (START_DRAWING)
            begin
                board_counter <= 8'd0;
                board_x <= 4'd0;
                board_y <= 4'd0;
                first_cell <= 1'b1;
                idle <= 1'b0;
            end

            // else, draw it
        else
            begin
                // once it completes drawing, draw the next cell
                if (START_DRAWING_CELL & ~idle)
                    begin
                        idle <= 1'b1;

                        if (first_cell)
                            first_cell <= 1'b0;

                        else
                            begin
                                // increment the screen coordinates
                                board_x <= board_x+4'd1;
                                if (board_x == 4'd9)
                                    begin
                                        board_x <= 4'd0;
                                        board_y <= board_y+4'd1;
                                        if (board_y == 4'd9)
                                            board_y <= 4'd0;
                                    end
                            end

                        board_counter <= board_counter+8'd1;
                    end

                else if (~START_DRAWING_CELL)
                    idle <= 1'b0;
            end

endmodule