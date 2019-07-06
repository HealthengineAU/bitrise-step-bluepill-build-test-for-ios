#!/bin/bash
set -e

# ---  1. INSTALL DEPENDENCIES ---

printf "\n\nInstalling dependencies...\n"

# Supported Bluepill versions and their associated brew commits
bluepill_4_1_1__xcode_10_2=1ed242fd12ded7f685ec67128ec739e6a9e1baa3
bluepill_3_1_1__xcode_10_1=a07abe758e78d90cd178b4f3207c84a181237206
bluepill_3_1_0__xcode_10_0=7fb99338e66b1ce1dd0d8f1a83051f8e9a044770
bluepill_2_4_0__xcode_9_4=0f881ea1286274f62a9fa6e649985b7e6599cd11
bluepill_2_3_1__xcode_9_3=5f8348a9f1f17d9d2f2e57f3b7981f3248bd5e82
bluepill_2_2_0__xcode_9_2=86beeb08e9f7f9e9e435fa9fe1250729ae3a677e
bluepill_2_1_0__xcode_9_1=c740eba675f665946c4af57f9fef2c1cae07c8a7
bluepill_2_0_2__xcode_9_0=c78ab93d962f9287cc90cb40ad13a398020a5744
bluepill_1_1_2__xcode_8_3=976ae7613ed70fa25139cc52e511005558100b35

if [ -z "${!bluepill_version}" ];then
  echo "Unrecognised Bluepill version passed: $bluepill_version"
  exit -1
fi

# Install Bluepill (if none installed already)
brew list bluepill \
  || brew install "https://raw.githubusercontent.com/Homebrew/homebrew-core/${!bluepill_version}/Formula/bluepill.rb"

# Install Python 3 (if none installed already)
brew list python3 \
  || brew install python3 \
  && brew postinstall python3

# Install junitparser and the `PrintBluepillJUnitResults.py` Python 3 script for parsing test results
pip3 install junitparser
curl -L https://git.io/fj6hp > PrintBluepillJUnitResults.py

# ---  2. BUILD ---

printf "\n\nBuilding App...\n"

# Build for testing
xcodebuild build-for-testing \
  -derivedDataPath "${derived_data_path}" \
  -workspace "${workspace}" \
  -scheme "${scheme}" \
  -destination "platform=iOS Simulator,name=${device_type},OS=${ios_version}" \
  -enableCodeCoverage "YES"

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
results_markdown=$( printf "$( python3 PrintBluepillJUnitResults.py "${report_output_dir}/TEST-FinalReport.xml" )" slack )

# --- 4. COLLECT COVERAGE ---

# Merge coverage profile
xcrun llvm-profdata merge \
    -sparse \
    -o ${bluepill_output_dir}/Coverage.profdata \
    ${bluepill_output_dir}/**/**/*.profraw

# Generate coverage report
xcrun llvm-cov show \
    -instr-profile ${bluepill_output_dir}/Coverage.profdata \
    ${derived_data_path}/Build/Products/*/${target_name}.app/${target_name} \
    > ${bluepill_output_dir}/${target_name}.app.coverage.txt

# --- 5. EXPORT ENV VARS ---

# Test results (human readable)
envman add --key "${test_result_env_var}" --value "$results_full"
envman add --key "${test_result_env_var}_MARKDOWN" --value "$results_markdown"

# --- 6. PRINT TEST RESULTS ---

printf "$results_full"

# --- 7. PASS/FAIL THE STEP ---

# Fail the step if there was an error
if [ $tests_failed ]
then
    exit -1
fi

exit 0
