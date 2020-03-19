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
  tag slurmd
  path /var/log/slurm/slurmd*.log
  pos_file /var/lib/google-fluentd/pos/slurm_slurmd.log.pos
  read_from_head true
  <parse>
    @type regexp
    expression /^\[(?<time>[^\]]*)\] (?<message>(?<severity>\w*).*)$/
    time_format %Y-%m-%dT%H:%M:%S.%N
  </parse>
</source>
