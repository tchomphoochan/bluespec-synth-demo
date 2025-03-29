# Bluespec synthesis demo

Here, I demonstrate a minimal project in Bluespec that can be successfully synthesized and flashed onto the VCU108 dev board.

There are two parts. The first part is a simple LED controller. It powers on a single LED out of 8 LEDs. It cycles through the 8 LEDs from left to right or from right to left depending on the user's button press.

The second part is a UART loopback interface. It demonstrates how one could create a wrapper for Verilog or SystemVerilog modules through `import "BVI"`.

The top level of the project also demonstrates how one could configure clocks and resets.

This project is based heavily on <https://github.com/tchomphoochan/fpga-uart>, so I recommend checking out that one first
if you have trouble understanding what's going on.

Please feel free to contact me at <tcpc@mit.edu> if you have any questions. It took me a lot of trial and error to figure out all these stuff, and I would love to help save you some time.
