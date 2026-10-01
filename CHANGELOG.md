# Changelog

Release notes of the Metadata Driven DW Automation framework, newest first.

Until 2026-09-30 the framework lived in the [sisula](https://github.com/Roenbaeck/sisula) repository, and these notes were written as its GitHub releases. That repository now holds only the Sisula template engine, so the notes are kept here, with their original publication dates. Every version is a tag in this repository; only the latest has a release page.

## [v2.0.3](https://github.com/Roenbaeck/dw-framework/releases/tag/v2.0.3) - 2026-06-12

Missing target SQL files could cause an error, which has now been fixed.

**Full Changelog**: https://github.com/Roenbaeck/dw-framework/compare/v2.0.2...v2.0.3

## [v2.0.2](https://github.com/Roenbaeck/dw-framework/releases/tag/v2.0.2) - 2026-01-16

Some minor performance improvements and a workaround for a rare bug in SQL Server.

## [v2.0.1](https://github.com/Roenbaeck/dw-framework/releases/tag/v2.0.1) - 2025-09-12

Fixed a bug in `Sisulate.ps1` where files were not generated if there wasn't already an existing file that could be overwritten. Added a script `Sign-Sisulate.ps1` with the intention of signing the script for running in environments where PowerShell scripts need signing to be allowed to execute.

## [v2.0](https://github.com/Roenbaeck/dw-framework/releases/tag/v2.0) - 2025-08-28

This is the first release of the rewrite to PowerShell + JavaScript (through Jint). The legacy versions using HTA and the older JScript are still bundled and runnable until Microsoft drops them completely from the OS. They're both deprecated technologies, and sometimes blocked by corporate policies. There could still be bugs in the new PS+JS version, even if all regression tests made so far now pass, so keep an eye on the generated code if you switch and please file any bugs under the issue tracker here on GitHub.

## [v1.16.6](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16.6) - 2024-09-27

This release adds additional support for SQL Server 2022 (with an updated Utilities.DLL). It also fixes a bug in the IsType CLR UDF where numeric/decimal target types were wrongly flagged as non-compatible if the input was a negative number. If you were using IsType you may want to upgrade. If you are already using an earlier version on 2022 and do not use IsType, there's no real need to upgrade to this version, since the older DLL-file also works there.

## [v1.16.5](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16.5) - 2024-05-16

This release focuses on performance improvements in the stored procedures that read and write metadata. Slowdowns were seen when you had millions of rows in your Work table, particularly if you are using microbatches, where the time taken for metadata management was no longer insignificant relative the whole running time. 

We now also force UTF-8 (without BOM) for generated SQL and XML files. For some reason the Sisulate script could produce files with different formats on different systems, which should now be avoided. UTF-8 is also a safe bet when it comes to versioning systems.

## [v1.16.4](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16.4) - 2023-06-01

This is a minor release fixing a bug where the Deletable column is not set in the UPDATE part of a MERGE statement even though a mapping target is marked with `deletable="true"`.

## [v1.16.3](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16.3) - 2023-03-30

This is a minor release that fixes a bug causing the Utilities assembly to alternatingly be installed and uninstalled when you had several source XML files.

## [v1.16.2](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16.2) - 2023-02-17

This release contains some minor bug fixes since v1.16. There is also a new feature in the MultiSplitter utility function. It will now also return the name of the capturing group. In the following example: 
```
select *
from GolfStage.dbo.MultiSplitter(
	'Hello stuff NN111, NN112 and the thing X001 in the cloud.', 
	'(?<stuff>[A-Z]{2}[0-9]{3})|(?<thing>[A-Z][0-9]{3})'
);
```
the output is now extended with an additional column named `group`:
|match	|index	|group|
|---|---|---|
|NN111	|12	|stuff|
|NN112	|19	|stuff|
|X001	|39	|thing|

## [v1.16](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.16) - 2021-01-22

Loads in the target definition can now be marked as type="insert" (defaults to "merge"), which will generate an INSERT statement instead of a MERGE. This improves performance when you are certain that whatever it is you are adding is entirely new, since the insert avoids the key lookup required by the merge. One way of ensuring this is to prepare your target model in the <sql position="before"> section, by doing desired updates and deletes there when the merge performance is not as good as required (yes, this happens).

## [v1.15.3](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.15.3) - 2021-01-21

A cut and paste bug had left a reference to the non-existing table #JB_ID in the _JobStopping SP. This minor release fixes that bug. If you are affected by this issue, rerun the script metadata/06_CreateLoggingProcedures.sql to upgrade the stored procedure in the database containing your metadata.

## [v1.15.2](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.15.2) - 2020-09-24

This release includes a fix that makes as="static" work as intended, such that changed values are ignored and unavailable values are added (but only once). In v1.15.1 changed values were added if one attribute was missing a value (null in the latest view) and a row with an existing natural key was present in the MERGE.

## [v1.15.1](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.15.1) - 2020-09-18

Attributes can now be marked as="static", which disables the check exemplified by (source.Value <> target.AN_ATT_Attribute_Value) to trigger an UPDATE in the MERGE. This can be convenient if you want to silently disregard any future changes of an attribute value. Marking an attribute as="static" should therefore be done only after carefully considering that this is the desired behavior.

We noticed some performance issues from logging overhead when running lots of jobs that complete in a very short time. Job_Stopping could take seconds to run when other Agent jobs were running, because a cross apply was evaluated even if the entire query would return 0 rows. This is now fixed and Job_Stopping should be a sub-second operation. Furthermore, all models have also been updated to remove the warning about updating a static attribute. These messages would otherwise litter the Agent logs, which could make the agent linger on a job step longer than necessary. Run scripts to create the metadata model or stats model over an existing v1.15 installation to upgrade them. Note that if you have v1.14 or older you also need to run the other upgrade scripts.

## [v1.15](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.15) - 2020-09-11

This release adds a new model and procedure to gather statistics over time, which can be used to track which database objects are growing the fastest in terms of rows and size. Installing the stats functionality can be done from the new stats folder. It is disjoint from the other features and can be used stand-alone if desired. In order to gather the statistics, the proc _GatherStatistics should be run at a regular interval.

We have also fixed a bug where Work could remain in "Running" state, even if a Job fails. This happened with statement-level errors that could only be determined at run time, such as necessary table having been removed since a procedure was compiled. 

Performance has been improved when it comes to metadata, but the model has to be upgraded in existing installations, since some constructs have now been knotted. Also, "last seen" is now restricted to files and is no longer logged for tables. There is also a new utility function _DeleteMetadata which can be used to delete rows from Job, Work, and Operations that belong to jobs older than a given date.

## [v1.14](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.14) - 2020-03-20

Added full support of SQL Server 2019. This includes the new necessary "whitelisting" of CLR assemblies. Also fixes a bug (introduced in 1.13.1) when you had several jobs defined in a single workflow. In this release the Golf example has been added, which can be seen in the new video tutorials: https://www.youtube.com/playlist?list=PLG6-3kKEOyYlWEaEFzhcARtjqHU6zn1cH.

## [v1.13.1](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.13.1) - 2019-12-06

This contains a few convenience fixes compared to 1.13. Nothing critical, but if you have had issues with any of them you may want to upgrade. Here is what has been done:
* Changed CreateJobs so that it never recreates an existing job. It will be left as is upon install, but its job steps recreated.
* Added a fix for a very rare case when logging of the number of inserts was done in such a quick succession that the same ChangedAt appeared twice.
* Corrected the printed version number from Sisulate.bat (from 1.13.3, which should have been 1.13, to 1.13.1, which is the correct one now).

## [v1.13](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.13) - 2019-11-07

This release changes the Sisulator, which previously ran in the Windows Scripting Host, to now run as an HTA (HTML Application). The reason for this change is due to a size limitation, which caused large XML files with metadata to cause an 'Out of Memory' error. In this release stored metadata from the framework will use UTC timing, instead of the previous local timing. As it turns out, jobs that run during the time when the clock is set back to winter time from summer time, may leave the metadata in an inconsistent state. In order to upgrade, run files 02 and 04 from the metadata folder. If you want to use this version, but remain on local time, do not run files 02 and 04, and instead add `set Timestamp=SYSDATETIME()` in Variables.bat. This now defaults to `SYSUTCDATETIME()`. Other fixes include correct installation of the Utilities assembly for SQL Server versions > 2016 and support for the FIELDQUOTE directive in bulk inserts. Added /filters option to Sisulate.bat controlling which code to install on the given server.

## [v1.12](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.12) - 2019-02-08

This release adds DLL files for SQL Server 2008 - 2019, when installing the Utilities assembly. The very same assembly has been extended with a variation of the Splitter function, named MultiSplitter. It returns every match of a pattern found in the row, rather than the first match per capture group. We needed this in order to precalculate some regex searches, where said regexes could match many times in a free text field, but with different results. Enjoy!

## [v1.11](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.11) - 2017-12-08

This release adds preliminary support for BIML-generated SSIS packages that load attributes in *parallel*. These drastically improve performance compared to inserting/merging into the latest views, which uses trigger logic to  *serially* load attributes. In the current release only anchors and their attributes can be loaded through BIML-generated SSIS-packages. There is unfortunately very little documentation of the BIML generation. Loading of ties and better documentation will follow in a later release. In the meantime, feel free to ask us questions about BIML in our forums.

## [v1.10](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.10) - 2017-03-09

This release contains a few bug fixes for the Splitter method. It also fixes an issue where a specified on_fail_action in a workflow was overwritten in the resulting agent job.

## [v1.09](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.09) - 2016-04-26

Primarily fixes a number of bugs, but also adds new features. When jobs are recreated by the installation process, any schedules on the job will now remain. A simple application that displays a loading report has been added. A function that converts UTC to local time has been added to the .NET CLR assembly. A new and improved splitter (with respect to performance) has also been added. This release is fully backwards compatible and can be dropped in as a replacement for version 1.08.

## [v1.08](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.08) - 2015-09-15

Fixes a few annoyances, such as directories being changed when calling the bat-files. Added some preliminary support for SQL Server 2005. There is a video tutorial available on how to use the framework here: https://www.youtube.com/playlist?list=PLG6-3kKEOyYlWEaEFzhcARtjqHU6zn1cH

## [v1.07](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.07) - 2015-08-15

This release fixes a couple of bugs that prevented the Example from running properly on all versions of Windows. It also adds support for quoted terminators, which can be specified through `delimiter="&quot;,&quot;"` for example.

## [v1.06](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.06) - 2015-05-25

This release separates the framework from the projects on which it operates, making it much easier to upgrade existing framework installations. Key and type checking can now be optionally controlled from the source XML description. BULK splitting has been improved and support for FIRSTROW has been added (in order to skip headers). A number of bug fixes have been included. Among them the important one which fixes the problem of upper case data types not being checked at all.

## [v1.05](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.05) - 2015-02-10

This release fixes the example files (vehicle collisions in Manhattan). GitHub were treating them as source code files and thereby felt at liberty to modify them, unfortunately making them unreadable. They are now marked as binary, which means GitHub is no longer able to touch them when they are checked in or out.

## [v1.04](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.04) - 2014-10-28

The TRY_CAST has been replaced by a CLR function that correctly detects truncation of types. It also removes the dependency on being on SQL Server 2012 or later. The framework should now work just as well in 2005/2008. 
Some other features have also been added, such as pre- and post processing in the target stored procedures, specified rowlength instead of varchar(max) in the Raw table, and a rewritten Splitter in C# that has slightly better performance than the old one.

## [v1.03](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.03) - 2014-10-20

Fixed yet another missing metadatabase reference that prevented the metadatabase to be different from the staging database.

## [v1.02](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.02) - 2014-10-20

This release fixes two bugs. Spaces can now be used in the filename directory path and BULK INSERT will no longer time out after 30 seconds when loading large files.

## [v1.01](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.01) - 2014-10-20

This release fixes the bug which prevented the metadatabase to be different from the stage database.

## [v1.0](https://github.com/Roenbaeck/dw-framework/releases/tag/v1.0) - 2014-10-16

This is the first release of the medatadata driven data warehouse automation framework based on sisula and geared towards Anchor Modeling. The framework requires JScript by Windows Scripting Host in order to generate SQL code, which is executable on SQL Server 2012 or later. Once the code has been executed the SQL Server Agent will contain a number of jobs that drive the ETL flow through stored procedures generated from the metadata. Logging is made to an included metadata model which also ties in to the sys tables used by the SQL Server Agent.
