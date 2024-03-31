# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/pip_install/private:generate_whl_library_build_bazel.bzl", "generate_whl_library_build_bazel")  # buildifier: disable=bzl-visibility

_tests = []

def _test_simple(env):
    want = """\
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "dist_info",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "data",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "whl",
    srcs = ["foo.whl"],
    data = [
        "@pypi_bar_baz//:whl",
        "@pypi_foo//:whl",
    ],
    visibility = ["//visibility:public"],
)

py_library(
    name = "pkg",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude=[],
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = [] + glob(
        ["site-packages/**/*"],
        exclude=["**/* *", "**/*.py", "**/*.pyc", "**/*.pyc.*", "**/*.dist-info/RECORD"],
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = [
        "@pypi_bar_baz//:pkg",
        "@pypi_foo//:pkg",
    ],
    tags = ["tag1", "tag2"],
    visibility = ["//visibility:public"],
)
"""
    actual = generate_whl_library_build_bazel(
        repo_prefix = "pypi_",
        whl_name = "foo.whl",
        dependencies = ["foo", "bar-baz"],
        dependencies_by_platform = {},
        data_exclude = [],
        tags = ["tag1", "tag2"],
        entry_points = {},
        annotation = None,
    )
    env.expect.that_str(actual).equals(want)

_tests.append(_test_simple)

def _test_dep_selects(env):
    want = """\
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "dist_info",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "data",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "whl",
    srcs = ["foo.whl"],
    data = [
        "@pypi_bar_baz//:whl",
        "@pypi_foo//:whl",
    ] + select(
        {
            "@//python/config_settings:is_python_3.9": ["@pypi_py39_dep//:whl"],
            "@platforms//cpu:aarch64": ["@pypi_arm_dep//:whl"],
            "@platforms//os:windows": ["@pypi_win_dep//:whl"],
            ":is_cp310_linux_ppc": ["@pypi_py310_linux_ppc_dep//:whl"],
            ":is_cp39_anyos_aarch64": ["@pypi_py39_arm_dep//:whl"],
            ":is_cp39_linux_anyarch": ["@pypi_py39_linux_dep//:whl"],
            ":is_linux_x86_64": ["@pypi_linux_intel_dep//:whl"],
            "//conditions:default": [],
        },
    ),
    visibility = ["//visibility:public"],
)

py_library(
    name = "pkg",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude=[],
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = [] + glob(
        ["site-packages/**/*"],
        exclude=["**/* *", "**/*.py", "**/*.pyc", "**/*.pyc.*", "**/*.dist-info/RECORD"],
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = [
        "@pypi_bar_baz//:pkg",
        "@pypi_foo//:pkg",
    ] + select(
        {
            "@//python/config_settings:is_python_3.9": ["@pypi_py39_dep//:pkg"],
            "@platforms//cpu:aarch64": ["@pypi_arm_dep//:pkg"],
            "@platforms//os:windows": ["@pypi_win_dep//:pkg"],
            ":is_cp310_linux_ppc": ["@pypi_py310_linux_ppc_dep//:pkg"],
            ":is_cp39_anyos_aarch64": ["@pypi_py39_arm_dep//:pkg"],
            ":is_cp39_linux_anyarch": ["@pypi_py39_linux_dep//:pkg"],
            ":is_linux_x86_64": ["@pypi_linux_intel_dep//:pkg"],
            "//conditions:default": [],
        },
    ),
    tags = ["tag1", "tag2"],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "is_linux_ppc",
    constraint_values = [
        "@platforms//cpu:ppc",
        "@platforms//os:linux",
    ],
    visibility = ["//visibility:private"],
)

selects.config_setting_group(
    name = "is_cp310_linux_ppc",
    match_all = [
        ":is_linux_ppc",
        "@//python/config_settings:is_python_3.10",
    ],
    visibility = ["//visibility:private"],
)

config_setting(
    name = "is_anyos_aarch64",
    constraint_values = ["@platforms//cpu:aarch64"],
    visibility = ["//visibility:private"],
)

selects.config_setting_group(
    name = "is_cp39_anyos_aarch64",
    match_all = [
        ":is_anyos_aarch64",
        "@//python/config_settings:is_python_3.9",
    ],
    visibility = ["//visibility:private"],
)

config_setting(
    name = "is_linux_anyarch",
    constraint_values = ["@platforms//os:linux"],
    visibility = ["//visibility:private"],
)

selects.config_setting_group(
    name = "is_cp39_linux_anyarch",
    match_all = [
        ":is_linux_anyarch",
        "@//python/config_settings:is_python_3.9",
    ],
    visibility = ["//visibility:private"],
)

config_setting(
    name = "is_linux_x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    visibility = ["//visibility:private"],
)
"""
    actual = generate_whl_library_build_bazel(
        repo_prefix = "pypi_",
        whl_name = "foo.whl",
        dependencies = ["foo", "bar-baz"],
        dependencies_by_platform = {
            "@//python/config_settings:is_python_3.9": ["py39_dep"],
            "@platforms//cpu:aarch64": ["arm_dep"],
            "@platforms//os:windows": ["win_dep"],
            "cp310_linux_ppc": ["py310_linux_ppc_dep"],
            "cp39_anyos_aarch64": ["py39_arm_dep"],
            "cp39_linux_anyarch": ["py39_linux_dep"],
            "linux_x86_64": ["linux_intel_dep"],
        },
        data_exclude = [],
        tags = ["tag1", "tag2"],
        entry_points = {},
        annotation = None,
    )
    env.expect.that_str(actual.replace("@@", "@")).equals(want)

