import argparse
import shutil
import sys
import tempfile
from pathlib import Path

from pypiserver.__main__ import main as pypiserver_main

from python.runfiles import runfiles

r = runfiles.Create()

WHEELS = (
    "pkg_a-1.0-py3-none-any.whl",
    "pkg_b-1.1-py3-none-any.whl",
    "pkg_c-2.0-py3-none-any.whl",
    "pkg_d-3.0-py3-none-any.whl",
    "pkg_e-4.0-py3-none-any.whl",
    "pkg_f-1.0-py3-none-any.whl",
)

def run_pypiserver(wheelhouse: Path, port: int):
    sys.argv = [
        "pypiserver",
        "run",
        "-v",
        "-p",
        str(port),
        str(wheelhouse),
    ]
    print("Running: " + " ".join(sys.argv))
    pypiserver_main()

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", default=8989, help="Port for pypiserver")
    args = parser.parse_args(argv[1:])

    print("Starting up pypiserver_runner.")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        wheelhouse = tmpdir / "wheelhouse"
        wheelhouse.mkdir()

        for wheel in WHEELS:
            shutil.copy(r.Rlocation("rules_python_pypi_install_example/wheels/{}".format(wheel)), wheelhouse)

        run_pypiserver(wheelhouse, args.port)


if __name__ == "__main__":
    print("Starting up pypiserver_runner.")
    sys.exit(main(sys.argv))
