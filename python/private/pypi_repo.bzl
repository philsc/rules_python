# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:normalize_name.bzl", "normalize_name")
load(":pypi_util.bzl", "generate_repo_name_for_download", "generate_repo_name_for_extracted_wheel")

def pypi_install(pip_installation_report = None, **kwargs):
    pip_install_dependencies()
    _pypi_install(pip_installation_report = pip_installation_report, **kwargs)

def _clean_info(info):
    result = dict(**info)
    if "deps" in result:
        result["deps"] = [normalize_name(dep) for dep in result["deps"]]
    return result

def _clean_intermediate(intermediate):
    result = {}
    for package, info_per_config in intermediate.items():
        result[normalize_name(package)] = {
            config: _clean_info(info)
            for config, info in info_per_config.items()
        }
    return result

def _pypi_install_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "\n", executable = False)
    if repository_ctx.attr.pip_installation_report:
        intermediate, config_settings = _combine_intermediate_files(
            repository_ctx,
            repository_ctx.attr.pip_installation_report,
        )
    else:
        intermediate = {}
        config_settings = sets.make([])

    lines = ["INTERMEDIATE = {}".format(json.encode_indent(_clean_intermediate(intermediate))), ""]
    repository_ctx.file("intermediate.bzl", "\n".join(lines), executable = False)

    lines = ["CONFIGS = {}".format(json.encode_indent(sets.to_list(config_settings))), ""]
    repository_ctx.file("configs.bzl", "\n".join(lines), executable = False)

    lines = [
        """load("@rules_python//python/private:pypi_repo.bzl",""",
        """    _load_pypi_packages_internal="load_pypi_packages_internal",""",
        """    _generate_package_aliases="generate_package_aliases",""",
        """)""",
        """load("@{}//:intermediate.bzl", "INTERMEDIATE")""".format(repository_ctx.name),
        """def load_pypi_packages(name, **kwargs):""",
        """    _load_pypi_packages_internal(INTERMEDIATE,""",
        """                                intermediate_repo_name="{}",""".format(repository_ctx.name),
        """                               alias_repo_name=name,""",
        """                               **kwargs)""",
        """    _generate_package_aliases(name=name, intermediate="@{}//:intermediate.bzl", **kwargs)""".format(repository_ctx.name),
    ]
    repository_ctx.file("packages.bzl", "\n".join(lines), executable = False)

_pypi_install = repository_rule(
    implementation = _pypi_install_impl,
    attrs = {
        "pip_installation_report": attr.label_list(
            allow_files = True,
        ),
    },
)

def _combine_intermediate_files(repository_ctx, installation_reports):
    combined = {}
    all_configs = sets.make([])

    # TODO(phil): Figure out how to deal with a single intermediate file. What
    # "config" setting should that have?
    for intermediate_label in installation_reports:
        intermediate = json.decode(repository_ctx.read(intermediate_label))
        for package in intermediate:
            config_settings = intermediate[package].keys()
            if len(config_settings) != 1:
                fail("Expected 1 config setting for package %s in %s, but got %d." %
                     (package, intermediate_label, len(config_settings)))
            config_setting = config_settings[0]
            sets.insert(all_configs, config_setting)

            info = combined.setdefault(package, {})
            if config_setting in info:
                fail("Two intermediate files have the same config setting for package %s in %s." %
                     (package, intermediate_label))
            info[config_setting] = intermediate[package][config_setting]

    return combined, all_configs

def load_pypi_packages_internal(intermediate, intermediate_repo_name, alias_repo_name, **kwargs):
    # Only download a wheel/tarball once. We do this by tracking which SHA sums
    # we've downloaded already.
    sha_indexed_infos = {}

    for package, configs in intermediate.items():
        for config, info in configs.items():
            if info["sha256"] not in sha_indexed_infos:
                _generate_http_file(package, info)

                # TODO(phil): What do we need to track here? Can we switch to a
                # set()?
                sha_indexed_infos[info["sha256"]] = True

                # TODO(phil): Do we need to support individual py_library
                # targets per config? Should only be an issue if someone needs
                # to assemble a runfiles tree with multiple configurations in
                # it.
                # TODO(phil): Can we add target_compatible_with information
                # here?
                _generate_py_library(package, config, info, intermediate_repo_name, alias_repo_name)

def _generate_http_file(package, info):
    http_file(
        name = generate_repo_name_for_download(package, info),
        urls = [
            info["url"],
        ],
        sha256 = info["sha256"],
        downloaded_file_path = paths.basename(info["url"]),
    )

def _generate_py_library(package, config, info, intermediate_repo_name, alias_repo_name):
    _wheel_library_repo(
        name = generate_repo_name_for_extracted_wheel(package, info),
        alias_repo_name = alias_repo_name,
        wheel_repo_name = generate_repo_name_for_download(package, info),
        intermediate_repo_name = intermediate_repo_name,
        intermediate_package = package,
        intermediate_config = config,
    )

def _wheel_library_repo_impl(repository_ctx):
    lines = [
        """load("@rules_python//python/private:pypi.bzl", "wrapped_py_wheel_library")""",
        """load("@{}//:intermediate.bzl", "INTERMEDIATE")""".format(repository_ctx.attr.intermediate_repo_name),
        """load("@{}//:configs.bzl", "CONFIGS")""".format(repository_ctx.attr.intermediate_repo_name),
        """wrapped_py_wheel_library(""",
        """    name="library",""",
        """    alias_repo_name="{}",""".format(repository_ctx.attr.alias_repo_name),
        """    wheel_repo_name="{}",""".format(repository_ctx.attr.wheel_repo_name),
        """    intermediate=INTERMEDIATE,""",
        """    all_configs=CONFIGS,""",
        """    package="{}",""".format(repository_ctx.attr.intermediate_package),
        """)""",
    ]
    repository_ctx.file("BUILD.bazel", "\n".join(lines), executable = False)

_wheel_library_repo = repository_rule(
    implementation = _wheel_library_repo_impl,
    attrs = {
        "alias_repo_name": attr.string(),
        "wheel_repo_name": attr.string(),
        "intermediate_repo_name": attr.string(),
        "intermediate_package": attr.string(),
        "intermediate_config": attr.string(),
    },
)

def _generate_package_aliases_impl(repository_ctx):
    bzl_intermediate = repository_ctx.read(repository_ctx.path(repository_ctx.attr.intermediate))
    if not bzl_intermediate.startswith("INTERMEDIATE = "):
        fail("Expected intermediate.bzl to start with 'INTERMEDIATE = '. Did the implementation get out of sync?")
    intermediate = json.decode(bzl_intermediate[len("INTERMEDIATE = "):])

    for package in intermediate:
        lines = [
            """load("{}", "INTERMEDIATE")""".format(repository_ctx.attr.intermediate),
            """load("@rules_python//python/private:pypi.bzl", _generate_package_alias="generate_package_alias")""",
            """_generate_package_alias(INTERMEDIATE)""",
        ]
        repository_ctx.file("{}/BUILD.bazel".format(package), "\n".join(lines), executable = False)

generate_package_aliases = repository_rule(
    implementation = _generate_package_aliases_impl,
    attrs = {
        "intermediate": attr.label(
            allow_single_file = True,
        ),
    },
)
