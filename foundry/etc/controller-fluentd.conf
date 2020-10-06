# This filter goes with all of the slurm sources. It maps slurm log levels
# to logging api severity levels and prepends the tag to the log message.
<filter slurmctld slurmdbd slurmd>
  @type record_transformer
  enable_ruby true
  <record>
    severity ${ {'debug'=>'DEBUG', 'debug2'=>'DEBUG', 'debug3'=>'DEBUG', 'debug4'=>'DEBUG', 'debug5'=>'DEBUG', 'error'=>'ERROR', 'fatal'=>'CRITICAL'}.tap{|map| map.default='INFO'}[record['severity']] }
    message ${tag + " " + record['message']}
  </record>
</filter>

<source>
  @type tail
  tag slurmctld
  path /var/log/slurm/slurmctld.log
  pos_file /var/lib/google-fluentd/pos/slurm_slurmctld.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^\[(?<time>[^\]]*)\] (?<message>(?<severity>\w*).*)$/
    time_format %Y-%m-%dT%H:%M:%S.%N
  </parse>
</source>

<source>
  @type tail
  tag slurmdbd
  path /var/log/slurm/slurmdbd.log
  pos_file /var/lib/google-fluentd/pos/slurm_slurmdbd.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^\[(?<time>[^\]]*)\] (?<message>(?<severity>\w*).*)$/
    time_format %Y-%m-%dT%H:%M:%S.%N
  </parse>
</source>

<source>
  @type tail
  tag resume
  path /var/log/slurm/resume.log
  pos_file /var/lib/google-fluentd/pos/slurm_resume.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^(?<time>\S+ \S+) (?<message>\S+ (?<severity>\S+):.*)$/
    time_format %Y-%m-%d %H:%M:%S,%N
  </parse>
</source>

<source>
  @type tail
  tag suspend
  path /var/log/slurm/suspend.log
  pos_file /var/lib/google-fluentd/pos/slurm_suspend.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^(?<time>\S+ \S+) (?<message>\S+ (?<severity>\S+):.*)$/
    time_format %Y-%m-%d %H:%M:%S,%N
  </parse>
</source>

<source>
  @type tail
  tag slurmsync
  path /var/log/slurm/slurmsync.log
  pos_file /var/lib/google-fluentd/pos/slurm_slurmsync.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^(?<time>\S+ \S+) (?<message>\S+ (?<severity>\S+):.*)$/
    time_format %Y-%m-%d %H:%M:%S,%N
  </parse>
</source>
