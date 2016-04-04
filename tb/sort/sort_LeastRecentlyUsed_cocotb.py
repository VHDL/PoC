import cocotb
from cocotb.triggers import Timer

@cocotb.test()
def my_first_test(dut):
    """
    Try accessing the design
    """
    dut.log.info("Running test!")
    for cycle in range(10):
        dut.Clock = 0
        yield Timer(1000) # ps
        dut.Clock = 1
        yield Timer(1000) # ps
    dut.log.info("Running test!")
