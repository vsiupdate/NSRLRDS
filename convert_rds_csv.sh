#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name:       convert_rds_csv.sh
# Description:       Converts the RDS database to CSV for use with OSForensics
# Version:           1.0
# Created Date:      September 27, 2023
# Last Modified:     September 27, 2023
# -----------------------------------------------------------------------------

# Header Section
echo ""
echo ""
echo "==========================================================="
echo "Convert RDS Curated Database to CSV Files"
echo "==========================================================="
echo "Script Actions:"
echo "- Automatically identifies the most recent curated.db file."
echo "- Initializes SQLite with performance tuning PRAGMAs."
echo "- Exports various tables to CSV files."
echo "==========================================================="
echo ""
echo ""
echo "Starting script..."


# Identify the most recent curated.db file
db_filename=$(ls -t RDS_*_curated.db | head -n 1)
echo "Identified most recent curated.db file as $db_filename."

# Check if the file exists
if [ ! -f "$db_filename" ]; then
  echo "File not found!"
  exit 1
fi
echo "-----------------------------------------------------------"
# Initialize SQLite with performance tuning PRAGMAs
echo "Initializing SQLite with performance tuning PRAGMAs..."
sqlite3 $db_filename <<PRAGMAS
PRAGMA journal_mode = WAL;
PRAGMA synchronous = normal;
PRAGMA temp_store = memory;
PRAGMA mmap_size = 4000000000;
PRAGMAS
echo "SQLite initialized."
echo "-----------------------------------------------------------"
echo "Exporting data to NSRLFile.txt..."
sqlite3 $db_filename <<NSRLFILE
BEGIN TRANSACTION;
DROP TABLE IF EXISTS temp_export;
CREATE TEMP TABLE temp_export AS SELECT sha1, md5, crc32, file_name, file_size, package_id FROM FILE;
UPDATE temp_export SET file_name = REPLACE(file_name, '\"', '');
COMMIT;
.output NSRLFile.txt
.mode csv
SELECT sha1, md5, crc32, file_name, file_size, package_id, 0, '' FROM temp_export ORDER BY sha1;
NSRLFILE
echo "Done."
echo "-----------------------------------------------------------"
echo "Exporting data to NSRLMfg.txt..."
sqlite3 $db_filename <<NSRLMFG
BEGIN TRANSACTION;
DROP TABLE IF EXISTS temp_export;
CREATE TEMP TABLE temp_export AS SELECT manufacturer_id, name FROM MFG;
UPDATE temp_export SET name = REPLACE(name, '\"', '');
COMMIT;
.output NSRLMfg.txt
.mode csv
SELECT manufacturer_id, name FROM temp_export ORDER BY manufacturer_id;
NSRLMFG
echo "Done."
echo "-----------------------------------------------------------"
echo "Exporting data to NSRLOS.txt..."
sqlite3 $db_filename <<NSRLOS
BEGIN TRANSACTION;
DROP TABLE IF EXISTS temp_export;
CREATE TEMP TABLE temp_export AS SELECT operating_system_id, name, version, manufacturer_id FROM OS;
UPDATE temp_export SET name = REPLACE(name, '\"', ''), version = REPLACE(version, '\"', '');
COMMIT;
.output NSRLOS.txt
.mode csv
SELECT operating_system_id, name, version, manufacturer_id FROM temp_export ORDER BY operating_system_id;
NSRLOS
echo "Done."
echo "-----------------------------------------------------------"
echo "Exporting data to NSRLProd.txt..."
sqlite3 $db_filename <<NSRLPROD
BEGIN TRANSACTION;
DROP TABLE IF EXISTS temp_export;
CREATE TEMP TABLE temp_export AS SELECT package_id, name, version, operating_system_id, manufacturer_id, language, application_type FROM PKG;
UPDATE temp_export SET name = REPLACE(name, '\"', ''), version = REPLACE(version, '\"', '');
COMMIT;
.output NSRLProd.txt
.mode csv
SELECT package_id, name, version, operating_system_id, manufacturer_id, language, application_type FROM temp_export ORDER BY package_id;
NSRLPROD
echo "Done."
echo "-----------------------------------------------------------"