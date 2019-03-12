# Relativity-Maintance-script

In an effort to help other developers keep their dev vms clean I have created a script that uses sql agents to clean up the following:

- Truncate EDDSlogging table
- remove errors from the errors tab that are 30+ days old
- Clean up the service bus logs from sql
- Cleans us the EDDS* log files to clean up disk space.


# This is only meant to run in developer instances, use at your own risk!!!
