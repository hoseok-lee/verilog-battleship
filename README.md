# Verilog Battleship
An FPGA (Verilog) implementation of the board game *battleship*. A DE1-SoC CycloneV 5CSEMA5F31C6 board was used to implement the project.


The graphical output is sent to the VGA output of the FPGA board. The number of ship *segments* are displayed on the hexes (HEX5/HEX4 for player 1 and HEX3/HEX2 for player 2). The current position selected by the switches are displayed on HEX1 and HEX0.

On the 10x10 board screen
- a white dot represents a ship piece,
- a yellow dot represents a guess (fired shot but missed), and
- a red dot represents a hit ship segment.

The game ends when one player guesses all of the ship segments on the opponent's board.
