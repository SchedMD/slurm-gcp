import tensorflow as tf
import os


@tf.function
def add_fn(x, y):
    z = x + y
    return z


print(f"TF_VERSION = {tf.__version__}")

cluster_resolver = tf.distribute.cluster_resolver.TPUClusterResolver()

TPU_LOAD_LIBRARY = os.getenv("TPU_LOAD_LIBRARY")
if (TPU_LOAD_LIBRARY is not None) and (TPU_LOAD_LIBRARY == "0"):
    print(f"WORKER_ID = {cluster_resolver.cluster_spec().as_dict()['worker']}")

tf.config.experimental_connect_to_cluster(cluster_resolver)
tf.tpu.experimental.initialize_tpu_system(cluster_resolver)
strategy = tf.distribute.TPUStrategy(cluster_resolver)

x = tf.constant(1.0)
y = tf.constant(1.0)
z = strategy.run(add_fn, args=(x, y))

working_TPUs = 0
for val in z.values:
    if val == 2.0:
        working_TPUs += 1

print(f"GOOD_TPUS = {working_TPUs}")
