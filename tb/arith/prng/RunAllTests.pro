# =============================================================================
# Authors:
#	Jonas Schreiner
# =============================================================================

TestSuite PoC.arith.prng

library tb_arith_PRNG

analyze arith_PRNG_TestController.vhdl
analyze arith_PRNG_TestHarness.vhdl

# Test Cases
RunTest arith_PRNG_Simple.vhdl
