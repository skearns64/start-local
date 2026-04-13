#!/bin/bash
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

CURRENT_DIR=$(pwd)
DEFAULT_DIR="${CURRENT_DIR}/elastic-start-local"
ENV_PATH="${DEFAULT_DIR}/.env"
UNINSTALL_FILE="${DEFAULT_DIR}/uninstall.sh"

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    sh "${CURRENT_DIR}/${SCRIPT_FILE}" --no-container
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function tear_down_after_script() {
    printf "yes\n" | "${UNINSTALL_FILE}"
    rm -rf "${DEFAULT_DIR}"
}

function test_stop() {
    "${DEFAULT_DIR}/stop.sh"

    result=$(get_http_response_code "http://localhost:9200" "elastic" "${ES_LOCAL_PASSWORD}")
    assert_equals "000" "$result"

    assert_file_not_exists "${DEFAULT_DIR}/elasticsearch.pid"
    assert_file_not_exists "${DEFAULT_DIR}/kibana.pid"
}

function test_start() {
    "${DEFAULT_DIR}/start.sh"

    # Wait for Elasticsearch to be ready after restart
    timeout=120
    start_time="$(date +%s)"
    until curl -s -o /dev/null -w '%{http_code}' -u "elastic:${ES_LOCAL_PASSWORD}" \
        http://localhost:9200 | grep -q '200'; do
        elapsed_time="$(($(date +%s) - start_time))"
        if [ "$elapsed_time" -ge "$timeout" ]; then
            echo "Error: Elasticsearch did not restart within ${timeout} sec."
            return 1
        fi
        sleep 2
    done

    result=$(get_http_response_code "http://localhost:9200" "elastic" "${ES_LOCAL_PASSWORD}")
    assert_equals "200" "$result"
}
