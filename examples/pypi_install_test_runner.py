import atexit
import os
import re
import subprocess
import shutil
import sys
import time
import threading
import tempfile
from pathlib import Path
from typing import List

from python.runfiles import runfiles

RUNFILES = runfiles.Create()

BIT_BAZEL_BINARY = Path(os.environ["BIT_BAZEL_BINARY"])
BIT_WORKSPACE_DIR = Path(os.environ["BIT_WORKSPACE_DIR"])

CREATE_SCRATCH_DIR = RUNFILES.Rlocation("rules_bazel_integration_test/tools/create_scratch_dir.sh")

PYPI_URL_MATCH = re.compile(f"http://localhost:\d+/packages")

def log(*text: List[str]):
    sys.stdout.write(" ".join(str(t) for t in text))
    sys.stdout.write("\n")
    sys.stdout.flush()

def make_scratch_dir() -> Path:
    scratch_dir = Path(subprocess.check_output([
        CREATE_SCRATCH_DIR,
        "--workspace",
        BIT_WORKSPACE_DIR,
    ]).decode("utf-8").strip())

    def clean_scratch_dir():
        log("Cleaning the scratch directory.")
        shutil.rmtree(scratch_dir)

    atexit.register(clean_scratch_dir)

    return scratch_dir

def start_pypiserver(cwd: Path, bazel_args: List[str]) -> int:
    env = os.environ.copy()
    env.pop("RUNFILES_DIR", None)
    env.pop("RUNFILES_MANIFEST_FILE", None)
    env.pop("PYTHONPATH", None)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_file_path = Path(temp_dir) / "output"

        with temp_file_path.open("w") as temp_file:

            for port in range(8989, 10000):
                log("Starting pypiserver.")
                pypiserver = subprocess.Popen([
                    BIT_BAZEL_BINARY,
                    "run",
                    "//wheels:pypiserver_runner",
                ] + bazel_args + [
                    "--",
                    f"--port={port}",
                ], stdout=temp_file, stderr=subprocess.STDOUT, cwd=cwd, env=env)

                def stop_pypiserver():
                    log("Stopping pypiserver.")
                    pypiserver.terminate()
                    pypiserver.wait()

                while True:
                    output = temp_file_path.read_text()
                    if "Hit Ctrl-C to quit" in output:
                        break
                    if pypiserver.poll() is not None:
                        stop_pypiserver()
                        if "Address already in use" in output:
                            continue
                        raise RuntimeError("Failed to execute pypiserver")
                    time.sleep(0.5)

                atexit.register(stop_pypiserver)

                return port

            raise RuntimeError("Could not find an available port for pypiserver.")

def fix_up_intermediate_files(cwd: Path, port: int):
    for filename in cwd.glob("intermediate_file_*.json"):
        text = filename.read_text()
        text = PYPI_URL_MATCH.sub(f"http://localhost:{port}/packages", text)
        filename.write_text(text)

def main(argv):
    if bool(os.environ["PYPI_INSTALL_USE_BZLMOD"]):
        bazel_args = ["--noenable_bzlmod"]
    else:
        bazel_args = ["--enable_bzlmod"]

    scratch_dir = make_scratch_dir()
    log("Made scratch directory:", scratch_dir)
    log("Bazel", BIT_BAZEL_BINARY)
    port = start_pypiserver(scratch_dir, bazel_args)
    log("Started pypiserver at port", port)
    fix_up_intermediate_files(scratch_dir, port)
    log("Fixed up intermediate files")

    subprocess.check_call([BIT_BAZEL_BINARY, "test", "//..."] + bazel_args, cwd=scratch_dir)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
