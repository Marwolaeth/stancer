# NOTE ON TEST STRUCTURE:
# These tests achieve decent coverage by extensively mocking external LLM API calls.
# Because the package logic is tightly integrated with asynchronous and
# non-deterministic model responses, the mocking setup (using mockery or stubs)
# may appear somewhat verbose, awkward, or clumsy. This approach is intentional.
library(testthat)
library(stancer)

test_check("stancer")
