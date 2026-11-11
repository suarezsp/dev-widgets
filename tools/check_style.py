#!/usr/bin/env python3
"""Checks the DevWidgets house rules that SwiftLint cannot express.

Rules: lines <= 70 columns, functions <= 25 lines, <= 3 parameters,
cyclomatic complexity <= 10 (15 with `style:complex`), and naming:
MAYUS_NAME constants, this_Name variables, thisName functions,
PascalCase types. Exit status 1 when any violation is found.
"""
import re
import sys
from pathlib import Path

MAX_COLUMNS = 70
MAX_FUNCTION_LINES = 25
MAX_PARAMETERS = 3
MAX_COMPLEXITY = 10
MAX_COMPLEX_COMPLEXITY = 15
SCANNED_DIRECTORIES = ["Sources", "Tests", "macOS"]
EXTRA_FILES = ["Package.swift"]
WIDTH_ONLY_GLOBS = ["tools/*.py", "tools/*.sh"]
# Names imposed by Apple frameworks or SwiftPM, not chosen by us.
FRAMEWORK_NAMES = {
    "typeDisplayRepresentation", "caseDisplayRepresentations",
    "package", "isDiscoverable", "willPresent", "didReceive",
    "wrappedValue", "defaultValue",
}
# Top-level code of these files may bind constants or variables.
SCRIPT_FILES = ("main.swift", "Package.swift")
ALLOW_PARAMS_MARK = "style:allow-params"
COMPLEX_MARK = "style:complex"

TYPE_NAME = re.compile(r"^[A-Z][A-Za-z0-9]*$")
FUNCTION_NAME = re.compile(r"^[a-z][A-Za-z0-9]*$")
CONSTANT_NAME = re.compile(r"^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$")
VARIABLE_NAME = re.compile(r"^[a-z][a-z0-9]*(_[A-Z][A-Za-z0-9]*)*$")

MODIFIERS = (r"(?:(?:public|private|fileprivate|internal|static|"
             r"mutating|override|final|nonisolated|class|"
             r"private\(set\))\s+)*")
FUNCTION_START = re.compile(
    r"^\s*(?:@\w+\s+)*" + MODIFIERS +
    r"(?:func\s+(?P<name>[^\s(<]+)|init\??)\s*[<(]")
COMPUTED_START = re.compile(
    r"^\s*(?:@\w+\s+)*" + MODIFIERS +
    r"var\s+(?P<name>\w+)\s*:[^=]*\{\s*$")
TYPE_DECLARATION = re.compile(
    r"\b(?:struct|class|enum|protocol|actor|typealias)\s+"
    r"(?P<name>\w+)")
BINDING = re.compile(
    r"(?P<static>\bstatic\s+)?\b(?:let|var)\s+(?P<name>\w+)")
LOOP_OR_CLOSURE = re.compile(
    r"\bfor\s+(?P<loop>\w+)\s+in\b|\{\s*(?P<params>[\w\s,]+)\s+in\b")
ENUM_CASE = re.compile(r"^\s*case\s+(?P<names>[a-z][\w\s,()?:]*)$")
DECISION = re.compile(
    r"\b(?:if|guard|for|while|case|catch)\b|&&|\|\||\?\?|\s\?\s")
STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
TUPLE_BINDING = re.compile(r"\b(?:let|var)\s*\((?P<names>[\w\s,]+)\)")


def stripCode(line):
    """Drops string contents and trailing // comments."""
    without_Strings = STRING_LITERAL.sub('""', line)
    return without_Strings.split("//", 1)[0]


def findBlockEnd(code_Lines, start_Index):
    """Index of the line closing the block opened at start_Index,
    or None for declarations without a body."""
    brace_Depth = 0
    has_Opened = False
    for line_Index in range(start_Index, len(code_Lines)):
        for character in code_Lines[line_Index]:
            if character == "{":
                brace_Depth += 1
                has_Opened = True
            elif character == "}":
                brace_Depth -= 1
        if brace_Depth < 0:
            return None
        if has_Opened and brace_Depth == 0:
            return line_Index
    return None


