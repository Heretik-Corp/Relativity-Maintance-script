USE [msdb]
GO

/****** Object:  Job [heretik_maint]    Script Date: 3/12/2019 11:16:59 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 3/12/2019 11:16:59 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'heretik_maint', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Truncate Relativity Logs]    Script Date: 3/12/2019 11:16:59 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Truncate Relativity Logs', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=2, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'truncate table [EDDSLogging].[eddsdbo].[RelativityLogs]', 
		@database_name=N'EDDSLogging', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Truncate Service bus logs]    Script Date: 3/12/2019 11:16:59 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Truncate Service bus logs', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @name VARCHAR(500) -- database name  

DECLARE db_cursor CURSOR FOR  
select inn.database_name from (
SELECT 
      database_name = DB_NAME(database_id)
    , log_size_mb = CAST(SUM(CASE WHEN type_desc = ''LOG'' THEN size END) * 8. / 1024 AS DECIMAL(8,2))
    , row_size_mb = CAST(SUM(CASE WHEN type_desc = ''ROWS'' THEN size END) * 8. / 1024 AS DECIMAL(8,2))
    , total_size_mb = CAST(SUM(size) * 8. / 1024 AS DECIMAL(8,2))
FROM sys.master_files WITH(NOWAIT)
--WHERE database_id = DB_ID() -- for current db 
GROUP BY database_id
)inn where inn.log_size_mb > 1024 AND database_name like ''sb%''

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   

declare @sql varchar(max)
WHILE @@FETCH_STATUS = 0   
BEGIN   
	set @sql = ''USE '' + @name + '';ALTER DATABASE '' + @name + '' SET RECOVERY SIMPLE;''
	EXECUTE(@sql)
	set @sql = ''USE '' + @name + '';DBCC SHRINKFILE ('' + @name + ''_Log, 1024);''
	EXECUTE(@sql)
	set @sql = ''USE '' + @name + '';ALTER DATABASE '' + @name + '' SET RECOVERY FULL;''
	EXECUTE(@sql)
    FETCH NEXT FROM db_cursor INTO @name   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Clear out old errors in error tab]    Script Date: 3/12/2019 11:16:59 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Clear out old errors in error tab', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
declare @errorsToDelete table
(
  ArtifactId int Primary Key
)

insert into @errorsToDelete (ArtifactId)
select a.ArtifactID from eddsdbo.Error e 
join eddsdbo.Artifact a on e.ArtifactID = a.ArtifactID
where CreatedOn < DATEADD(day, -30, GETDATE()) and a.ArtifactID > 1000000

delete e
from eddsdbo.Error e
join @errorsToDelete etd on etd.ArtifactId = e.ArtifactID

delete a 
from eddsdbo.ArtifactAncestry a
join @errorsToDelete etd on a.ArtifactID = etd.ArtifactId


delete a 
from eddsdbo.Artifact a
join @errorsToDelete etd on a.ArtifactID = etd.ArtifactId

', 
		@database_name=N'EDDS', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Truncate SQL Logs]    Script Date: 3/12/2019 11:16:59 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Truncate SQL Logs', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @name VARCHAR(500) -- database name  

DECLARE db_cursor CURSOR FOR  
select inn.database_name from (
SELECT 
      database_name = DB_NAME(database_id)
    , log_size_mb = CAST(SUM(CASE WHEN type_desc = ''LOG'' THEN size END) * 8. / 1024 AS DECIMAL(8,2))
    , row_size_mb = CAST(SUM(CASE WHEN type_desc = ''ROWS'' THEN size END) * 8. / 1024 AS DECIMAL(8,2))
    , total_size_mb = CAST(SUM(size) * 8. / 1024 AS DECIMAL(8,2))
FROM sys.master_files WITH(NOWAIT)
--WHERE database_id = DB_ID() -- for current db 
GROUP BY database_id
)inn where inn.log_size_mb > 1024 AND database_name like ''edds%''

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   

declare @sql varchar(max)
WHILE @@FETCH_STATUS = 0   
BEGIN   
	set @sql = ''USE '' + @name + '';ALTER DATABASE '' + @name + '' SET RECOVERY SIMPLE;''
	EXECUTE(@sql)
	set @sql = ''USE '' + @name + '';DBCC SHRINKFILE ('' + @name + ''_Log, 1024);''
	EXECUTE(@sql)
	set @sql = ''USE '' + @name + '';ALTER DATABASE '' + @name + '' SET RECOVERY FULL;''
	EXECUTE(@sql)
    FETCH NEXT FROM db_cursor INTO @name   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'First Day of the week', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=2, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20180530, 
		@active_end_date=99991231, 
		@active_start_time=120000, 
		@active_end_time=235959, 
		@schedule_uid=N'ee179528-e5b1-49db-a386-457a5e9a74e6'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


