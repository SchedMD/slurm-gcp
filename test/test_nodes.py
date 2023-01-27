import logging
import hostlist

from itertools import chain

from deploy import Cluster
from testutils import wait_until, util

log = logging.getLogger()


def test_static(cluster: Cluster, lkp: util.Lookup):

    power_states = set(
        (
            "POWERING_DOWN",
            "POWERED_DOWN",
            "POWERING_UP",
        )
    )

    def is_node_up(node):
        info = cluster.get_node(node)
        state = info["state"]
        flags = set(info["state_flags"])
        log.info(
            f"waiting for static node {node} to be up; state={state} flags={','.join(flags)}"
        )
        return state == "idle" and not (power_states & flags)

    for node in chain.from_iterable(
        hostlist.expand_hostlist(nodes) for nodes in lkp.static_nodelist()
    ):
        assert wait_until(is_node_up, node)