def splitTopLevel(text):
    """Splits on commas that are not nested in () or []."""
    parts, current_Part, nesting = [], "", 0
    for character in text.replace("->", "  "):
        if character in "([<":
            nesting += 1
        elif character in ")]>":
            nesting -= 1
        if character == "," and nesting == 0:
            parts.append(current_Part)
            current_Part = ""
        else:
            current_Part += character
    parts.append(current_Part)
    return [part.strip() for part in parts if part.strip()]


def extractParameters(code_Lines, start_Index, name_End):
    """Returns the parameter declarations of a func or init."""
    window_Lines = code_Lines[start_Index:start_Index + 12]
    signature_Text = " ".join(window_Lines)
    open_Index = signature_Text.index("(", name_End)
    nesting = 0
    for character_Index in range(open_Index, len(signature_Text)):
        character = signature_Text[character_Index]
        nesting += {"(": 1, ")": -1}.get(character, 0)
        if nesting == 0:
            return splitTopLevel(
                signature_Text[open_Index + 1:character_Index])
    return []


def parameterNames(parameter_Text):
    """`from previous: T` -> ["from", "previous"]."""
    head_Text = parameter_Text.split(":", 1)[0]
    words = head_Text.replace("inout", "").split()
    return [word for word in words
            if word != "_" and word.isidentifier()]


def complexityOf(block_Lines):
    """1 + decision points (if, guard, loops, case, &&, ||, ??)."""
    decision_Counts = (len(DECISION.findall(line))
                       for line in block_Lines)
    return 1 + sum(decision_Counts)


