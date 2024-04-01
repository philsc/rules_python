import argparse
import shutil
import sys
import tempfile
from pathlib import Path

from pypiserver.__main__ import main as pypiserver_main

from python.runfiles import runfiles

RUNFILES = runfiles.Create()

def run_pypiserver(wheelhouse: Path, port: int):
    sys.argv = [
        "pypiserver",
        "run",
        # Specify -v so that we get a message when the server has started up.
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
    parser.add_argument("wheel", nargs="+", action="extend")
    args = parser.parse_args(argv[1:])

    print("Starting up pypiserver_runner.")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        wheelhouse = tmpdir / "wheelhouse"
        wheelhouse.mkdir()

        for wheel in args.wheel:
            shutil.copy(wheel, wheelhouse)

        run_pypiserver(wheelhouse, args.port)


if __name__ == "__main__":
    print("Starting up pypiserver_runner.")
    sys.exit(main(sys.argv))
