#!/usr/bin/env python3
import argparse
from pathlib import Path

import tftest


def cleanup(cluster_name):
    terraform_dir = Path("../terraform")
    cluster_vars = [
        path
        for path in terraform_dir.rglob(f"{cluster_name}-*.tfvars")
        if path.is_symlink()
    ]
    for path in cluster_vars:
        moduledir, tfvars = path.parent, path.name
        print(f"destroy {moduledir/tfvars}")
        tf = tftest.TerraformTest(moduledir)
        print(tf.setup(output=True))
        print(tf.destroy(tf_var_file=tfvars, output=True))
        path.unlink()


parser = argparse.ArgumentParser(description="Cleanup any tftest clusters left around")
parser.add_argument("cluster_name", help="name of the cluster to clean up")

if __name__ == "__main__":
    args = parser.parse_args()
    cleanup(args.cluster_name)
