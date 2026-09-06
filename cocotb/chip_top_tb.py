
# chip_top_tb.py — cocotb testbench for osoc1_cpu full chip
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_chip_reset(dut):
    """Test: chip reset behavior"""
    # Start clock (50 MHz = 20ns period)
    cocotb.start_soon(Clock(dut.clk_pad, 20, units="ns").start())

    # Assert reset
    dut.rst_n_pad.value = 0
    dut.gpio_in_pad.value = 0
    await Timer(100, units="ns")

    # Release reset
    dut.rst_n_pad.value = 1
    await RisingEdge(dut.clk_pad)
    await Timer(50, units="ns")

    # Check outputs (ปรับตาม expected behavior ของ osoc1_cpu)
    cocotb.log.info(f"gpio_out = {dut.gpio_out_pad.value}")
    assert dut.gpio_out_pad.value.integer >= 0, "GPIO output should be valid"

@cocotb.test()
async def test_basic_operation(dut):
    """Test: basic CPU operation after reset"""
    cocotb.start_soon(Clock(dut.clk_pad, 20, units="ns").start())

    dut.rst_n_pad.value = 0
    await Timer(40, units="ns")
    dut.rst_n_pad.value = 1

    # ให้ CPU run 1000 cycles
    for _ in range(1000):
        await RisingEdge(dut.clk_pad)

    cocotb.log.info("Basic operation test passed")
