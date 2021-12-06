#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

#setup() {
    # do any general setup
#}

source_in() {
    stdin_payload=${1:-"stdin-source-with-version"}
    curl_response_headers=${2:-"curl-response-headers.txt"}
    curl_response_body=${3:-"curl-response-body.json"}

    # source the common script
    source "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
    #log() { echo "$@"; } # use this during development to see log output
    log() { :; }
    export -f log

    # create some tmp files
    request_headers="$BATS_TEST_TMPDIR/request_headers"
    response_headers="$BATS_TEST_TMPDIR/response_headers"
    response_body="$BATS_TEST_TMPDIR/response_body"

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
    source "$SUT_ASSETS_DIR/in"
}

teardown() {
    # teardown without strictly asserting invocations
    unstub curl 2> /dev/null || true
}

@test "[in] requested version is extracted" {
    source_in

    extractVersion

    assert_equal "$requestedVersion" 'some-version-from-check'
}

@test "[in] fetches the resource" {
    source_in

    target_dir=$BATS_TEST_TMPDIR
    version="some-version-from-check"

    fetchResource

    # then a 'headers' file contains the response headers
    retrieved_headers="$BATS_TEST_TMPDIR/headers"
    assert [ -e "$retrieved_headers" ]
    assert_equal $(cat $retrieved_headers | sed -n -e "/^Some-Header:/p" | cut -d':' -f2-) 'some-header-value'

    # and a 'body' file contains the response body
    retrieved_body="$BATS_TEST_TMPDIR/body"
    assert [ -e "$retrieved_body" ]
    assert_equal "$(jq -r '.some' < "$retrieved_body")" 'response'
}

@test "[in] fetches the resource with source headers" {
    source_in "stdin-source-headers"

    fetchResource

    # assert we populated the headers file correctly
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Accept:/p" | cut -d':' -f2-) 'application/json'
    assert_equal $(cat $request_headers | sed -n -e "/^Source-Header:/p" | cut -d':' -f2-) 'source-value'
}

@test "[in] fetches the resource with param headers" {
    source_in "stdin-source-params-headers"

    fetchResource

    # assert we populated the headers file correctly
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Accept:/p" | cut -d':' -f2-) 'application/octet-stream'
    assert_equal $(cat $request_headers | sed -n -e "/^Param-Header:/p" | cut -d':' -f2-) 'param-value'
}

@test "[in] fetches the resource with source and param headers" {
    source_in "stdin-source-headers-params-headers"

    fetchResource

    # assert we populated the headers file correctly
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Source-Header:/p" | cut -d':' -f2-) 'source-value'
    assert_equal $(cat $request_headers | sed -n -e "/^Param-Header:/p" | cut -d':' -f2-) 'param-value'
}

@test "[in] fetch will fail if 'strict' param is 'true' and the requested version does not match current version" {
    source_in "stdin-source-params-strict-with-version"

    target_dir=$BATS_TEST_TMPDIR
    requestedVersion="some-version-from-check-that-does-not-match"

    run fetchResource

    # it should fail
    assert_failure

    # and the 'headers' and 'body' files should be empty
    refute [ -s "$BATS_TEST_TMPDIR/headers" ]
    refute [ -s "$BATS_TEST_TMPDIR/body" ]
}

@test "[in] emits the version of the fetched resource" {
    source_in

    requestedVersion="the-version-requested-by-check"
    version="the-version-just-fetched"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.version.version' <<< "$output")" 'the-version-just-fetched'
}

@test "[in] emits the version requested by check when the fetched version cannot be determined" {
    source_in

    requestedVersion="the-version-requested-by-check"
    retrievedVersion=""

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.version.version' <<< "$output")" 'the-version-requested-by-check'
}

@test "[in] emits the http method in the metadata" {
    source_in

    method=GET
    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "method") | .value ' <<< "$output")" "GET"
}

@test "[in] emits the url in the metadata" {
    source_in

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "url") | .value ' <<< "$output")" "https://some-server:8443"
}

@test "[in] emits the http response status in the metadata" {
    source_in

    retrievedVersion="the-version-just-fetched"

    response_status="HTTP/1.1 200 OK"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "status") | .value ' <<< "$output")" "HTTP/1.1 200 OK"
}

@test "[in] fails if response status is 4xx" {
    source_in "stdin-source-with-version" "curl-response-headers-4xx.txt"

    target_dir=$BATS_TEST_TMPDIR
    requestedVersion="some-version"

    run fetchResource

    # it should fail
    assert_failure
}

@test "[in] fails if response status is 5xx" {
    source_in "stdin-source-with-version" "curl-response-headers-5xx.txt"

    target_dir=$BATS_TEST_TMPDIR
    requestedVersion="some-version"

    run fetchResource

    # it should fail
    assert_failure
}

@test "[in] no-op if source config 'out_only' is 'true'" {
    source_in "stdin-source-out_only-true"

    output=$(main 5>&1 1>&2)

    # echoes back the same version it was given
    assert_equal "$(jq -r '.version.version ' <<< "$output")" "some-previous-version"

    # and the status in the metadata indicates it was a no-op
    assert_equal "$(jq -r '.metadata[] | select(.name == "status") | .value ' <<< "$output")" "no-op"
}

@test "[in] e2e in" {
    source_in

    echo "HTTP/1.1 200 OK" > $response_headers
    output=$(main 5>&1 1>&2)

    # should emit the version attribute
    assert_equal "$(jq -r '.version.version' <<< "$output")" 'abc-123'

    # includes the http response in the resource's metadata
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "status" and .value == "HTTP/1.1 200 OK")' <<< "$output")" 'true'
}
