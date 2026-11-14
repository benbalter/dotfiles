#!/usr/bin/env bats
# ios/privacy.mobileconfig: a profile installed by hand on an unsupervised
# iPhone or iPad. Python's plistlib rather than plutil, so this also runs on
# the Ubuntu CI job.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
PROFILE="$REPO_ROOT/ios/privacy.mobileconfig"

# Restrictions keys Apple's schema allows without supervision, from
# github.com/apple/device-management mdm/profiles/com.apple.applicationaccess.yaml.
# An unsupervised device silently ignores a supervised-only key, so a key added
# here must be checked against that schema first.
UNSUPERVISED_KEYS="allowApplePersonalizedAdvertising allowDiagnosticSubmission forceLimitAdTracking safariForceFraudWarning safariAcceptCookies"

# profile <python expression over `p`, the parsed profile>
profile() {
	python3 -I -c "import plistlib, sys; p = plistlib.load(open(sys.argv[1], 'rb')); print($1)" "$PROFILE"
}

@test "iOS profile parses and every payload has an identifier and UUID" {
	run profile 'all(d.get("PayloadIdentifier") and d.get("PayloadUUID") for d in [p] + p["PayloadContent"])'
	[ "$status" -eq 0 ] || fail "$output"
	[ "$output" = True ] || fail "a payload is missing PayloadIdentifier or PayloadUUID"
	run profile 'len({d["PayloadUUID"] for d in [p] + p["PayloadContent"]}) == len(p["PayloadContent"]) + 1'
	[ "$output" = True ] || fail "payload UUIDs repeat"
}

@test "iOS profile uses only Restrictions keys that work without supervision" {
	run profile '"\n".join(k for d in p["PayloadContent"] if d["PayloadType"] == "com.apple.applicationaccess" for k in d if not k.startswith("Payload"))'
	[ "$status" -eq 0 ] || fail "$output"
	for key in $output; do
		case " $UNSUPERVISED_KEYS " in
			*" $key "*) ;;
			*) fail "$key isn't in the unsupervised allowlist; check Apple's schema before adding it" ;;
		esac
	done
}

@test "iOS profile names no person" {
	# The repo is public, and a profile's identifier and text show on the device.
	! grep -Eiq 'balter|@[a-z0-9-]+\.[a-z]' "$PROFILE" || fail "the profile names someone"
}
