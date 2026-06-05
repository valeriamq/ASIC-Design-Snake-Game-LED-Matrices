# SPDX-FileCopyrightText: © 2026 Tu Nombre
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_project(dut): # <-- CAMBIAMOS EL NOMBRE AQUÍ
    """Testbench: Simulates the game at the physical pin level"""
    
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("--- [TB] Starting up and resetting ---")
    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.ui_in.value = 0x00 
    dut.rst_n.value = 0
    
    await ClockCycles(dut.clk, 60)

    dut._log.info("--- [TB] Reset Unlocked  ---")
    dut.rst_n.value = 1
    
    await ClockCycles(dut.clk, 60)

    uo_out_str = str(dut.uo_out.value)
    dut._log.info(f"--- [TB] Initial state of the uo_out outputs: {uo_out_str} ---")
    assert "x" not in uo_out_str, f"Error: Undefined signals in uo_out: {uo_out_str}"
    assert "z" not in uo_out_str, f"Error: Floating signals in uo_out: {uo_out_str}"

    # 3. Presionar Botón ARRIBA (Mapeado en ui_in[3])
    # En binario, poner en '1' el bit 3 es 0b00001000 = 8
    dut._log.info("--- [TB] Pressing the UP button  ---")
    dut.ui_in.value = 8
    await ClockCycles(dut.clk, 60) 

    # Soltamos el botón de dirección
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 60)

    dut._log.info("--- [TB] ¡TEST PASS! ---")