class StyleChecker:
    def __init__(self):
        self.violations = []

    def report(self, file_Path, line_Number, message):
        self.violations.append(
            f"{file_Path}:{line_Number}: {message}")

    def checkName(self, location, name, pattern, kind_Text):
        if name in FRAMEWORK_NAMES or pattern.match(name):
            return
        self.report(*location, f"naming: {kind_Text} '{name}'")

    def checkWidth(self, file_Path, raw_Lines):
        for line_Index, line in enumerate(raw_Lines):
            if len(line) > MAX_COLUMNS:
                self.report(file_Path, line_Index + 1,
                            f"width: {len(line)} > {MAX_COLUMNS}")

    def checkSwiftFile(self, file_Path):
        raw_Lines = file_Path.read_text().splitlines()
        code_Lines = [stripCode(line) for line in raw_Lines]
        self.checkWidth(self.current_Path, raw_Lines)
        is_Script = file_Path.name in SCRIPT_FILES
        for line_Index, code_Line in enumerate(code_Lines):
            location = (self.current_Path, line_Index + 1)
            self.checkDeclarations(location, code_Line, is_Script)
            self.checkFunction(raw_Lines, code_Lines, line_Index)

    def checkDeclarations(self, location, code_Line, is_Script):
        for match in TYPE_DECLARATION.finditer(code_Line):
            if match["name"] not in ("func", "var", "let"):
                self.checkName(location, match["name"], TYPE_NAME,
                               "type")
        is_Top_Level = not code_Line[:1].isspace()
        for match in BINDING.finditer(code_Line):
            if is_Top_Level and is_Script and \
                    CONSTANT_NAME.match(match["name"]):
                continue
            is_Constant = bool(match["static"]) or (
                is_Top_Level and not is_Script
                and code_Line.startswith("let"))
            is_Static_Var = bool(match["static"]) and " var " in \
                f" {code_Line[match.start():match.end()]} "
            self.checkBinding(location, match["name"],
                              is_Constant and not is_Static_Var)
        self.checkLocalNames(location, code_Line)

    def checkBinding(self, location, name, is_Constant):
        if is_Constant:
            self.checkName(location, name, CONSTANT_NAME, "constant")
        else:
            self.checkName(location, name, VARIABLE_NAME, "variable")

    def checkLocalNames(self, location, code_Line):
        names = []
        for match in TUPLE_BINDING.finditer(code_Line):
            names += match["names"].split(",")
        for match in LOOP_OR_CLOSURE.finditer(code_Line):
            names += (match["loop"] or match["params"]).split(",")
        enum_Match = ENUM_CASE.match(code_Line)
        bare_Case = re.sub(r"\(.*\)", "", code_Line)
        if enum_Match and ":" not in bare_Case:
            case_Names = re.sub(r"\([^)]*\)", "", enum_Match["names"])
            names += case_Names.split(",")
        for name in (part.strip() for part in names):
            if name and name != "_":
                self.checkName(location, name, VARIABLE_NAME,
                               "variable")

    def checkFunction(self, raw_Lines, code_Lines, line_Index):
        function_Match = FUNCTION_START.match(code_Lines[line_Index])
        computed_Match = COMPUTED_START.match(code_Lines[line_Index])
        if not function_Match and not computed_Match:
            return
        end_Index = findBlockEnd(code_Lines, line_Index)
        location = (self.current_Path, line_Index + 1)
        if function_Match:
            self.checkSignature(raw_Lines, code_Lines, line_Index,
                                function_Match)
        if end_Index is None:
            return
        self.checkBody(location, raw_Lines, code_Lines,
                       (line_Index, end_Index))

    def checkSignature(self, raw_Lines, code_Lines, line_Index,
                       function_Match):
        location = (self.current_Path, line_Index + 1)
        name = function_Match["name"]
        if name and name.isidentifier():
            self.checkName(location, name, FUNCTION_NAME, "function")
        parameters = extractParameters(code_Lines, line_Index,
                                       function_Match.end() - 1)
        for parameter in parameters:
            for word in parameterNames(parameter):
                self.checkName(location, word, VARIABLE_NAME,
                               "parameter")
        preceding_Text = " ".join(raw_Lines[max(0, line_Index - 3):
                                            line_Index + 1])
        if len(parameters) > MAX_PARAMETERS and \
                ALLOW_PARAMS_MARK not in preceding_Text:
            self.report(*location, f"parameters: {len(parameters)}"
                        f" > {MAX_PARAMETERS}")

    def checkBody(self, location, raw_Lines, code_Lines, block_Range):
        start_Index, end_Index = block_Range
        line_Count = end_Index - start_Index + 1
        if line_Count > MAX_FUNCTION_LINES:
            self.report(*location, f"length: {line_Count} lines"
                        f" > {MAX_FUNCTION_LINES}")
        complexity = complexityOf(
            code_Lines[start_Index:end_Index + 1])
        preceding_Text = " ".join(raw_Lines[max(0, start_Index - 3):
                                            start_Index + 1])
        limit = MAX_COMPLEX_COMPLEXITY if COMPLEX_MARK in \
            preceding_Text else MAX_COMPLEXITY
        if complexity > limit:
            self.report(*location,
                        f"complexity: {complexity} > {limit}")

    def checkTree(self, root_Path):
        swift_Paths = [root_Path / name for name in EXTRA_FILES]
        for directory in SCANNED_DIRECTORIES:
            directory_Path = root_Path / directory
            if not directory_Path.is_dir():
                continue
            swift_Paths += sorted(directory_Path.rglob("*.swift"))
        for swift_Path in swift_Paths:
            self.current_Path = swift_Path.relative_to(root_Path)
            self.checkSwiftFile(swift_Path)
        for pattern in WIDTH_ONLY_GLOBS:
            for other_Path in sorted(root_Path.glob(pattern)):
                self.checkWidth(other_Path.relative_to(root_Path),
                                other_Path.read_text().splitlines())
        return len(swift_Paths)


def main():
    root_Path = Path(__file__).resolve().parent.parent
    checker = StyleChecker()
    file_Count = checker.checkTree(root_Path)
    for violation in checker.violations:
        print(violation)
    print(f"check_style: {file_Count} Swift files, "
          f"{len(checker.violations)} violations")
    return 1 if checker.violations else 0


if __name__ == "__main__":
    sys.exit(main())
