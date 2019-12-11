<p align="center">
  <img width="256" height="256" src="https://i.imgur.com/3RIso4i.png">
</p>

# Bluepill Build/Test for iOS

A Bitrise Step for running iOS UI/Unit Tests in parallel (using multiple simulators) with [linkedin/bluepill](https://github.com/linkedin/bluepill).

## Features

- Running tests in parallel by using multiple simulators.
- Automatically packing tests into groups.
- Running tests in headless mode to reduce memory consumption.
- Generating a junit report after each test run.
- Reporting test running stats, including test running speed and environment robustness.
- Retrying when the Simulator hangs or crashes.

## More Information
- See [linkedin/bluepill](https://github.com/linkedin/bluepill) for full configuration options.

## Acknowledgement (from [linkedin/bluepill](https://github.com/linkedin/bluepill))
- Bluepill was inspired by [parallel iOS test](https://github.com/plu/parallel_ios_tests) and Facebook’s [xctool](https://github.com/facebook/xctool) and [FBSimulatorControl](https://github.com/facebook/FBSimulatorControl).
- The Bluepill icon was created by [Maria Iu](https://www.linkedin.com/in/mariaiu/)

# Publish updates to the official Bitrise Step Library
```bash
# 1. Install Bitrise CLI tool (if not already installed)
$ brew update && brew install bitrise

# 2. Fork official Bitrise StepLib
# (On Github) https://github.com/bitrise-io/bitrise-steplib

# 3. Publish your change to any StepLib fork
$ bitrise share start -c git@github.com:[your-username]/bitrise-steplib.git
$ bitrise share create --git https://github.com/HealthEngineAU/bitrise-step-bluepill-build-test-for-ios.git --stepid bluepill-build-test-for-ios --tag [step-version-tag]
$ bitrise share finish

# 4. Finish & submit to the official StepLib
# (On Github) https://github.com/[your-username]/bitrise-steplib.git
```