_tests.append(_test_dep_selects)

def _test_with_annotation(env):
    want = """\
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "dist_info",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "data",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "whl",
    srcs = ["foo.whl"],
    data = [
        "@pypi_bar_baz//:whl",
        "@pypi_foo//:whl",
    ],
    visibility = ["//visibility:public"],
)

py_library(
    name = "pkg",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude=["srcs_exclude_all"],
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = ["file_dest", "exec_dest"] + glob(
        ["site-packages/**/*"],
        exclude=["**/* *", "**/*.py", "**/*.pyc", "**/*.pyc.*", "**/*.dist-info/RECORD", "data_exclude_all"],
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = [
        "@pypi_bar_baz//:pkg",
        "@pypi_foo//:pkg",
    ],
    tags = ["tag1", "tag2"],
    visibility = ["//visibility:public"],
)

copy_file(
    name = "file_dest.copy",
    src = "file_src",
    out = "file_dest",
    is_executable = False,
)

copy_file(
    name = "exec_dest.copy",
    src = "exec_src",
    out = "exec_dest",
    is_executable = True,
)

# SOMETHING SPECIAL AT THE END
"""
    actual = generate_whl_library_build_bazel(
        repo_prefix = "pypi_",
        whl_name = "foo.whl",
        dependencies = ["foo", "bar-baz"],
        dependencies_by_platform = {},
        data_exclude = [],
        tags = ["tag1", "tag2"],
        entry_points = {},
        annotation = struct(
            copy_files = {"file_src": "file_dest"},
            copy_executables = {"exec_src": "exec_dest"},
            data = [],
            data_exclude_glob = ["data_exclude_all"],
            srcs_exclude_glob = ["srcs_exclude_all"],
            additive_build_content = """# SOMETHING SPECIAL AT THE END""",
        ),
    )
    env.expect.that_str(actual).equals(want)

_tests.append(_test_with_annotation)

def _test_with_entry_points(env):
    want = """\
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "dist_info",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "data",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "whl",
    srcs = ["foo.whl"],
    data = [
        "@pypi_bar_baz//:whl",
        "@pypi_foo//:whl",
    ],
    visibility = ["//visibility:public"],
)

py_library(
    name = "pkg",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude=[],
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = [] + glob(
        ["site-packages/**/*"],
        exclude=["**/* *", "**/*.py", "**/*.pyc", "**/*.pyc.*", "**/*.dist-info/RECORD"],
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = [
        "@pypi_bar_baz//:pkg",
        "@pypi_foo//:pkg",
    ],
    tags = ["tag1", "tag2"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "rules_python_wheel_entry_point_fizz",
    srcs = ["buzz.py"],
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
    deps = [":pkg"],
)
"""
    actual = generate_whl_library_build_bazel(
        repo_prefix = "pypi_",
        whl_name = "foo.whl",
        dependencies = ["foo", "bar-baz"],
        dependencies_by_platform = {},
        data_exclude = [],
        tags = ["tag1", "tag2"],
        entry_points = {"fizz": "buzz.py"},
        annotation = None,
    )
    env.expect.that_str(actual).equals(want)

_tests.append(_test_with_entry_points)

def _test_group_member(env):
    want = """\
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "dist_info",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "data",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "_whl",
    srcs = ["foo.whl"],
    data = ["@pypi_bar_baz//:whl"] + select(
        {
            "@platforms//os:linux": ["@pypi_box//:whl"],
            ":is_linux_x86_64": [
                "@pypi_box//:whl",
                "@pypi_box_amd64//:whl",
            ],
            "//conditions:default": [],
        },
    ),
    visibility = ["@pypi__groups//:__pkg__"],
)

py_library(
    name = "_pkg",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude=[],
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = [] + glob(
        ["site-packages/**/*"],
        exclude=["**/* *", "**/*.py", "**/*.pyc", "**/*.pyc.*", "**/*.dist-info/RECORD"],
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = ["@pypi_bar_baz//:pkg"] + select(
        {
            "@platforms//os:linux": ["@pypi_box//:pkg"],
            ":is_linux_x86_64": [
                "@pypi_box//:pkg",
                "@pypi_box_amd64//:pkg",
            ],
            "//conditions:default": [],
        },
    ),
    tags = [],
    visibility = ["@pypi__groups//:__pkg__"],
)

config_setting(
    name = "is_linux_x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    visibility = ["//visibility:private"],
)

alias(
    name = "pkg",
    actual = "@pypi__groups//:qux_pkg",
)

alias(
    name = "whl",
    actual = "@pypi__groups//:qux_whl",
)
"""
    actual = generate_whl_library_build_bazel(
        repo_prefix = "pypi_",
        whl_name = "foo.whl",
        dependencies = ["foo", "bar-baz", "qux"],
        dependencies_by_platform = {
            "linux_x86_64": ["box", "box-amd64"],
            "windows_x86_64": ["fox"],
            "@platforms//os:linux": ["box"],  # buildifier: disable=unsorted-dict-items to check that we sort inside the test
        },
        tags = [],
        entry_points = {},
        data_exclude = [],
        annotation = None,
        group_name = "qux",
        group_deps = ["foo", "fox", "qux"],
    )
    env.expect.that_str(actual.replace("@@", "@")).equals(want)

_tests.append(_test_group_member)

def generate_build_bazel_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
