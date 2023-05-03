import logging

instance_information_fields = ["resourceStatus", "id"]


def register_instance_information_fields(*pos_args, **keyword_args):
    logging.debug("register_instance_information_fields called from test_plugin")
    keyword_args["instance_information_fields"].extend(instance_information_fields)


def post_prolog_resume_nodes(*pos_args, **keyword_args):
    logging.debug("post_prolog_resume_nodes called from test_plugin")
    for node in keyword_args["nodelist"]:
        logging.info(
            (
                "test_plugin:"
                + f"job_id:{keyword_args['job_id']} "
                + f"nodename:{node} "
                + f"instance_id:{keyword_args['lkp'].instance(node)['id']} "
                + f"physicalHost:{keyword_args['lkp'].instance(node)['resourceStatus']['physicalHost']}"
            )
        )


__all__ = [
    "register_instance_information_fields",
    "post_prolog_resume_nodes",
]
