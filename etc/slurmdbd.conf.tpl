#ArchiveEvents=yes
#ArchiveJobs=yes
#ArchiveResvs=yes
#ArchiveSteps=no
#ArchiveSuspend=no
#ArchiveTXN=no
#ArchiveUsage=no

AuthType=auth/munge
AuthAltTypes=auth/jwt
AuthAltParameters=jwt_key={state_save}/jwt_hs256.key

DbdHost={control_host}
DebugLevel=debug

#PurgeEventAfter=1month
#PurgeJobAfter=12month
#PurgeResvAfter=1month
#PurgeStepAfter=1month
#PurgeSuspendAfter=1month
#PurgeTXNAfter=12month
#PurgeUsageAfter=24month

LogFile={slurmlog}/slurmdbd.log
PidFile=/var/run/slurm/slurmdbd.pid

SlurmUser=slurm

StorageLoc={db_name}

StorageType=accounting_storage/mysql
StorageHost={db_host}
StoragePort={db_port}
StorageUser={db_user}
StoragePass={db_pass}
#StorageUser=database_mgr
#StoragePass=shazaam
