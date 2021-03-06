script "SQL Yoga Development Tools"
/**
Summary: Reloads all of the SQL Yoga configuration files.

Description:
This handler is useful for reloading configuration files after
you modify them.
*/
command sqlyogadev_reloadConfigFiles
  levureReloadRegisteredKey "sql yoga>configuration"
  return empty
end sqlyogadev_reloadConfigFiles


/**
Summary: Turns on logging using the Levure logging helper.

Description:
All log entries generated by SQL Yoga will be prefixed with "sqlYoga:"
*/
command sqlyogadev_enableLogging pBoolean, pConnectionName, pDBKey
  if pBoolean then
    dbconn_set "log callback", "sqlyogadev_loggingCallback", pConnectionName, pDBKey
  else
    dbconn_set "log callback", "", pConnectionName, pDBKey
  end if

  return empty
end sqlyogadev_enableLogging


command sqlyogadev_loggingCallback pSQL, pConnectionName, pDBKey
  loggerLogMsg "sqlYoga:" && pSQL
end sqlyogadev_loggingCallback


/**
Summary: Saves the current schema for a database to a YAML file.

Description:
SQL Yoga will load the schema.yml file if present and use that to define
the table objects for the database. If the schema.yml file is not present
then the first time a connection is made to the database the tables and
columns will be extracted from the database.

A schema.yml can be used to create a new database. Just create a connection
to an empty database and call `dbsynch_databaseWithSchema`.
*/
command sqlyogadev_saveSchemaToYAML pDBKey
  local tError

  _saveSchemaToYAML pDBKey
  put the result into tError

  return tError for error
end sqlyogadev_saveSchemaToYAML


command sqlyogadev_createSchemaMigration pName, pDBKey
  local tError, tMigrateFolder, tStamp

  put _migrateFolder(pDBKey) into tMigrateFolder
  put _GetGMTTimeStampForMigrationId() into tStamp

  put textEncode("migration:" & cr & "  ", "utf8") \
        into URL ("binfile:" & tMigrateFolder & "/" & tStamp & "_" & pName & ".yml")
  put the result into tError

  return tError for error
end sqlyogadev_createSchemaMigration


/**
Summary: Runs all migrations in the *migrate* folder that have not been applied to the current connection.

Description:
This handler will loop through all files in the *migrate* folder. The schema version
for the migration will be determined by the numbers at the front of the filename.
Each number is compared against the current `schema` table `version` column value.
If the version of the migration is greater than the version of the column value then
the migration is applied to the database.

After running the last migration the version of the migration is stored in the
`schema` table `version` column.
*/
command sqlyogadev_runMigrations pConnectionName, pDBKey
  local tError, tConfigA, i, tMigrateFolder

  put _migrateFolder(pDBKey) into tMigrateFolder

  if there is a folder tMigrateFolder then
    _runMigrations tMigrateFolder, pConnectionName, pDBKey
    put the result into tError
  else
    put "migrate folder not found:" && tMigrateFolder into tError
  end if

  if tError is empty then
    _saveSchemaToYAML pDBKey
    put the result into tError
  end if

  return tError
end sqlyogadev_runMigrations


command _runMigrations pMigrationFolder, pConnectionName, pDBKey
  local tError, tFiles, tFile, tMigrateA
  local tMigrationVersion

  put files(pMigrationFolder) into tFiles
  filter tFiles without ".*"
  filter tFiles with regex pattern "(.*\.yml$)|(.*\.livecodescript$)"

  sort lines of tFiles numeric by each

  repeat for each line tFile in tFiles
    put _extractMigrationVersionFromFilename(tFile) into tMigrationVersion

    if tFile ends with ".yml" or tFile ends with ".yaml" then
      put yamlFileToArray(pMigrationFolder & "/" & tFile) into tMigrateA
      put the result into tError

      if tError is empty then
        dbschema_processMigrationArray tMigrationVersion, tMigrateA, pConnectionName, pDBKey
      end if
    else if tFile ends with ".livecodescript" or tFile ends with ".livecode" then
        dbschema_processMigrationFile tMigrationVersion, pMigrationFolder & "/" & tFile, pConnectionName, pDBKey
    end if

    if tError is not empty then exit repeat
  end repeat

  return tError
end _runMigrations


private function _extractMigrationVersionFromFilename pFilename
  local tChar, tVersion

  repeat for each char tChar in pFilename
    if tChar is a number then
      put tChar after tVersion
    end if
  end repeat

  return tVersion
end _extractMigrationVersionFromFilename


private command _saveSchemaToYAML pDBKey
  local tError, tDBFolder, tYAML

  put _databaseFolder() into tDBFolder

  if there is a folder tDBFolder then
    put dbschema_get("yaml", pDBKey) into tYAML
    put textEncode(tYAML, "utf8") into URL("binfile:" & tDBFolder & "/schema.yml")
    put the result into tError
  end if

  return tError
end _saveSchemaToYAML


private function _databaseFolder pDBKey
  local tConfigA, i

  put levureAppGet("sql yoga") into tConfigA

  repeat with i = 1 to the number of elements of tConfigA["configuration"]
    if tConfigA["configuration"][i]["database key"] is pDBKey \
          or (pDBKey is empty and tConfigA["configuration"][i]["database key"] is "default") then
      return tConfigA["configuration"][i]["filename"]
    end if
  end repeat

  return empty
end _databaseFolder


private function _migrateFolder pDBKey
  local tDBFolder

  put _databaseFolder(pDBKey) into tDBFolder
  if tDBFolder is not empty then
    return tDBFolder & "/migrate"
  else
    return empty
  end if
end _migrateFolder


private function _GetGMTTimeStampForMigrationId
  local tInternetTime, tGMTOffset

  put the internet date into tInternetTime
  put _InternetTimeStampGMTOffset(tInternetTime) into tGMTOffset

  convert tInternetTime from internet date to dateItems
  if tGMTOffset is a number then
    subtract tGMTOffset from item 4 of tInternetTime
  end if
  convert tInternetTime to dateItems
  replace comma with empty in tInternetTime
  return tInternetTime
end _GetGMTTimeStampForMigrationId


private function _InternetTimeStampGMTOffset pInternetTime
  local tGMTOffset

  put the last word of pInternetTime into tGMTOffset
  delete the char -2 to -1 of tGMTOffset
  if char 2 of tGMTOffset is 0 then delete char 2 of tGMTOffset
  if char 1 of tGMTOffset is "+" then delete char 1 of tGMTOffset
  return tGMTOffset
end _InternetTimeStampGMTOffset
