--!strict
-- The slow test suite: only tests registered with t.slow (whole AI matches,
-- fairness runs). The integration check runs it; `lune run test` doesn't.
--   lune run test_slow [filter]
(_G :: any).FTGG_TEST_MODE = "slow"
require("./test")
