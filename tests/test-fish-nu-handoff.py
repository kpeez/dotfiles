#!/usr/bin/env python3
"""Exercise the real Fish -> Nu startup boundary with isolated user config."""

import os
import fcntl
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import termios
import time


def attach_terminal() -> None:
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


def run_terminal(command: list[str], environment: dict[str, str]) -> str:
    master, slave = pty.openpty()
    # Start in the fake HOME: under the real HOME, mise reads ~/.config/mise as
    # an ancestor project config, finds it untrusted, and stops at a prompt.
    process = subprocess.Popen(
        command, stdin=slave, stdout=slave, stderr=slave, env=environment,
        cwd=environment["HOME"], preexec_fn=attach_terminal,
    )
    os.close(slave)
    output = bytearray()
    deadline = time.monotonic() + 15
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            elif process.poll() is not None:
                break
        try:
            process.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            raise AssertionError(f"Terminal timed out: {output.decode(errors='replace')}") from None
        text = output.decode(errors="replace")
        assert process.returncode == 0, text
        return text
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)


root = Path(__file__).resolve().parent.parent
fish = shutil.which("fish")
assert fish and shutil.which("nu"), "Install Fish and Nu before running this test"
temporary = Path(tempfile.mkdtemp(prefix="fish-nu-handoff-"))
print(f"test data: {temporary}")
config_home = temporary / ".config"
(config_home / "fish").mkdir(parents=True)
(config_home / "nushell").mkdir()
shutil.copy(root / "home/.config/fish/config.fish", config_home / "fish/config.fish")
# A minimal real Nu config makes the handoff observable without loading tools.
(config_home / "nushell/config.nu").write_text(
    'if ($nu.default-config-dir | path expand) != ($env.HOME | path join ".config/nushell" | path expand) {\n'
    '  error make {msg: "wrong Nu config directory"}\n'
    '}\n'
    'print NU_HANDOFF_OK\n'
    'exit 0\n'
)
environment = dict(os.environ)
environment.pop("FISH_ONLY", None)
environment.pop("XDG_CONFIG_HOME", None)
environment.update(
    HOME=str(temporary),
    XDG_DATA_HOME=str(temporary / ".local/share"),
    XDG_CACHE_HOME=str(temporary / ".cache"),
    MISE_SKIP_ACTIVATE="1",
    TERM="dumb",
)

for flags in (["--interactive"], ["--login", "--interactive"]):
    output = run_terminal([fish, *flags, "-c", "echo FISH_REMAINED"], environment)
    assert "NU_HANDOFF_OK" in output and "FISH_REMAINED" not in output, output

for flags, extra_environment in (
    ([], {}),
    (["--login"], {}),
    (["--interactive"], {"FISH_ONLY": "1"}),
    (["--no-config", "--interactive"], {}),
):
    output = run_terminal(
        [fish, *flags, "-c", "echo FISH_REMAINED"],
        environment | extra_environment,
    )
    assert "FISH_REMAINED" in output and "NU_HANDOFF_OK" not in output, output

# A shell parent means the user typed `fish`: Fish stays. `; true` stops the
# parent from exec-ing Fish, so the parent stays a shell. A copy of bash named
# atuin stands in for `atuin pty-proxy`, which restarts a Fish that stayed.
fake_atuin = temporary / "atuin"
shutil.copy(shutil.which("bash"), fake_atuin)
for parent in (["sh", "-c"], ["bash", "-c"], ["nu", "-n", "-c"], [str(fake_atuin), "-c"]):
    output = run_terminal(
        [*parent, f"{fish} --interactive -c 'echo FISH_REMAINED'; true"],
        environment,
    )
    assert "FISH_REMAINED" in output and "NU_HANDOFF_OK" not in output, (parent, output)

# Remote tools can explicitly request interactive Fish while piping stdin.
# Such command sessions must not be replaced by Nu's terminal-only REPL.
for flags in (["--interactive"], ["--login", "--interactive"]):
    result = subprocess.run(
        [fish, *flags, "-c", "echo REMOTE_COMMAND_OK"],
        stdin=subprocess.DEVNULL, capture_output=True, text=True,
        env=environment, cwd=environment["HOME"], timeout=15,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "REMOTE_COMMAND_OK" in result.stdout, result.stdout + result.stderr
    assert "NU_HANDOFF_OK" not in result.stdout, result.stdout

print("PASS: terminal handoff, XDG config, shell parents, piped remote commands, Fish escape hatches")
