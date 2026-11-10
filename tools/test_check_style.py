#!/usr/bin/env python3
"""Proves check_style.py catches each rule it claims to enforce."""
import tempfile
import unittest
from pathlib import Path

import check_style

LONG_COMMENT = "// " + "x" * 70
BAD_SWIFT = """
let globalValue = 3 """ + LONG_COMMENT + """
enum BadState {
    case badCase
}
struct bad_Type {
    static let lowerConstant = 1
    var camelCase: Int = 0
    func Bad_Name(first: Int, second: Int, third: Int, fourth: Int) {}
    func tooLong() {
""" + "        print(1)\n" * 25 + """    }
    func branchy(value: Int) -> Int {
        if value > 0 && value < 2 || value == 3 { return 1 }
        if value == 4 { return 1 }; if value == 5 { return 1 }
        if value == 6 { return 1 }; if value == 7 { return 1 }
        if value == 8 { return 1 }; if value == 9 { return 1 }
        return value ?? 0
    }
}
"""
GOOD_SWIFT = """
let MAX_ITEMS = 3

enum GoodState {
    case failed(exit_Status: Int32, error_Text: String)
    case not_Running
}

struct GoodType {
    static let DEFAULT_SIZE = 1
    var item_Count: Int = 0

    // style:allow-params documented exception
    func makeThing(first: Int, second: Int, third: Int, fourth: Int) {
        for item_Index in 0..<first { print(item_Index) }
    }
}
"""


def checkSource(source_Text):
    with tempfile.TemporaryDirectory() as directory_Name:
        root_Path = Path(directory_Name)
        (root_Path / "Sources").mkdir()
        (root_Path / "Package.swift").write_text("")
        sample_Path = root_Path / "Sources" / "Sample.swift"
        sample_Path.write_text(source_Text)
        checker = check_style.StyleChecker()
        checker.checkTree(root_Path)
        return "\n".join(checker.violations)


class CheckStyleTests(unittest.TestCase):
    def testBadSourceTripsEveryRule(self):
        report_Text = checkSource(BAD_SWIFT)
        for expected_Text in (
                "constant 'globalValue'", "type 'bad_Type'",
                "constant 'lowerConstant'", "variable 'camelCase'",
                "variable 'badCase'",
                "function 'Bad_Name'", "parameters: 4",
                "length: ", "complexity: ", "width: "):
            self.assertIn(expected_Text, report_Text)

    def testGoodSourcePasses(self):
        self.assertEqual(checkSource(GOOD_SWIFT), "")


if __name__ == "__main__":
    unittest.main()
