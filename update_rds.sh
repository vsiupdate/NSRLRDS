#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name:       update_rds.sh
# Description:       Updates the RDS database and optionally converts it to CSV
# Version:           1.0.6
# Created Date:      20230917
# Last Modified:     20231006
# -----------------------------------------------------------------------------

# Define log file
logfile="RDS_update_$(date +"%Y%m%d%H%M%S").log"

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
echo ""
echo "==========================================================="
echo "NIST NSRL RDS Hash Set Update"
echo "==========================================================="
echo "Script Actions:"
echo "** Dynamically identifies the latest ZIP files for both the"
echo "     full and delta RDS datasets"
echo "** Extracts these ZIP files into a temporary directory"
echo "** Applies delta changes to full RDS database using SQLite3"
echo "** Renames the updated database file with today's date and"
echo "     moves it back to the original folder"
echo "** Once complete, the RDS can be converted to CSV for use "
echo "     with OSForensics"
echo "==========================================================="
echo ""
# Ask the user if they want to convert RDS to CSV
echo "Post-update, convert the updated RDS to CSV? (yes/no)"
read user_response

echo ""
echo "-----------------------------------------------------------"
echo "Starting script..."


# Check if ZIP files exist for the full RDS
if [ -f RDS_*_minimal.zip ]; then
  latest_full_zip=$(ls -t RDS_*_minimal.zip | head -n 1)
  echo ""
  echo "Identified latest full RDS ZIP as $latest_full_zip"
  # Extract the "modern_minimal" part from the ZIP filename
  os_version_set=${latest_full_zip#RDS_*_}  # Remove prefix
  os_version_set=${os_version_set%.zip}  # Remove .zip suffix
  echo "Identified OS version set as $os_version_set"
  echo ""
  # Unzip the file to the PWD
  unzip -o "$latest_full_zip"
  # Search for the latest full DB file
  latest_full_db=$(find . -type f -name "RDS_*_minimal.db" -print0 | xargs -0 ls -t | head -n 1)
  if [ -z "$latest_full_db" ]; then
	echo ""
	echo "Error: No suitable .db file found for the full RDS."
	exit 1
  else
	echo ""
	echo "Identified latest full RDS DB as $latest_full_db"
	echo ""
  fi
else
  latest_full_db=$(ls -t RDS_*_minimal.db | head -n 1)
  if [ -z "$latest_full_db" ]; then
  	echo ""
	echo "Error: No suitable .db file found for the full RDS."
	exit 1
  else
       	echo ""	
       	echo "No ZIP found. Identified latest full RDS DB as $latest_full_db"
  fi
  # Extract the "_{OS}_minimal" part from the DB filename
  os_version_set=${latest_full_db#RDS_*_}  # Remove prefix
  os_version_set=${os_version_set%.db}  # Remove .db suffix
  echo "Identified OS version set as $os_version_set"
  echo ""
fi

# Check if ZIP files exist for the delta RDS
if [ -f RDS_*_delta.zip ]; then
  latest_delta_zip=$(ls -t RDS_*_minimal_delta.zip | head -n 1)
  echo ""
  echo "Identified latest delta RDS ZIP as $latest_delta_zip"
  echo ""
  # Unzip the file to the PWD
  unzip -o "$latest_delta_zip"
  # Search for the latest delta SQL file
  latest_delta_sql=$(find . -type f -name "RDS_*_minimal_delta.sql" -print0 | xargs -0 ls -t | head -n 1)
  if [ -z "$latest_delta_sql" ]; then
  	echo ""
	echo "Error: No suitable .sql file found for the delta RDS."
	exit 1
  else
	echo ""
	echo "Identified latest delta RDS SQL as $latest_delta_sql"
  fi
else
  # Skip extraction and use $latest_delta_sql
  latest_delta_sql=$(ls -t RDS_*_minimal_delta.sql | head -n 1)
  if [ -z "$latest_delta_sql" ]; then
	echo ""
    	echo "Error: No suitable .sql file found for the delta RDS."
    	exit 1
  else
    	echo ""
    	echo "No ZIP found. Identified latest delta RDS SQL as $latest_delta_sql"
  fi
fi

# Modify the SQL file to replace INSERTINTO with INSERT OR IGNORE INTO
echo "-----------------------------------------------------------"
echo "Modifying SQL file to ignore duplicate entries..."
sed -i 's/INSERT INTO/INSERT OR IGNORE INTO/g' "$latest_delta_sql"
echo "Done."

# Run SQLite3 commands
echo "-----------------------------------------------------------"
echo "(DATABASE UPDATE) THIS SECTION CAN TAKE HOURS TO COMPLETE" 
echo "Preparing SQLite3 variables..."
echo ""
echo "Database to use: " $latest_full_db
echo "SQL to read: " $latest_delta_sql
echo ""
read -p "Verify DB and SQL are correct, then press ENTER to continue"
echo ""
spinner_pid=
start_spinner "Running SQLite3 commands "
sqlite3 "$latest_full_db" <<SQL_COMMANDS
.read "$latest_delta_sql"
.q
SQL_COMMANDS
stop_spinner 
echo ""
echo "SQLite3 commands executed."
echo "-----------------------------------------------------------"

# Get today's date
today=$(date +"%Y.%m.%d")
echo "Today's date: $today"
# Debugging: Print the value of $latest_full_base
echo "Value of latest_full_db: $latest_full_db"
echo ""
# Rename the database file with today's date and OS version set
echo "Renaming the database file..."
if [ -f "$latest_full_db" ]; then
  mv "$latest_full_db" "RDS_${today}_curated_${os_version_set}.db"
  echo "Database file renamed: RDS_${today}_curated_${os_version_set}.db"
else
  echo "Error: Database file not found for renaming"
fi

echo "-----------------------------------------------------------"

if [ "$user_response" == "yes" ]; then
  # Create a new directory with the specified name
  new_dir="NSRL_CSV_RDS_${today}_curated_${os_version_set}"
  mkdir "$new_dir"
  echo "Created new directory: $new_dir"
  echo "-----------------------------------------------------------"
  echo "Starting the conversion process..."
  echo ""
  echo "Running convert_rds_csv.sh"
  ./convert_rds_csv.sh
  echo "Conversion complete."
  # Optionally, move the converted CSV files to the new directory
  
  echo "Zipping NSRL*.txt files..."
  zip "NSRL_CSV_RDS_${today}_curated_${os_version_set}.zip" NSRL*.txt
  echo "Zipping complete."
  
  echo "Cleaning up RDS* folders..."
  for dir in RDS_*; do
    if [ -d "$dir" ]; then
      rm -r "$dir"
    fi
  done
  echo "Clean-up complete."
  
  mv NSRL*.txt "$new_dir/"
else
  echo "Exiting without conversion."
fi
echo "==========================================================="
echo "Script completed successfully."
echo ""

