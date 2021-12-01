#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

#setup() {
    # do any general setup
#}

source_out() {
    stdin_payload=${1:-"stdin-source"}
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
    source "$SUT_ASSETS_DIR/out"
}

teardown() {
    # teardown without strictly asserting invocations
    unstub curl 2> /dev/null || true
}

@test "[out] changes into sources directory given" {
    source_out

    sourcesDirectory "$BATS_TEST_TMPDIR"

    # assert that we changed into the directory
    assert_equal $(realpath $BATS_TEST_TMPDIR) $(realpath $PWD)
}

@test "[out] invokes the endpoint with POST by default" {
    source_out

    putResource

    assert_equal "$method" "POST"
}

@test "[out] invokes the endpoint with method configured in source" {
    source_out "stdin-source-method"

    putResource

    assert_equal "$method" "PUT"
}

@test "[out] invokes the endpoint with method configured in params" {
    source_out "stdin-source-params-method"

    putResource

    assert_equal "$method" "HEAD"
}

@test "[out] invokes endpoint with source headers" {
    source_out "stdin-source-headers"

    target_dir=$BATS_TEST_TMPDIR

    putResource

    # assert we populated the headers file for the request
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Accept:/p" | cut -d':' -f2-) 'application/json'
    assert_equal $(cat $request_headers | sed -n -e "/^Source-Header:/p" | cut -d':' -f2-) 'source-value'
}

@test "[out] invokes endpoint with param headers" {
    source_out "stdin-source-params-headers"

    target_dir=$BATS_TEST_TMPDIR

    putResource

    # assert we populated the headers file for the request
    assert [ -e "$request_headers" ]
    assert_equal $(cat $request_headers | sed -n -e "/^Accept:/p" | cut -d':' -f2-) 'application/octet-stream'
    assert_equal $(cat $request_headers | sed -n -e "/^Param-Header:/p" | cut -d':' -f2-) 'param-value'
}

@test "[out] invokes endpoint with source headers and param headers" {
    source_out "stdin-source-headers-params-headers"

    target_dir=$BATS_TEST_TMPDIR

    putResource

    # assert we populated the headers file for the request
    assert [ -e "$request_headers" ]

    # source headers and param headers
    assert_equal $(cat $request_headers | sed -n -e "/^Source-Header:/p" | cut -d':' -f2-) 'source-value'
    assert_equal $(cat $request_headers | sed -n -e "/^Param-Header:/p" | cut -d':' -f2-) 'param-value'
}

@test "[out] invokes endpoint with data text" {
    source_out "stdin-source-params-data-text"

    target_dir=$BATS_TEST_TMPDIR

    putResource

    assert_equal "${expanded_data[0]}" "-d"
    assert_equal "${expanded_data[1]}" "some-data"
}

@test "[out] emits the version" {
    source_out

    version="the-version"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.version.version' <<< "$output")" 'the-version'
}

@test "[out] emits the http method in the metadata" {
    source_out

    method=POST
    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "method") | .value ' <<< "$output")" "POST"
}

@test "[out] emits the url in the metadata" {
    source_out

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "url") | .value ' <<< "$output")" "https://some-server:8443"
}

@test "[out] emits the http response status in the metadata" {
    source_out

    response_status="HTTP/1.1 200 OK"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '.metadata[] | select(.name == "status") | .value ' <<< "$output")" "HTTP/1.1 200 OK"
}

@test "[out] fails if response status is 4xx" {
    source_out

    echo "HTTP/1.1 400 BAD REQUEST" > $response_headers

    run putResource

    # it should fail
    assert_failure
}

@test "[out] fails if response status is 5xx" {
    source_out

    echo "HTTP/1.1 500 INTERNAL SERVER ERROR" > $response_headers

    run putResource

    # it should fail
    assert_failure
}

@test "[out] fails if both 'text' and 'file' are configured" {
    source_out "stdin-source-params-data-file-and-text"

    run putResource

    # it should fail
    assert_failure
}
