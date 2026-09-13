#!/usr/bin/env bash
# Shared bats helpers.
#
# Provides fail(), which bats itself does not define -- it ships with
# bats-support/bats-assert, which this repo deliberately does not vendor so the
# suite runs identically under brew bats-core (macOS CI) and apt bats (Linux CI).

fail() {
	echo "$@" >&2
	return 1
}
