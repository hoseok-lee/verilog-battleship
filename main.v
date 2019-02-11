`timescale 1ns/1ns

module top_module(
    // clock
    CLOCK_50,

    // input switches
    SW, KEY,
    // output hexes
    HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6,
    LEDR,

    // The ports below are for the VGA output.  Do not change.
    VGA_CLK,         // VGA Clock
    VGA_HS,       // VGA H_SYNC
    VGA_VS,       // VGA V_SYNC
    VGA_BLANK_N,      // VGA BLANK
    VGA_SYNC_N,      // VGA SYNC
    VGA_R,         // VGA Red[9:0]
    VGA_G,        // VGA Green[9:0]
    VGA_B         // VGA Blue[9:0]
);

    input         CLOCK_50;
    input  [8:0]  SW;
    input  [3:0]  KEY;

    output [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6;
    output [9:0]  LEDR;
        // Do not change the following outputs
    output        VGA_CLK;       // VGA Clock
    output        VGA_HS;     // VGA H_SYNC
    output        VGA_VS;     // VGA V_SYNC
    output        VGA_BLANK_N;    // VGA BLANK
    output        VGA_SYNC_N;    // VGA SYNC
    output [7:0]  VGA_R;       // VGA Red[7:0] Changed from 10 to 8-bit DAC
    output [7:0]  VGA_G;      // VGA Green[7:0]
    output [7:0]  VGA_B;       // VGA Blue[7:0]


        // master inputs
    wire          CLOCK, RESET,
        // 1 if the game is in single player mode
        // 0 if the game is in two player mode
        // (since we don't have our AI properly working yet,
        // the game will always run in two player mode)
                  single_player_mode,
        // connected to ~KEY[0]
                  fire;
        // counts the number of ships PIECES (of each player)
    wire   [4:0]  PLAYER1_ships, PLAYER2_ships;
        // the BOARD coordinate (no the screen coordinate)
    wire   [3:0]  x_in, y_in;

        // VGA output registers
    wire   [8:0]  screen_x_out;
    wire   [7:0]  screen_y_out;
    wire   [2:0]  screen_colour_out;
    wire          write_enable;

        // control signals
    wire
        // checks whether the players are choosing ships
                  CHOOSE_SHIP,
        // connected to fire
                  PLAY_MOVE,
        // checks whether if its player 1's turn
                  PLAYER1_MOVE,
        // screen states
                  START_SCREEN,
                  BLACK_SCREEN,
        // if ENDGAME == 1 and PLAYER1_WIN == 1
        // display the win screen for player 1
                  PLAYER1_WIN,
                  ENDGAME,

        // checks whether the key/switch inputs have changed state
                  UPDATE,
        // determines if a valid move has been made
                  MOVE_MADE,
        // checks whether the screen has finished updating
                  FINISH_SCREEN;
        // in the choosing-ship stage, counts which ship is being placed
    wire   [2:0]  SHIP_NUMBER;

        // pulses turn 1 whenever there's a change in key/switch inputs
    wire   [10:0] pulse;
        // wires to store the information of the key states in the previous clock edge
    wire   [10:0] signal_out;


        // input key and switch assignments
    assign x_in = SW[7:4];
    assign y_in = SW[3:0];
    assign RESET = ~KEY[1];
    assign fire = ~KEY[0];


        // generate pulses everytime an input key/switch changes state
    generate
        begin
            genvar i;

            for (i = 0; i < 9; i = i+1)
                begin : gen1
                    generate_pulse_on_change GPO(
                        .CLOCK     (CLOCK_50),
                        .signal_in (SW[i]),
                        .signal_out(signal_out[i]),
                        .pulse     (pulse[i])
                    );
                end
        end
    endgenerate
        // fire signal
    generate_pulse_on_change GPOC9(
        .CLOCK     (CLOCK_50),
        .signal_in (fire),
        .signal_out(signal_out[9]),
        .pulse     (pulse[9])
    );
        // reset signal
    generate_pulse_on_change GPOC10(
        .CLOCK     (CLOCK_50),
        .signal_in (RESET),
        .signal_out(signal_out[10]),
        .pulse     (pulse[10])
    );

        // update everytime a switch changes state
        // include the fire and RESET key
    assign UPDATE = (pulse != 11'd0);


        // Create an Instance of a VGA controller - there can be only one!
        // Define the number of colours as well as the initial background
        // image file (.MIF) for the controller.
    vga_adapter VGA(
        .resetn   (~RESET),
        .clock    (CLOCK_50),
        .colour   (screen_colour_out),
        .x        (screen_x_out),
        .y        (screen_y_out),
        .plot     (write_enable),
        /* Signals for the DAC to drive the monitor. */
        .VGA_R    (VGA_R),
        .VGA_G    (VGA_G),
        .VGA_B    (VGA_B),
        .VGA_HS   (VGA_HS),
        .VGA_VS   (VGA_VS),
        .VGA_BLANK(VGA_BLANK_N),
        .VGA_SYNC (VGA_SYNC_N),
        .VGA_CLK  (VGA_CLK)
    );
    defparam VGA.RESOLUTION = "320x240";
    defparam VGA.MONOCHROME = "FALSE";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
    defparam VGA.BACKGROUND_IMAGE = "start.mif";


    master_game_control C(
        // master inputs
        .CLOCK               (CLOCK_50),
        .RESET               (RESET),

        // game inputs
        .single_player_button(~KEY[2]),
        .two_player_button   (~KEY[3]),
        .fire                (fire),
        .PLAYER1_ships       (PLAYER1_ships),
        .PLAYER2_ships       (PLAYER2_ships),
        // input control signals
        .MOVE_MADE           (MOVE_MADE),
        .FINISH_SCREEN       (FINISH_SCREEN),

        // game outputs
        .single_player_mode  (single_player_mode),
        // output control signals
        .CHOOSE_SHIP         (CHOOSE_SHIP),
        .PLAY_MOVE           (PLAY_MOVE),
        .PLAYER1_MOVE        (PLAYER1_MOVE),
        .SHIP_NUMBER         (SHIP_NUMBER),
        .START_SCREEN        (START_SCREEN),
        .BLACK_SCREEN        (BLACK_SCREEN),
        .PLAYER1_WIN         (PLAYER1_WIN),
        .ENDGAME             (ENDGAME)
    );
    master_game_datapath D(
        // master inputs
        .CLOCK             (CLOCK_50),
        .UPDATE            (UPDATE),
        .RESET             (RESET),

        // game inputs
        .x_in              (x_in),
        .y_in              (y_in),
        .rotate            (SW[8]),
        .single_player_mode(single_player_mode),
        // input control signals
        .CHOOSE_SHIP       (CHOOSE_SHIP),
        .PLAY_MOVE         (PLAY_MOVE),
        .PLAYER1_MOVE      (PLAYER1_MOVE),
        .SHIP_NUMBER       (SHIP_NUMBER),
        .START_SCREEN      (START_SCREEN),
        .BLACK_SCREEN      (BLACK_SCREEN),
        .PLAYER1_WIN       (PLAYER1_WIN),
        .ENDGAME           (ENDGAME),

        // VGA output
        .write_enable      (write_enable),
        .screen_x_out      (screen_x_out),
        .screen_y_out      (screen_y_out),
        .screen_colour_out (screen_colour_out),
        // game outputs
        .PLAYER1_ships     (PLAYER1_ships),
        .PLAYER2_ships     (PLAYER2_ships),
        // output control signals
        .MOVE_MADE         (MOVE_MADE),
        .FINISH_SCREEN     (FINISH_SCREEN)
    );


        // HEX SEGMENTS
        // x coordinate
    hex_decoder H1(
        .hex_digit(x_in),
        .segments (HEX1)
    );
        // y coordinate
    hex_decoder H0(
        .hex_digit(y_in),
        .segments (HEX0)
    );
        // player 1 ships left
    hex_decoder H4(
        .hex_digit(PLAYER1_ships[3:0]),
        .segments (HEX4)
    );
    hex_decoder H5(
        .hex_digit(PLAYER1_ships[4]+4'd0),
        .segments (HEX5)
    );
        // player 2 ships left
    hex_decoder H2(
        .hex_digit(PLAYER2_ships[3:0]),
        .segments (HEX2)
    );
    hex_decoder H3(
        .hex_digit(PLAYER2_ships[4]+4'd0),
        .segments (HEX3)
    );

endmodule


module generate_pulse_on_change(CLOCK, signal_in, signal_out, pulse);

    input      CLOCK, signal_in;
    output     pulse;
    output reg signal_out;


    wire       signal_change;
    assign signal_change = (signal_in != signal_out);

    pulse_generator PG(CLOCK, signal_change, pulse);

    always @(posedge CLOCK)
        signal_out <= signal_in;

endmodule

module pulse_generator(CLOCK, signal, pulse);

    input   CLOCK, signal;
    output  pulse;


    integer counter;

    initial
        counter = 0;

    assign pulse = (counter > 0);
        // increment counter
    always @(posedge CLOCK)
        begin
            if (signal)
                counter = 1;

            else if (counter > 0)
                counter = counter-1;
        end

endmodule

module master_game_control(
    // master inputs
    CLOCK,
    RESET,

    // game inputs
    single_player_button,
    two_player_button,
    fire,
    PLAYER1_ships,
    PLAYER2_ships,
    // input control signals
    MOVE_MADE,
    FINISH_SCREEN,

    // game outputs
    single_player_mode,
    // output control signals
    CHOOSE_SHIP,
    PLAY_MOVE,
    PLAYER1_MOVE,
    SHIP_NUMBER,
    START_SCREEN,
    BLACK_SCREEN,
    PLAYER1_WIN,
    ENDGAME
);

    input            CLOCK, RESET;
    input            single_player_button, two_player_button, fire;
    input [4:0]      PLAYER1_ships, PLAYER2_ships;
    input            MOVE_MADE, FINISH_SCREEN;

    output
                     CHOOSE_SHIP,
                     PLAY_MOVE,
                     PLAYER1_MOVE,
                     START_SCREEN,
                     BLACK_SCREEN,
                     PLAYER1_WIN,
                     ENDGAME;
    output reg       single_player_mode;
    output reg [2:0] SHIP_NUMBER;


        // STATE DEFINITIONS
    localparam
        S_START_SCREEN          = 4'd0,
        S_START_SCREEN_IDLE     = 4'd1,
        S_BLACK_SCREEN          = 4'd2,
        S_1_SELECT_SHIP         = 4'd3,
        S_1_SELECT_SHIP_IDLE    = 4'd4,
        S_2_SELECT_SHIP         = 4'd5,
        S_2_SELECT_SHIP_IDLE    = 4'd6,
        S_1_MOVE                = 4'd7,
        S_1_MOVE_IDLE           = 4'd8,
        S_2_MOVE                = 4'd9,
        S_2_MOVE_IDLE           = 4'd10,
        S_AI_MOVE               = 4'd11,
        S_AI_MOVE_IDLE          = 4'd12,
        S_ENDGAME               = 4'd13,
        S_EXIT                  = 4'd14;


        // STATE PAIR
    reg [3:0]        current_state, next_state;


    initial
        current_state <= S_START_SCREEN;


        // STATE TABLE
    always @(*)
        begin :state_table
            case (current_state)
                    // start screen
                S_START_SCREEN:
                        // game initialization
                    begin
                            // default set the gameplay mode to two players
                        single_player_mode <= 1'b0;

                            // if EITHER the single player or two player button has been pressed
                        if (single_player_button | two_player_button)
                            begin
                                    // set single player mode if the respective button has been pressed
                                if (single_player_button)
                                    single_player_mode <= 1'b1;

                                    // move on to the next state
                                next_state = S_START_SCREEN_IDLE;
                            end

                        else
                            next_state = S_START_SCREEN;
                    end
                S_START_SCREEN_IDLE:
                    next_state = (single_player_button | two_player_button) ?  S_START_SCREEN_IDLE:S_BLACK_SCREEN;

                    // black the screen
                S_BLACK_SCREEN:
                    next_state = (FINISH_SCREEN) ? S_1_SELECT_SHIP:S_BLACK_SCREEN;

                    // pick the ships
                    // the choosing-ship stage
                S_1_SELECT_SHIP:
                    next_state = (fire) ? S_1_SELECT_SHIP_IDLE:S_1_SELECT_SHIP;
                S_1_SELECT_SHIP_IDLE:
                        // if player 1 has finished placing all of their ships
                        // move onto player 2 choosing ships
                    next_state = (fire) ? S_1_SELECT_SHIP_IDLE:((SHIP_NUMBER == 3'd5) ? S_2_SELECT_SHIP:S_1_SELECT_SHIP);

                S_2_SELECT_SHIP:
                    next_state = (fire) ? S_2_SELECT_SHIP_IDLE:S_2_SELECT_SHIP;
                S_2_SELECT_SHIP_IDLE:
                        // if player 2 has finished placing all of their ships
                        // move onto playing the game
                    next_state = (fire) ? S_2_SELECT_SHIP_IDLE:((SHIP_NUMBER == 3'd5) ? S_1_MOVE:S_2_SELECT_SHIP);

                    // begin the game
                S_1_MOVE:
                    next_state = (fire) ? S_1_MOVE_IDLE:S_1_MOVE;
                S_1_MOVE_IDLE:
                    next_state = (fire) ? S_1_MOVE_IDLE:((single_player_mode) ? S_AI_MOVE:S_2_MOVE);
                S_2_MOVE:
                    next_state = (fire) ? S_2_MOVE_IDLE:S_2_MOVE;
                S_2_MOVE_IDLE:
                    next_state = (fire) ? S_2_MOVE_IDLE:S_1_MOVE;

                    // AI moves
                    // it takes one clock cycle to go through these two states
                S_AI_MOVE:
                    next_state = S_AI_MOVE_IDLE;
                S_AI_MOVE_IDLE:
                    next_state = S_1_MOVE;

                    // end the game
                S_ENDGAME:
                    next_state = (FINISH_SCREEN) ? S_EXIT:S_ENDGAME;

                    // post-end-game screen
                S_EXIT:
                    next_state = S_EXIT;

                    // default
                default:
                    next_state = S_START_SCREEN;
            endcase
        end


        // CONTROL SIGNALS
    assign START_SCREEN = (current_state <= S_BLACK_SCREEN);
    assign BLACK_SCREEN = (current_state == S_BLACK_SCREEN);
    assign CHOOSE_SHIP = (current_state >= S_1_SELECT_SHIP & current_state <= S_2_SELECT_SHIP_IDLE);
    assign PLAY_MOVE = fire;
    assign PLAYER1_MOVE = (current_state == S_1_MOVE | current_state == S_1_MOVE_IDLE | current_state == S_1_SELECT_SHIP | current_state == S_1_SELECT_SHIP_IDLE);
    assign PLAYER1_WIN = (PLAYER2_ships == 5'd0);
    assign ENDGAME = (current_state >= S_ENDGAME);


        // STATE FFS
    always @(posedge CLOCK)
        begin : state_ffs
            // reset
            if (RESET)
                begin
                    // reset ship number
                    SHIP_NUMBER <= 3'd0;
                    // reset state
                    current_state <= S_START_SCREEN;
                end

                // when one player has lost all their ships, cause end game sequence
            else if (PLAYER1_ships == 5'd0 | PLAYER2_ships == 5'd0)
                current_state <= S_ENDGAME;

            else
                    // for the first few states,
                    // pass on states normally
                if (START_SCREEN)
                    current_state <= next_state;

                    // otherwise...
                else
                        // if the NEXT state is a non-wait state
                        // pass it on without checking if a valid move has been made, since it's just a wait state
                    if (next_state%2 == 4'd1)
                        begin
                            current_state <= next_state;

                            if (SHIP_NUMBER == 3'd5)
                                // reset the ship number
                                SHIP_NUMBER <= 3'd0;
                        end

                        // if the CURRENT state is a non-wait state,
                        // (or if the NEXT state is a wait state)
                        // the FSM must check if the move made was valid
                        // (even though the control signal passes to the datapath and the MOVE_MADE signal passes back
                        // into the control, it takes 2 clock cycles for that to occur, which is 40 ns, way too quick
                        // for human reflexes to interrupt the signal exchange)
                    else
                        begin
                            // AND if the move made during the current state was valid...
                            if (MOVE_MADE)
                                begin
                                    // if the game is in the ship-choosing state...
                                    if (CHOOSE_SHIP)
                                        // this code section runs only on the state change,
                                        // thus it only runs once per state change
                                        if (current_state != next_state)
                                            begin
                                                // pick the next ship
                                                SHIP_NUMBER <= SHIP_NUMBER+3'd1;

                                            end

                                    // pass on states
                                    current_state <= next_state;
                                end
                        end
        end

endmodule

module master_game_datapath(
    // master inputs
    CLOCK,
    UPDATE,
    RESET,

    // game inputs
    x_in, y_in,
    rotate,
    single_player_mode,
    // input control signals
    CHOOSE_SHIP,
    PLAY_MOVE,
    PLAYER1_MOVE,
    SHIP_NUMBER,
    START_SCREEN,
    BLACK_SCREEN,
    PLAYER1_WIN,
    ENDGAME,
    // VGA output
    write_enable,
    screen_x_out, screen_y_out,
    screen_colour_out,

    // game outputs
    PLAYER1_ships,
    PLAYER2_ships,
    // output control signals
    MOVE_MADE,
    FINISH_SCREEN
);

    input            CLOCK, UPDATE, RESET;
    input            rotate, single_player_mode;
    input  [3:0]     x_in, y_in;
    input
                     CHOOSE_SHIP,
                     PLAY_MOVE,
                     PLAYER1_MOVE,
                     START_SCREEN,
                     BLACK_SCREEN,
                     PLAYER1_WIN,
                     ENDGAME;
    input  [2:0]     SHIP_NUMBER;

    output [8:0]     screen_x_out;
    output [7:0]     screen_y_out;
    output [2:0]     screen_colour_out;
    output reg [4:0] PLAYER1_ships, PLAYER2_ships;
    output           write_enable, MOVE_MADE;


        // boards
    reg [99:0]
                     PLAYER1_guess_board,
                     PLAYER1_ship_board,
                     PLAYER2_guess_board,
                     PLAYER2_ship_board;


        // VGA outputs
    wire   [8:0]     cell_x_out;
    wire   [7:0]     cell_y_out;
    wire   [2:0]     cell_colour_out;

        // player 2 coordinates
        // (a separate wire is needed for the AI)
    wire   [3:0]     player2_x_in, player2_y_in;
        // the ships lengths for each ship
    wire   [2:0]     player1_ship_length, player2_ship_length;
        // valid move placement checking wire
    wire             VALID_SPOT, VALID_MOVE, CURSOR;
        // valid move placement checking wire for each player
    wire             PLAYER1_VALID_PLACEMENT, PLAYER2_VALID_PLACEMENT, PLAYER1_SHIP_COLLISION, PLAYER2_SHIP_COLLISION;
        // coordinates for each player
    wire   [6:0]     coordinate, player2_coordinate;


        // VGA coordinates
    assign coordinate = (x_in+y_in*10);
        // write enable
    assign write_enable = (~START_DRAWING_SCREEN);
        // wires to determine valid spots and moves
    assign VALID_SPOT = ((~PLAYER1_MOVE & ~PLAYER2_guess_board[coordinate]) | (PLAYER1_MOVE & ~PLAYER1_guess_board[coordinate]));
    assign VALID_MOVE = (VALID_SPOT & (PLAYER1_MOVE ? PLAYER1_VALID_PLACEMENT:~PLAYER1_MOVE & PLAYER2_VALID_PLACEMENT));
    assign MOVE_MADE = (PLAY_MOVE & VALID_MOVE & (CHOOSE_SHIP ? (PLAYER1_MOVE ? ~PLAYER1_SHIP_COLLISION:~PLAYER2_SHIP_COLLISION):1'b1));


        // INITIALIZE
    initial
        begin
            // initialize ship numbers
            PLAYER1_ships <= 5'd17;
            PLAYER2_ships <= 5'd17;
            // initialize boards
            PLAYER1_guess_board <= 99'b0;
            PLAYER1_ship_board <= 99'b0;
            PLAYER2_guess_board <= 99'b0;
            PLAYER2_ship_board <= 99'b0;
        end


        // piece collision
    piece_collision PC1(
        .CLOCK          (CLOCK),
        .x_in           (x_in),
        .y_in           (y_in),
        .rotate         (rotate),
        .board          (PLAYER1_ship_board),
        .CHOOSE_SHIP    (CHOOSE_SHIP),
        .SHIP_NUMBER    (SHIP_NUMBER),
        .ship_length    (player1_ship_length),
        .VALID_PLACEMENT(PLAYER1_VALID_PLACEMENT),
        .SHIP_COLLISION (PLAYER1_SHIP_COLLISION)
    );
    piece_collision PC2(
        .CLOCK          (CLOCK),
        .x_in           (x_in),
        .y_in           (y_in),
        .rotate         (rotate),
        .board          (PLAYER2_ship_board),
        .CHOOSE_SHIP    (CHOOSE_SHIP),
        .SHIP_NUMBER    (SHIP_NUMBER),
        .ship_length    (player2_ship_length),
        .VALID_PLACEMENT(PLAYER2_VALID_PLACEMENT),
        .SHIP_COLLISION (PLAYER2_SHIP_COLLISION)
    );


        // screen drawing module connections
    wire             START_DRAWING_BOARD, FINISH_BOARD;
    wire             START_DRAWING_SCREEN;
    output           FINISH_SCREEN;
    wire   [16:0]    screen_counter;
    wire   [7:0]     board_counter;
    reg [2:0]        screen_state;


        // STATE DEFINITIONS
    localparam
        S_BLACK_SCREEN          = 3'd0,
        S_GAME_BOARD            = 3'd1,
        S_PLAYER1_WIN_SCREEN    = 3'd2,
        S_PLAYER2_WIN_SCREEN    = 3'd3;


        // STATE TABLE
    always @(*)
        begin :state_table
            if (START_SCREEN)
                screen_state <= S_BLACK_SCREEN;
            else if (ENDGAME)
                begin
                    if (PLAYER1_WIN)
                        screen_state <= S_PLAYER1_WIN_SCREEN;
                    else
                        screen_state <= S_PLAYER2_WIN_SCREEN;
                end
            else
                screen_state <= S_GAME_BOARD;
        end


        // when to determine finish drawing the board
    assign FINISH_BOARD = (board_counter == 8'd201);
        // when to determine finish drawing the screen
    assign FINISH_SCREEN = (screen_state == S_GAME_BOARD) ? FINISH_BOARD:(screen_counter == 17'd76800);


        // UPDATE BOARD FSM
    draw_control UBDC(
        // master input
        .CLOCK        (CLOCK),
        .RESET        (RESET),

        // input control signals
        .UPDATE       (UPDATE & (~START_SCREEN & ~ENDGAME)),
        .FINISH       (FINISH_BOARD),

        // output control signals
        .START_DRAWING(START_DRAWING_BOARD)
    );
    update_board_datapath UBD(
        // master input
        .CLOCK                  (CLOCK),
        .RESET                  (RESET),

        // game boards
        .PLAYER1_guess_board    (PLAYER1_guess_board),
        .PLAYER1_ship_board     (PLAYER1_ship_board),
        .PLAYER2_guess_board    (PLAYER2_guess_board),
        .PLAYER2_ship_board     (PLAYER2_ship_board),
        // game inputs
        .x_in                   (x_in),
        .y_in                   (y_in),
        .rotate                 (rotate),
        .player1_ship_length    (player1_ship_length),
        .player2_ship_length    (player2_ship_length),
        // input control signals
        .START_DRAWING          (START_DRAWING_BOARD),
        .CHOOSE_SHIP            (CHOOSE_SHIP),
        .VALID_SPOT             (VALID_SPOT),
        .VALID_MOVE             (VALID_MOVE),
        .PLAYER1_MOVE           (PLAYER1_MOVE),
        .PLAYER1_VALID_PLACEMENT(PLAYER1_VALID_PLACEMENT),
        .PLAYER2_VALID_PLACEMENT(PLAYER2_VALID_PLACEMENT),

        // output controls
        .board_counter          (board_counter),
        // VGA outputs
        .cell_x_out             (cell_x_out),
        .cell_y_out             (cell_y_out),
        .cell_colour_out        (cell_colour_out)
    );

        // UPDATE SCREEN FSM
    draw_control USDC(
        // master input
        .CLOCK        (CLOCK),
        .RESET        (RESET),

        // input control signals
        .UPDATE       (UPDATE & (~START_SCREEN & ~ENDGAME) | BLACK_SCREEN | ENDGAME),
        .FINISH       (FINISH_SCREEN),

        // output control signals
        .START_DRAWING(START_DRAWING_SCREEN)
    );
    update_screen_datapath USD(
        // master input
        .CLOCK            (CLOCK),

        // VGA inputs
        .cell_x_in        (cell_x_out),
        .cell_y_in        (cell_y_out),
        .cell_colour_in   (cell_colour_out),
        .screen_state     (screen_state),
        // input control signals
        .START_DRAWING    (START_DRAWING_SCREEN),

        // output controls
        .screen_counter   (screen_counter),
        // VGA outputs
        .screen_x_out     (screen_x_out),
        .screen_y_out     (screen_y_out),
        .screen_colour_out(screen_colour_out)
    );


        // GAME
    always @(posedge CLOCK)
        if (~ENDGAME & ~START_SCREEN)
            // RESET
            if (RESET)
                begin
                    PLAYER1_ships <= 5'd17;
                    PLAYER2_ships <= 5'd17;

                    PLAYER1_guess_board <= 99'd0;
                    PLAYER1_ship_board <= 99'd0;
                    PLAYER2_guess_board <= 99'd0;
                    PLAYER2_ship_board <= 99'd0;
                end

                // SET + PLAY BOARD
            else if (PLAY_MOVE & VALID_MOVE)
                // set the board
                if (CHOOSE_SHIP)
                    begin
                        // remember that rotate == 0 means horizontal and rotate == 1 means vertical
                        // player 1 set
                        // if it's player 1's turn and there's no collision of ships
                        if (PLAYER1_MOVE & ~PLAYER1_SHIP_COLLISION)
                            begin
                                for (i = 0; i < player1_ship_length; i = i+1)
                                    if (rotate)
                                        PLAYER1_ship_board[x_in+(y_in+i)*10] <= 1'b1;
                                    else
                                        PLAYER1_ship_board[(x_in+i)+y_in*10] <= 1'b1;
                            end

                            // player 2 set
                            // if it's player 2's turn and there's no collision of ships
                        else if (~PLAYER1_MOVE & ~PLAYER2_SHIP_COLLISION)
                            begin
                                for (i = 0; i < player2_ship_length; i = i+1)
                                    if (rotate)
                                        PLAYER2_ship_board[x_in+(y_in+i)*10] <= 1'b1;
                                    else
                                        PLAYER2_ship_board[(x_in+i)+y_in*10] <= 1'b1;
                            end
                    end

                    // play the board
                else
                    begin
                        // player 1 goes
                        if (PLAYER1_MOVE)
                            begin
                                if (~PLAYER1_guess_board[coordinate])
                                    begin
                                        PLAYER1_guess_board[coordinate] <= 1'b1;

                                        if (PLAYER2_ship_board[coordinate])
                                            PLAYER2_ships <= PLAYER2_ships-1'b1;
                                    end
                            end

                            // player 2 goes
                        else
                            begin
                                if (~PLAYER2_guess_board[coordinate])
                                    begin
                                        PLAYER2_guess_board[coordinate] <= 1'b1;

                                        if (PLAYER1_ship_board[coordinate])
                                            PLAYER1_ships <= PLAYER1_ships-1'b1;
                                    end
                            end
                    end

endmodule


module piece_collision(
    // master input
    CLOCK,

    // game inputs
    x_in, y_in,
    rotate,
    board,
    // input control signals
    CHOOSE_SHIP,
    SHIP_NUMBER,

    // game outputs
    ship_length,
    // output control signals
    VALID_PLACEMENT,
    SHIP_COLLISION
);

    input            CLOCK, CHOOSE_SHIP;
    input            rotate;
    input [3:0]      x_in, y_in;
    input [99:0]     board;
    input [2:0]      SHIP_NUMBER;

    output           VALID_PLACEMENT, SHIP_COLLISION;
    output reg [2:0] ship_length;


        // 1 if there is a ship collision
    reg              ship_piece_collision;


        // detect collision with board edges
    assign VALID_PLACEMENT = ((CHOOSE_SHIP & ((~rotate & ((x_in+ship_length-4'd1) < 4'd10) & y_in < 4'd10) | (rotate & (x_in < 4'd10) & (y_in+ship_length-4'd1) < 4'd10))) | (~CHOOSE_SHIP & (x_in < 4'd10 & y_in < 4'd10)));
    assign SHIP_COLLISION = (ship_piece_collision != 1'b0);


    always @(*)
        // assigns a ship length give a ship number
        case (SHIP_NUMBER)
            3'd0:
                begin
                    ship_length = 3'd2;
                    ship_piece_collision <= (rotate ? (board[(x_in)+(y_in)*10] | board[(x_in)+(y_in+1)*10]):(board[(x_in)+(y_in)*10] | board[(x_in+1)+(y_in)*10]));
                end
            3'd1:
                begin
                    ship_length = 3'd3;
                    ship_piece_collision <= (rotate ? (board[(x_in)+(y_in)*10] | board[(x_in)+(y_in+1)*10] | board[(x_in)+(y_in+2)*10]):(board[(x_in)+(y_in)*10] | board[(x_in+1)+(y_in)*10] | board[(x_in+2)+(y_in)*10]));
                end
            3'd2:
                begin
                    ship_length = 3'd3;
                    ship_piece_collision <= (rotate ? (board[(x_in)+(y_in)*10] | board[(x_in)+(y_in+1)*10] | board[(x_in)+(y_in+2)*10]):(board[(x_in)+(y_in)*10] | board[(x_in+1)+(y_in)*10] | board[(x_in+2)+(y_in)*10]));
                end
            3'd3:
                begin
                    ship_length = 3'd4;
                    ship_piece_collision <= (rotate ? (board[(x_in)+(y_in)*10] | board[(x_in)+(y_in+1)*10] | board[(x_in)+(y_in+2)*10] | board[(x_in)+(y_in+3)*10]):(board[(x_in)+(y_in)*10] | board[(x_in+1)+(y_in)*10] | board[(x_in+2)+(y_in)*10] | board[(x_in+3)+(y_in)*10]));
                end
            3'd4:
                begin
                    ship_length = 3'd5;
                    ship_piece_collision <= (rotate ? (board[(x_in)+(y_in)*10] | board[(x_in)+(y_in+1)*10] | board[(x_in)+(y_in+2)*10] | board[(x_in)+(y_in+3)*10] | board[(x_in)+(y_in+4)*10]):(board[(x_in)+(y_in)*10] | board[(x_in+1)+(y_in)*10] | board[(x_in+2)+(y_in)*10] | board[(x_in+3)+(y_in)*10] | board[(x_in+4)+(y_in)*10]));
                end
        endcase

endmodule