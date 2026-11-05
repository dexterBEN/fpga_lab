"""Sequential notebook driver for the 9-bit GPIO command contract.

Run on PYNQ with the matching registers.bit/registers.hwh overlay.
There is no hardware ACK. Only one caller may own this driver/GPIO.
The settling reads rely on the shared clock and standard uncached PYNQ MMIO;
they do not confirm command completion. Do not reuse this protocol unchanged
for multiple clients, asynchronous clock domains, or stronger transaction guarantees.
"""

DATA_MASK = 0x00F
SERIAL = 1 << 4
MODE = 1 << 5
LOAD = 1 << 6
SHIFT = 1 << 7
RESET = 1 << 8
COMMAND_MASK = 0x1FF
Q_MASK = 0xF


class RegisterControl:
    def __init__(self, gpio):
        self.commands = gpio.channel1
        self.result = gpio.channel2
        self.commands.setdirection("out")
        self.commands.setlength(9)
        self.result.setdirection("in")
        self.result.setlength(4)
        # Output bits cannot be read back through GPIO_DATA. Keep a shadow.
        self.shadow = 0
        self.reset()

    def _settle(self):
        # Timing allowance only: these reads are not a hardware ACK.
        # Each completed uncached MMIO read is an AXI transaction in the
        # common PL clock domain. Eight reads leave more than the two reset
        # release edges + one rearming edge. No Python sleep generates pulses.
        # Assumes standard PYNQ MMIO, a running common clock and one writer.
        for _ in range(8):
            value = int(self.result.read()) & Q_MASK
        return value

    def write_command(self, value):
        """Write the entire GPIO word; low-level callers own the protocol."""
        value = int(value)
        if value < 0 or value > COMMAND_MASK:
            raise ValueError("command must fit in 9 bits")
        self.commands.write(value, COMMAND_MASK)
        self.shadow = value
        return self._settle()

    def reset(self):
        """Request a synchronous functional reset through GPIO bit 8.

        The adapter samples this request on a rising clock edge; it does
        not assert reset immediately. The infrastructure input aresetn
        asserts reset asynchronously. Both use the controlled two-edge
        release, followed by request rearming. There is no completion ACK.
        """
        base = self.shadow & ~(LOAD | SHIFT | RESET)
        self.write_command(base | RESET)
        self.write_command(base)

    def operate(self, *, data=None, serial=None, load=False, shift=False):
        base = self.shadow & ~(LOAD | SHIFT | RESET)
        if data is not None:
            if not 0 <= data <= 15:
                raise ValueError("data must be between 0 and 15")
            base = (base & ~DATA_MASK) | int(data)
        if serial is not None:
            if serial not in (0, 1):
                raise ValueError("serial must be 0 or 1")
            base = (base & ~SERIAL) | (int(serial) << 4)
        self.write_command(base)  # data stable; sample zero to rearm.
        self.write_command(base | (LOAD if load else 0) | (SHIFT if shift else 0))
        return self.write_command(base)  # consumed before return to zero.

    def load(self, value):
        return self.operate(data=value, load=True)

    def shift_bit(self, bit):
        return self.operate(serial=bit, shift=True)

    def select(self, mode):
        if mode not in (0, 1):
            raise ValueError("mode must be 0 or 1")
        return self.write_command((self.shadow & ~MODE) | (int(mode) << 5))

    def states(self):
        """Read each stored value via the existing output MUX; restore mode."""
        saved_mode = bool(self.shadow & MODE)
        parallel_value = self.select(0)
        shift_value = self.select(1)
        self.select(int(saved_mode))
        return parallel_value, shift_value
