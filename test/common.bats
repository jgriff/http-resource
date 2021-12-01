#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'

run_with() {
    . "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$1.json)"
}

@test "[common] extracts 'source.url' as variable 'source_url'" {
    run_with "stdin-source"
    assert isSet source_url
    assert_equal "$source_url" 'https://some-server:8443'
}

@test "[common] extracts 'source.username' as variable 'source_username'" {
    run_with "stdin-source-credentials"
    assert isSet source_username
    assert_equal "$source_username" 'a-username'
}

@test "[common] extracts 'source.password' as variable 'source_password'" {
    run_with "stdin-source-credentials"
    assert isSet source_password
    assert_equal "$source_password" 'a-password'
}

@test "[common] extracts 'source.insecure' as variable 'source_insecure'" {
    run_with "stdin-source-insecure"
    assert isSet source_insecure
    assert_equal "$source_insecure" 'true'
}

@test "[common] extracts 'source.method' as variable 'source_method'" {
    run_with "stdin-source-method"
    assert isSet source_method
    assert_equal "$source_method" 'PUT'
}

@test "[common] defaults 'source_url' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_url
    assert_equal "$source_url" ''
}

@test "[common] defaults 'source_username' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_username
    assert_equal "$source_username" ''
}

@test "[common] defaults 'source_password' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_password
    assert_equal "$source_password" ''
}

@test "[common] defaults 'source_insecure' to false" {
    run_with "stdin-source-empty"
    assert_equal "$source_insecure" 'false'
}

@test "[common] defaults 'source_method' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_method
    assert_equal "$source_method" ''
}
