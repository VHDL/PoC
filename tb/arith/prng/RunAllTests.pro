# =============================================================================
# Authors:
#	Jonas Schreiner
# =============================================================================

TestSuite PoC.arith.prng

library tb_arith_prng

analyze arith_prng_TestController.vhdl
analyze arith_prng_TestHarness.vhdl

# Test Cases
RunTest arith_prng_Simple.vhdl
