#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name:       convert_rds_csv.sh
# Description:       Converts the RDS database to CSV for use with OSForensics
# Version:           1.0.4
# Created Date:      20230927
# Last Modified:     20231018
# -----------------------------------------------------------------------------

# Define spinner functions
function start_spinner {
    set +m
    echo -n "$1         "
    { while : ; do for X in '  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      ' ; do echo -en "\b\b\b\b\b\b\b\b$X" ; sleep 0.1 ; done ; done & } 2>/dev/null
    spinner_pid=$!
}
function stop_spinner {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
    set -m
    echo -en "\033[2K\r"
}

# Define trap to exit gracefully
trap stop_spinner EXIT

# Header Section
echo ""
echo "==========================================================="
echo "Convert RDS Curated Database to CSV Files"
echo "==========================================================="
echo "Script Actions:"
echo "** Automatically identifies the most recent curated.db file"
echo "** Initializes SQLite with performance tuning PRAGMAs"
echo "** Exports various tables to CSV files"
echo "==========================================================="
echo ""
echo ""
# Identify the most recent curated.db file
db_filename=$(ls -t RDS_*_curated_*_minimal.db | head -n 1)
echo "Identified most recent curated db file as $db_filename."

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
PRAGMA mmap_size = 24000000000;
PRAGMA page_size = 32768;
PRAGMA optimize;
PRAGMAS
echo "Done."
echo "-----------------------------------------------------------"
echo "Exporting data to NSRL Text Files..."
spinner_pid=
start_spinner 
# -----------------------------------------------------------------------------
# Step 1: Export data to NSRLFile.txt
sqlite3 $db_filename <<NSRLFILE
BEGIN TRANSACTION;
DROP TABLE IF EXISTS EXPORT;
CREATE TABLE EXPORT AS SELECT sha1, md5, crc32, file_name, file_size, package_id FROM FILE;
UPDATE EXPORT SET file_name = REPLACE(file_name, '"', '');
COMMIT;
.mode csv
.headers off
.output NSRLFileOutput.txt
SELECT '"' || sha1 || '"', '"' || md5 || '"', '"' || crc32 || '"', '"' || file_name || '"', file_size, package_id, '"' || 0 || '"', '"' || '"' FROM EXPORT ORDER BY sha1;
.q
NSRLFILE
# Step 2: Run sed command to replace triple quotes with a single quote
sed -i 's/"""/"/g' NSRLFileOutput.txt
# Step 3: Create a header file
echo '"SHA-1","MD5","CRC32","FileName","FileSize","ProductCode","OpSystemCode","SpecialCode"' > NSRLFile-header.txt
# Step 4: Concatenate output.txt to NSRLFile-header.txt
cat NSRLFileOutput.txt >> NSRLFile-header.txt
# Step 5: Remove carriage returns and create the final NSRLFile.txt
sed -e "s/\r//g" NSRLFile-header.txt > NSRLFile.txt
# Step 6: Remove temporary files
rm NSRLFileOutput.txt NSRLFile-header.txt
# Script completed
echo "Script completed successfully. NSRLFile.txt has been created."
# -----------------------------------------------------------------------------
# Step 1: Export data to NSRLMfg.txt
sqlite3 $db_filename <<NSRLMFG
BEGIN TRANSACTION;
DROP TABLE IF EXISTS EXPORT;
CREATE TABLE EXPORT AS SELECT manufacturer_id, name FROM MFG;
UPDATE EXPORT SET name = REPLACE(name, '"', '');
COMMIT;
.mode csv
.headers off
.output NSRLMfgOutput.txt
SELECT manufacturer_id, '"' || name || '"' FROM EXPORT ORDER BY manufacturer_id;
.q
NSRLMFG
# Step 2: Run sed command to replace triple quotes with a single quote
sed -i 's/"""/"/g' NSRLMfgOutput.txt
# Step 3: Create a header file
echo '"MfgCode","MfgName"' > NSRLMfg-header.txt
# Step 4: Concatenate output.txt to NSRLMfg-header.txt
cat NSRLMfgOutput.txt >> NSRLMfg-header.txt
# Step 5: Remove carriage returns and create the final NSRLMfg.txt
sed -e "s/\r//g" NSRLMfg-header.txt > NSRLMfg.txt
# Step 6: Remove temporary files
rm NSRLMfgOutput.txt NSRLMfg-header.txt
# Script completed
echo "Script completed successfully. NSRLMfg.txt has been created."
# -----------------------------------------------------------------------------
# Step 1: Export data to NSRLOS.txt
sqlite3 $db_filename <<NSRLOS
BEGIN TRANSACTION;
DROP TABLE IF EXISTS EXPORT;
CREATE TABLE EXPORT AS SELECT operating_system_id, name, version, manufacturer_id FROM OS;
UPDATE EXPORT SET name = REPLACE(name, '"', ''), version = REPLACE(version, '"', '');
COMMIT;
.mode csv
.headers off
.output NSRLOSOutput.txt
SELECT operating_system_id, '"' || name || '"', '"' || version || '"', manufacturer_id FROM EXPORT ORDER BY operating_system_id;
.q
NSRLOS
# Step 2: Run sed command to replace triple quotes with a single quote
sed -i 's/"""/"/g' NSRLOSOutput.txt
# Step 3: Create a header file
echo '"OpSystemCode","OpSystemName","OpSystemVersion","MfgCode"' > NSRLOS-header.txt
# Step 4: Concatenate output.txt to NSRLOS-header.txt
cat NSRLOSOutput.txt >> NSRLOS-header.txt
# Step 5: Remove carriage returns and create the final NSRLOS.txt
sed -e "s/\r//g" NSRLOS-header.txt > NSRLOS.txt
# Step 6: Remove temporary files
rm NSRLOSOutput.txt NSRLOS-header.txt
# Script completed
echo "Script completed successfully. NSRLOS.txt has been created."
# -----------------------------------------------------------------------------
# Step 1: Export data to NSRLProd.txt
sqlite3 $db_filename <<NSRLPROD
BEGIN TRANSACTION;
DROP TABLE IF EXISTS EXPORT;
CREATE TABLE EXPORT AS SELECT package_id, name, version, operating_system_id, manufacturer_id, language, application_type FROM PKG;
UPDATE EXPORT SET name = REPLACE(name, '"', ''), version = REPLACE(version, '"', '');
COMMIT;
.mode csv
.headers off
.output NSRLProdOutput.txt
SELECT package_id, '"' || name || '"', '"' || version || '"', operating_system_id, manufacturer_id, '"' || language || '"', '"' || application_type || '"' FROM EXPORT ORDER BY package_id;
.q
NSRLPROD
# Step 2: Run sed command to replace triple quotes with a single quote
sed -i 's/"""/"/g' NSRLProdOutput.txt
# Step 3: Create a header file
echo '"ProductCode","ProductName","ProductVersion","OpSystemCode","MfgCode","Language","ApplicationType"' > NSRLProd-header.txt
# Step 4: Concatenate output.txt to NSRLProd-header.txt
cat NSRLProdOutput.txt >> NSRLProd-header.txt
# Step 5: Remove carriage returns and create the final NSRLProd.txt
sed -e "s/\r//g" NSRLProd-header.txt > NSRLProd.txt
# Step 6: Remove temporary files
rm NSRLProdOutput.txt NSRLProd-header.txt
# Script completed
echo "Script completed successfully. NSRLProd.txt has been created."
# -----------------------------------------------------------------------------
stop_spinner
echo "Done."
echo "-----------------------------------------------------------"
echo ""
