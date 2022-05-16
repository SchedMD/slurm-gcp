# slurm.conf
# https://slurm.schedmd.com/slurm.conf.html
# https://slurm.schedmd.com/configurator.html

ProctrackType=proctrack/cgroup
SlurmctldPidFile=/var/run/slurm/slurmctld.pid
SlurmdPidFile=/var/run/slurm/slurmd.pid
TaskPlugin=task/affinity,task/cgroup

#
#
# SCHEDULING
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

#
#
# LOGGING AND ACCOUNTING
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/cgroup
SlurmctldDebug=info
SlurmdDebug=info

################################################################################
#              vvvvv  WARNING: DO NOT MODIFY SECTION BELOW  vvvvv              #
################################################################################

SlurmctldHost={control_host}

AuthType=auth/munge
AuthInfo=cred_expire=120
AuthAltTypes=auth/jwt
CredType=cred/munge
MpiDefault={mpi_default}
ReturnToService=2
SlurmctldPort=6820-6830
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
StateSaveLocation={state_save}

#
#
# TIMERS
MessageTimeout=60

#
#
# LOGGING AND ACCOUNTING
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost={control_host}
ClusterName={name}
SlurmctldLogFile={slurmlog}/slurmctld.log
SlurmdLogFile={slurmlog}/slurmd-%n.log

#
#
# GENERATED CLOUD CONFIGURATIONS
include cloud.conf

################################################################################
#              ^^^^^  WARNING: DO NOT MODIFY SECTION ABOVE  ^^^^^              #
################################################################################
