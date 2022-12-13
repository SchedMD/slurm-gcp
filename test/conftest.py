from pathlib import Path

import pytest

from deploy import Cluster, Configuration

root = Path(__file__).parent.parent
tf_path = root / "terraform"
test_path = root / "test"


def pytest_addoption(parser):
    parser.addoption(
        "--project-id", action="store", help="GCP project to deploy the cluster to"
    )
    parser.addoption("--cluster-name", action="store", help="cluster name to deploy")
    parser.addoption(
        "--image", action="store", nargs="?", help="image name to use for test cluster"
    )
    parser.addoption(
        "--image-family",
        action="store",
        nargs="?",
        help="image family to use for test cluster",
    )
    parser.addoption(
        "--image-project", action="store", help="image project to use for test cluster"
    )


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    # execute all other hooks to obtain the report object
    outcome = yield
    rep = outcome.get_result()

    # set a report attribute for each phase of a call, which can
    # be "setup", "call", "teardown"

    setattr(item, "rep_" + rep.when, rep)


CONFIGS = {
    pytest.param("basic"): dict(
        moduledir=tf_path / "slurm_cluster/examples/slurm_cluster/cloud/basic",
        tfvars_file=test_path / "basic.tfvars.tpl",
        tfvars={},
    ),
}


@pytest.fixture(params=CONFIGS.keys(), scope="session")
def configuration(request):
    config = Configuration(
        project_id=request.config.getoption("project_id"),
        cluster_name=request.config.getoption("cluster_name"),
        image_project=request.config.getoption("image_project"),
        image_family=request.config.getoption("image_family"),
        image=request.config.getoption("image"),
        **CONFIGS[pytest.param(request.param)],
    )
    config.tf.setup(extra_files=[config.tfvars_file], cleanup_on_exit=False)
    return config


@pytest.fixture(scope="session")
def plan(configuration):
    return configuration.tf.plan(
        tf_vars=configuration.tfvars,
        tf_var_file=configuration.tfvars_file.name,
        output=True,
    )


@pytest.fixture(scope="session")
def applied(configuration):
    configuration.tf.apply(
        tf_vars=configuration.tfvars, tf_var_file=configuration.tfvars_file.name
    )
    yield configuration.tf
    # configuration.tf.destroy()


@pytest.fixture(scope="session")
def cluster(applied):
    cluster = Cluster(applied)
    yield cluster
    cluster.disconnect()
