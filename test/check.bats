#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

#setup() {
    # do any general setup
#}

source_check() {
    stdin_payload=${1:-"stdin-source"}
    curl_response_headers=${2:-"curl-response-headers.txt"}
    curl_response_body=${3:-"curl-response-body.json"}

    # source the common script
    source "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
    #log() { echo -e "$@"; } # use this during development to see log output
    log() { :; }
    export -f log

    # create some tmp files
    request_headers="$BATS_TEST_TMPDIR/request_headers"
    response_headers="$BATS_TEST_TMPDIR/response_headers"
    response_body="$BATS_TEST_TMPDIR/response_body"

    # mock curl to expect our invocation
    if [ $curl_response == "FAIL" ]; then
        stub curl "exit 1"
    else
        # mock the headers response, which are written by curl's '-D' option to a file
        cat $BATS_TEST_DIRNAME/fixtures/$curl_response_headers > $response_headers

        # stub the invocation and echo the mock response body
        stub curl "cat $BATS_TEST_DIRNAME/fixtures/$curl_response_body"
    fi

    # source the sut
    source "$SUT_ASSETS_DIR/curlops"
    source "$SUT_ASSETS_DIR/check"
}

teardown() {
    # teardown without strictly asserting invocations
    unstub curl 2> /dev/null || true
}

@test "[check] invokes endpoint with method 'GET' by default" {
    source_check

    checkResource

    assert_equal "$method" "GET"
}

@test "[check] invokes endpoint with method configured in source" {
    source_check "stdin-source-method"

    checkResource

    assert_equal "$method" "PUT"
}

@test "[check] invokes endpoint with username/password" {
    source_check "stdin-source-credentials"

    checkResource

    assert_equal "${expanded_options[0]}" "-u"
    assert_equal "${expanded_options[1]}" "a-username:a-password"
}

@test "[check] invokes endpoint with --insecure" {
    source_check "stdin-source-insecure"

    checkResource

    assert_equal "${expanded_options[0]}" "--insecure"
}

@test "[check] invokes endpoint with source headers" {
    source_check "stdin-source-headers"

    checkResource

    # assert we populated the headers file correctly
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Accept:/p" | cut -d':' -f2-) 'application/json'
    assert_equal $(cat $request_headers | sed -n -e "/^Source-Header:/p" | cut -d':' -f2-) 'source-value'
}

@test "[check] invokes endpoint with source data text" {
    source_check "stdin-source-data-text"

    checkResource

    assert_equal "${expanded_data[0]}" "-d"
    assert_equal "${expanded_data[1]}" "some-source-data"
}

@test "[check] determines version from jq query of response body" {
    source_check stdin-source-version-jq

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" 'abc-123'
}

@test "[check] determines version from response header" {
    source_check stdin-source-version-header

    determineVersion

    assert_equal "$version" '1'
}

@test "[check] determines version from hash digest of response headers" {
    source_check stdin-source-version-hash-headers

    determineVersion

    assert_equal "$version" '066a07b2138ac71a14900fa52e4e0995a547d4b2'
}

@test "[check] determines version from hash digest of response body" {
    source_check stdin-source-version-hash-body

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] determines version from hash digest of response headers + body" {
    source_check stdin-source-version-hash-full

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" 'b2aacf40fc9e4d03ef1afdb59239e13784e09b5d'
}

@test "[check] determines version from jq query first, then header" {
    source_check stdin-source-version-jq-and-header

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '1'
}

@test "[check] determines version from jq query first, then header, then hash digest" {
    source_check stdin-source-version-jq-and-header-and-hash

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '066a07b2138ac71a14900fa52e4e0995a547d4b2'
}

@test "[check] determines version from jq query first, then header, then default to 'hash' (by default)" {
    source_check stdin-source-version-jq-and-header-default

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] determines version from jq query first, then header, then default to 'hash' (explicitly)" {
    source_check stdin-source-version-jq-and-header-default-hash

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] determines version from jq query first, then header, then default to 'none'" {
    source_check stdin-source-version-jq-and-header-default-none

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" ''
}

@test "[check] determines version from hash digest when no version strategy configured" {
    source_check

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] determines version from hash digest when default is 'hash'" {
    source_check stdin-source-version-default-hash

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] determines version to be empty string when default is 'none'" {
    source_check stdin-source-version-default-none

    # given a response body...
    cat $BATS_TEST_DIRNAME/fixtures/curl-response-body.json > $response_body

    determineVersion

    assert_equal "$version" ''
}

@test "[check] e2e initial check with default hash digest of response body as version" {
    source_check

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] e2e initial check with jq version" {
    source_check stdin-source-version-jq

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" 'abc-123'
}

@test "[check] e2e initial check with header version" {
    source_check stdin-source-version-header

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" '1'
}

@test "[check] e2e initial check with hash digest of response headers as version" {
    source_check stdin-source-version-hash-headers

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" '066a07b2138ac71a14900fa52e4e0995a547d4b2'
}

@test "[check] e2e initial check with hash digest of response body as version" {
    source_check stdin-source-version-hash-body

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] e2e initial check with hash digest of full response as version" {
    source_check stdin-source-version-hash-full

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" 'b2aacf40fc9e4d03ef1afdb59239e13784e09b5d'
}

@test "[check] e2e initial check with default version of 'hash' yields digest of response body as version" {
    source_check stdin-source-version-default-hash

    output=$(main 5>&1 1>&2)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '1'
    assert_equal "$(jq -r '.[0].version' <<< "$output")" '70fea65041d5c7cda924db721e5162b8a243afb8'
}

@test "[check] e2e initial check with default version of 'none' yields no versions" {
    source_check stdin-source-version-default-none

    output=$(main 5>&1 1>&2)

    # should emit an empty version list
    assert_equal $(jq length <<< "$output") 0
}

@test "[check] no-op if source config 'out_only' is 'true'" {
    source_check stdin-source-out_only-true

    output=$(main 5>&1 1>&2)

    # should emit an empty version list
    assert_equal $(jq length <<< "$output") 0
}

@test "[check] (gh-8) includes option '--head' when method is HEAD" {
    source_check "stdin-source-method-head"

    checkResource

    assert_equal "${expanded_options[0]}" "--head"
}

@test "[check] (gh-8) includes option '--head' when method is HEAD (case insensitive)" {
    source_check "stdin-source-method-head-crazycase"

    checkResource

    assert_equal "${expanded_options[0]}" "--head"
}
