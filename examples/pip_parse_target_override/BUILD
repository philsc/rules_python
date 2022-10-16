load("@rules_python//python:defs.bzl", "py_test")
load("@rules_python//python:pip.bzl", "compile_pip_requirements")
load("@pypi//:requirements.bzl", "requirement")

py_test(
    name = "test",
    srcs = ["test.py"],
    deps = [
        requirement("requests"),
    ],
)

# This rule adds a convenient way to update the requirements file.
compile_pip_requirements(
    name = "requirements",
    extra_args = ["--allow-unsafe"],
    requirements_in = "requirements.in",
    requirements_txt = "requirements_lock.txt",
)
