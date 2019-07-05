#!/bin/bash
set -e

# ---  1. INSTALL DEPENDENCIES ---

printf "\n\nInstalling dependencies...\n"

# Install Bluepill 4.1.1
# https://github.com/linkedin/bluepill
brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/1ed242fd12ded7f685ec67128ec739e6a9e1baa3/Formula/bluepill.rb

# Install junitparser for parsing test results
pip3 install junitparser
result_parser_url="https://gist.githubusercontent.com/reececomo/81b64b1a3423d9b793f3c610897ab590/raw/6839897c18eb6ecc1a367c40bf96cf1c86360501/PrintBluepillJUnitResults.py"
curl ${result_parser_url} > 'PrintBluepillJUnitResults.py'

# ---  2. BUILD ---

printf "\n\nBuilding App...\n"

# Build for testing
xcodebuild build-for-testing \
  -derivedDataPath "${derived_data_path}" \
  -workspace "${workspace}" \
  -scheme "${scheme}" \
  -destination "platform=iOS Simulator,name=${device_type},OS=${ios_version}" \
  -enableCodeCoverage "YES" \
  | xcpretty

# ---  3. RUN TESTS --- #

printf "\n\nRunning Tests...\n"

# Report name (e.g. "iPhone 6 - 12.2 - 1762297376")
report_name="${device_type} - ${ios_version} - $( date '+%s' )"
report_output_dir="${bluepill_output_dir}/${report_name}"

# Don't fail the build if tests fail...
set +e

# Run tests with Bluepill
bluepill --xctestrun-path "${derived_data_path}"/Build/Products/*.xctestrun \
    -r "iOS ${ios_version}" \
    -d "${device_type}" \
    -o "${report_output_dir}/" \
    -n ${num_simulators} \
    -f ${failure_tolerance} \
    -F ${retry_only_failed_tests} \
    -H on ${additional_bluepill_args} \
    || tests_failed=true

# ...renable failures for the remainder of the script.
set -e

# Parse results
results_full=$( printf "$( python3 PrintBluepillJUnitResults.py "${report_output_dir}/TEST-FinalReport.xml" )" )
results_slack=$( printf "$( python3 PrintBluepillJUnitResults.py "${report_output_dir}/TEST-FinalReport.xml" )" slack )

# --- 4. COLLECT COVERAGE ---

# Merge coverage profile
xcrun llvm-profdata merge \
    -sparse \
    -o ${bluepill_output_dir}/Coverage.profdata \
    ${bluepill_output_dir}/**/**/*.profraw

# Generate coverage report
xcrun llvm-cov show \
    -instr-profile ${bluepill_output_dir}/Coverage.profdata \
    ${derived_data_path}/Build/Products/*/${app_name}.app/${app_name} \
    > ${bluepill_output_dir}/${app_name}.app.coverage.txt

# --- 5. EXPORT ENV VARS ---

# Test results (human readable)
envman add --key "${test_result_env_var}" --value "$results_full"
envman add --key "${test_result_env_var}_SLACK" --value "$results_slack"

# --- 6. PRINT TEST RESULTS ---

printf "$results_full"

# --- 7. PASS/FAIL THE STEP ---

# Fail the step if there was an error
if [ $tests_failed ]
then
    exit -1
fi

exit 0
