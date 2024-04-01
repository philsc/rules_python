import atexit
import os
import re
import subprocess
import shutil
import sys
import time
import threading
from pathlib import Path

from python.runfiles import runfiles

RUNFILES = runfiles.Create()

BIT_BAZEL_BINARY = Path(os.environ["BIT_BAZEL_BINARY"])
BIT_WORKSPACE_DIR = Path(os.environ["BIT_WORKSPACE_DIR"])

CREATE_SCRATCH_DIR = RUNFILES.Rlocation("rules_bazel_integration_test/tools/create_scratch_dir.sh")

PYPI_URL_MATCH = re.compile(f"http://localhost:\d+/packages")

def make_scratch_dir() -> Path:
    scratch_dir = Path(subprocess.check_output([
        CREATE_SCRATCH_DIR,
        "--workspace",
        BIT_WORKSPACE_DIR,
    ]).decode("utf-8").strip())

    atexit.register(shutil.rmtree, scratch_dir)

    return scratch_dir

def start_pypiserver(cwd: Path) -> int:
    env = os.environ.copy()
    env.pop("RUNFILES_DIR", None)
    env.pop("RUNFILES_MANIFEST_FILE", None)
    env.pop("PYTHONPATH", None)

    for port in range(8989, 10000):
        print("Trying: ", BIT_BAZEL_BINARY)
        print("cwd: ", cwd)
        pypiserver = subprocess.Popen([
            BIT_BAZEL_BINARY,
            "run",
            "//wheels:pypiserver_runner",
            "--",
            f"--port={port}",
        ], stdout=subprocess.PIPE, cwd=cwd, env=env)

        output = ""

        def read_output():
            while True:
                text = pypiserver.stdout.read(1024)
                if not text:
                    break
                text = text.decode("utf-8")
                print(text)
                output += text

        reader_thread = threading.Thread(target=read_output)
        reader_thread.start()

        def stop_pypiserver():
            print("Stopping pypiserver")
            pypiserver.terminate()
            pypiserver.wait()
            print("Waiting for reader thread to shut down.")
            reader_thread.join()

        while True:
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
    scratch_dir = make_scratch_dir()
    port = start_pypiserver(scratch_dir)
    fix_up_intermediate_files(scratch_dir, port)

    subprocess.check_call([BIT_BAZEL_BINARY, "test", "//..."], cwd=scratch_dir)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
