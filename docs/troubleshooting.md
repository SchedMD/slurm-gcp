# Troubleshooting Guide

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Troubleshooting Guide](#troubleshooting-guide)
  - [Customer support](#customer-support)
  - [The cluster is not behaving correctly](#the-cluster-is-not-behaving-correctly)
  - [Instance startup-script failed](#instance-startup-script-failed)
  - [Quota limits](#quota-limits)

<!-- mdformat-toc end -->

## Customer support

For [Google Cloud](./glossary.md#gcp) issues, please direct support requests to
[Google Cloud Support](https://cloud.google.com/support-hub).

For [Slurm](./glossary.md#slurm) and `slurm-gcp` issues, please direct support
requests to [SchedMD Support](https://bugs.schedmd.com).

## The cluster is not behaving correctly

There are numerous things that could cause strange or undesired behavior. They
could originate from [Google Cloud](./glossary.md#gcp) or from the Slurm scripts
provided by `slurm-gcp`. You should always check logs to locate errors and
warning being reported by the cluster instances and Google Cloud.
[Google Cloud Logging](https://cloud.google.com/logging) makes it easy to
monitor project activity, including all Slurm logs from each instance, by
collating all logging within the project into one place.

Optionally, you can directly check messages/syslog, Slurm logs, and Slurm script
logs on each instance.

- syslog ( *HINT*: `grep "startup-script" $LOG`)
  - `/var/log/messages`
  - `/var/log/syslog`
- Slurm
  - `/var/log/slurm/slurmctld.log`
  - `/var/log/slurm/slurmdbd.log`
  - `/var/log/slurm/slurmrestd.log`
  - `/var/log/slurm/slurmd-%n.log`
- Slurm scripts
  - `/var/log/slurm/resume.log`
  - `/var/log/slurm/suspend.log`
  - `/var/log/slurm/slurmeventd.log`

Additionally, increasing Slurm log verbosity level and or adding DebugFlags may
be useful for tracing any errors or warnings.

```sh
$ scontrol setdebug debug2
$ scontrol setdebugflags +power
```

## Instance startup-script failed

Upon startup-script failure, all users should be notified via `wall` and `motd`.
Check `/slurm/scripts/setup.log` for details about the failure.

## Quota limits

[Google Cloud](./glossary.md#gcp) has [quota limits](./glossary.md#gcp-quota).
Instances can fail to be deployed because they would exceed your CPU limits.
Additionally, instance deployments can be throttled because of quota limits
placed on API requests. If you are experiencing these quota limits with your
cluster, consider requesting a limit increase to better meet your cluster
demands.
