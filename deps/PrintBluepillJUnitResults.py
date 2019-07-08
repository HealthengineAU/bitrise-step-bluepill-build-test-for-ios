##
# Print JUnit Test Results.
#
# - Description: Only prints iOS-formatted results (AllTests > Suites > Subsuites > Cases).
#
# - Usage:
#   - `python3 PrintBluepillJUnitResults.py <XML file>`
#
# - Arguments:
#   - JUnit results XML file
#   - [optional] Format (e.g. "terminal" or "slack") (default: "terminal")
#
# - Dependencies:
#   - Python 3
#   - Requires junitparser (`pip3 install junitparser`)
##

import sys
from junitparser import TestCase, TestSuite, JUnitXml, Skipped, Error, Failure

class TestError(object):
    """A nice error wrapper

    Properties:
        - name          e.g. "MyCareTeamTests/testRemoveFromMyCareTeam"

    Attributes:
        - type          e.g. "Failure" or "Error"
        - message       e.g. "No matches found for first match sequence"
        - location      e.g. "XCUIElement+Extension.swift:122"
        - trace         Full stacktrace (as reported by XCTest)
    """

    def __init__(self, testCase, error):
        self.name = "{}/{}".format(testCase.classname, testCase.name)
        self.message = error.message
        self.type = error.type
        self.location = stripAndRemoveNewlines(error._elem.text)
        self.trace = stripAndRemoveNewlines(testCase.system_out)

    def __eq__(self, other):
        return self.uniqueId==other.uniqueId

    def __hash__(self):
        return hash(self.uniqueId)

    @property
    def uniqueId(self):
        """Used for mapping duplicate failures on the same test case.

        Bluepill runs will often retry failed tests.
        String in format: "MyCareTeamTests/testAddToMyCareTeam:Out of bounds exception"
        """
        return "{}:{}".format(self.name, self.message)

class BluepillJUnitReport(JUnitXml):
    """Fix baby"""
    def __iter__(self):
        return super(JUnitXml, self).iterchildren(ParentTestSuite)

class ParentTestSuite(TestSuite):
    """Fix baby"""
    def __iter__(self):
        return super(TestSuite, self).iterchildren(TestSuite)

def stripAndRemoveNewlines(text):
    """Removes empty newlines, and removes leading whitespace.
    """
    no_empty_newlines = "\n".join([ll.rstrip() for ll in text.splitlines() if ll.strip()])
    return no_empty_newlines.strip()

def getLastXLines(string, x):
    return "\n".join(string.split("\n")[-x:])

def getTestErrors(testSuites):
    """Get a collection of bad results in these test suites
    """

    if testSuites.errors == 0 and testSuites.failures == 0:
        return [] # early exit

    testErrors = []

    # Suites (e.g. "UITests.xctest")
    for testSuite in testSuites:
        if testSuite.errors == 0 and testSuite.failures == 0:
            continue # skip

        # Groups (e.g. "MarketplaceTests")
        for testGroup in testSuite:
            if testGroup.errors == 0 and testGroup.failures == 0:
                continue # skip

            # (e.g. "testOpenXMLReader")
            for testCase in testGroup:
                testResult = testCase.result

                if isinstance(testResult, Error) or isinstance(testResult, Failure):
                    testError = TestError(testCase, testResult)
                    testErrors.append(testError)

    return testErrors

def printResults(testErrors):
    """Formatted for terminal output

    MyCareTeamTests/testAddToMyCareTeamButton (1)
    Error: "No matches found for first match sequence"
    Location: XCUIElement+Extension.swift:122
    Trackback:
    XCTestOutputBarrier    t =    14.25s Assertion Failure: XCUIElement+Extension.swift:122: No matches found for first match sequence (
        "&lt;XCTElementFilteringTransformer: 0x6000009d7f90 'Find: Descendants matching type Button'&gt;",
        "&lt;XCTElementFilteringTransformer: 0x6000009e4360 'Find: Elements matching predicate '\"Book\" IN identifiers''&gt;"
    ) from input
        t =    14.32s Tear Down
    """
    uniqueTestErrors = set(testErrors)

    if len(testErrors) == 0:
        print("All tests passed.")
    else:
        print("There were {} unique errors/failures ({} total):\n".format(len(uniqueTestErrors),
                                                                    len(testErrors)))

    for error in uniqueTestErrors:
        occurences = testErrors.count(error)

        print("""\n{e.name} ({occurences})
{e.type}: \t\t"{e.message}"
Location: \t{e.location}
Traceback:\n{trace}\n""".format(e=error,
                                occurences=occurences,
                                trace=error.trace))

def printResultsAsMarkdown(testErrors):
    """Formatted as Markdown (for Slack)

    MyCareTeamTests/testAddToMyCareTeamButton (1)
    XCUIElement+Extension.swift:122 ("No matches found for first match sequence")
    ```XCTestOutputBarrier    t =    14.25s Assertion Failure: XCUIElement+Extension.swift:122: No matches found for first match sequence (
        "&lt;XCTElementFilteringTransformer: 0x6000009d7f90 'Find: Descendants matching type Button'&gt;",
        "&lt;XCTElementFilteringTransformer: 0x6000009e4360 'Find: Elements matching predicate '\"Book\" IN identifiers''&gt;"
    ) from input
        t =    14.32s Tear Down```
    """
    uniqueTestErrors = set(testErrors)

    if len(testErrors) == 0:
        print("All tests passed.")
    else:
        print("There were {} unique errors/failures ({} total):\n".format(len(uniqueTestErrors),
                                                                          len(testErrors)))

    for error in uniqueTestErrors:
        occurences = testErrors.count(error)

        print(""">*{e.name} ({occurences})*
>{e.location} ("{e.message}")
>```{trace}```\n""".format(e=error,
                         occurences=occurences,
                         trace=getLastXLines(error.trace, 5)))

def main():
    """python3 PrintBluepillJUnitResults.py <bluepill_junit_result_file.xml>
    """

    if len(sys.argv) < 2:
        print("Missing argument 1: Input file")

    file = sys.argv[1]
    results = BluepillJUnitReport.fromfile(file)
    testErrors = getTestErrors(results)


    if len(sys.argv) < 3:
        mode = "terminal"
    else:
        mode = sys.argv[2]

    if mode == "markdown":
        printResultsAsMarkdown(testErrors)
    else:
        printResults(testErrors)

if __name__ == "__main__":
    main()
