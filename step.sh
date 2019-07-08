#!/bin/bash
set -e

# Dependency directories
STEP_DIR="$( dirname "${BASH_SOURCE[0]}" )"
DEPS_DIR="$STEP_DIR/deps"

# ---  1. INSTALL DEPENDENCIES ---

bluepill_formulae_file="$DEPS_DIR/brew-formulae/$bluepill_version/bluepill.rb"

# Check if the Bluepill formulae is supported
if [ -f "$bluepill_formulae_file" ]; then
  printf "\n\nInstalling Bluepill ($bluepill_version/bluepill.rb)...\n"

  brew list bluepill \
    && echo "  ...already installed." \
    || brew install "$bluepill_formulae_file"
else
  printf "Unrecognised Bluepill version identifier passed: '$bluepill_version'\n"
  exit -1
fi

printf "\n\nInstalling junitparser...\n"

# Install junitparser to run the `PrintBluepillJUnitResults.py` script for parsing test results
# Allow this part to fail silently
set +e
brew list python3 || brew install python3 && brew postinstall python3
pip3 install junitparser
set -e

# ---  2. BUILD ---

printf "\n\nBuilding App...\n"

# Use xcpretty to pipe pretty build logs if available, otherwise cat
# Not going to require this as a hard dependency because it's just a nice-to-have.
XCPRETTY_OR_CAT=$(which xcpretty && echo xcpretty || echo cat)

# Build for testing
xcodebuild build-for-testing \
  -derivedDataPath "${derived_data_path}" \
  -workspace "${workspace}" \
  -scheme "${scheme}" \
  -destination "platform=iOS Simulator,name=${device_type},OS=${ios_version}" \
  -enableCodeCoverage "YES" \
  | eval $XCPRETTY_OR_CAT

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

# ...renable failures.
set -e

# Parse results
if [ -f "$bluepill_formulae_file" ]; then
  results_full=$( printf "$( python3 "$DEPS_DIR/PrintBluepillJUnitResults.py" "${report_output_dir}/TEST-FinalReport.xml" )" )
  results_markdown=$( printf "$( python3 "$DEPS_DIR/PrintBluepillJUnitResults.py" "${report_output_dir}/TEST-FinalReport.xml" )" slack )
else
  results_full="Bluepill failed to generate a final test report."
  results_markdown="$results_full"
fi

# --- 4. COLLECT COVERAGE ---

# Don't fail the build if coverage fail...
set +e

coverage_file="${bluepill_output_dir}/${target_name}.app.coverage.txt"

# Merge coverage profile
xcrun llvm-profdata merge \
    -sparse \
    -o ${bluepill_output_dir}/Coverage.profdata \
    ${bluepill_output_dir}/**/**/*.profraw \
    || coverage_failed=true

# Generate coverage report
if ! [ "$coverage_failed" == "true" ]; then
  xcrun llvm-cov show \
      -instr-profile ${bluepill_output_dir}/Coverage.profdata \
      ${derived_data_path}/Build/Products/*/${target_name}.app/${target_name} \
      > ${coverage_file} \
      || coverage_failed=true
fi

# ...renable failures.
set -e

# --- 5. EXPORT ENV VARS ---

# Test results (human readable)
envman add --key "${test_result_env_var}" --value "$results_full"
envman add --key "${test_result_env_var}_MARKDOWN" --value "$results_markdown"

# --- 6. PRINT TEST RESULTS TO CONSOLE ---

printf "$results_full"

# --- 7. PASS/FAIL THE STEP ---

# Fail the step if there was an error
if [ "$tests_failed" == "true" ]
then
  exit -1
fi

# Coverage logging
if [ "$coverage_failed" == "true" ]; then
  if [ "$fail_build_if_coverage_fails" == "true" ]; then
    printf "\nFailed to gather coverage data and \$fail_build_if_coverage_fails is set to true.\n"
    exit -1
  else
    printf "\nFailed to gather coverage data but \$fail_build_if_coverage_fails is set to false.\n"
  fi
else
  printf "\nCoverage report generated at: $coverage_file\n"
fi

exit 0
