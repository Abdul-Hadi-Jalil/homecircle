import json
from subprocess import CompletedProcess
from unittest.mock import Mock

import pytest

from tools import run_local_integration as runner


@pytest.mark.parametrize("host", ["127.0.0.1", "0.0.0.0"])
def test_local_runner_checks_actual_published_address_and_stops_exposure(monkeypatch, host):
    # Docker's requested HostIp can be empty when a bridge supplies the default.
    # NetworkSettings reports the resolved, actually published host address.
    container = {
        "HostConfig": {"PortBindings": {"5432/tcp": [{"HostIp": ""}]}},
        "NetworkSettings": {
            "Ports": {
                "5432/tcp": [
                    {"HostIp": host, "HostPort": "55422"},
                ]
            }
        },
    }
    execute = Mock(
        side_effect=[
            CompletedProcess([], 0, json.dumps([{"Containers": {"test-container": {}}}])),
            CompletedProcess([], 0, json.dumps([container])),
        ]
    )
    stop = Mock()
    monkeypatch.setattr(runner.subprocess, "run", execute)
    monkeypatch.setattr(runner, "cli", stop)
    if host == "127.0.0.1":
        runner.verify_port_bindings("docker")
        stop.assert_not_called()
    else:
        with pytest.raises(RuntimeError, match="beyond loopback"):
            runner.verify_port_bindings("docker")
        stop.assert_called_once_with(["stop"])
