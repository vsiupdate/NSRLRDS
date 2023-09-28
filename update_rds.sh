#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name:       update_rds.sh
# Description:       Updates the RDS database and optionally converts it to CSV
# Version:           1.0
# Created Date:      September 27, 2023
# Last Modified:     September 27, 2023
# -----------------------------------------------------------------------------

# Header Section
echo ""
echo ""
echo "==========================================================="
echo "NIST NSRL RDS Hash Set Update"
echo "==========================================================="
echo "Script Actions:"
echo "- Dynamically identifies the latest ZIP files for both the"
echo "    full and delta RDS datasets."
echo "- Extracts these ZIP files into a temporary directory."
echo "- Applies delta changes to full RDS database using SQLite3"
echo "- Renames the updated database file with today's date and"
echo "    moves it back to the original folder."
echo "- Once complete, the RDS can be converted to CSV for use "
echo "    with OSForensics"
echo "==========================================================="
echo ""
echo ""
# Ask the user if they want to convert RDS to CSV
echo "Post-update, convert the updated RDS to CSV? (yes/no)"
read user_response

echo ""
echo "Starting script..."

echo ""
# Identify the most recent RDS full data set ZIP file
latest_full_zip=$(ls -t RDS_*_curated.zip | head -n 1)
echo "Identified latest full RDS ZIP as $latest_full_zip."

# Identify the most recent RDS delta data set ZIP file
latest_delta_zip=$(ls -t RDS_*_curated_delta.zip | head -n 1)
echo "Identified latest delta RDS ZIP as $latest_delta_zip."

# Create a temporary directory
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir."
# Extract the ZIP files to the temporary directory
echo "Starting to extract ZIP files..."
echo "-----------------------------------------------------------"
unzip "$latest_full_zip" -d "$temp_dir"
echo "Extracted $latest_full_zip."
echo "-----------------------------------------------------------"
unzip "$latest_delta_zip" -d "$temp_dir"
echo "Extracted $latest_delta_zip."
echo "-----------------------------------------------------------"
echo "ZIP files extracted."
echo ""
# Find the SQL file in the temporary directory
sql_file_path=$(find "$temp_dir" -name "*.sql")
echo "Located SQL file at $sql_file_path."

# Extract the base names without extensions for SQLite3 operations
latest_full_base=$(basename "$latest_full_zip" .zip)
echo "Base names extracted: $latest_full_base."

# Run SQLite3 commands
echo "-----------------------------------------------------------"
echo "PLEASE BE PATIENT. THIS SECTION CAN TAKE HOURS..." 
echo "Running SQLite3 commands..."
sqlite3 "$temp_dir/$latest_full_base.db" <<EOF
.read "$sql_file_path"
.q
EOF
echo "SQLite3 commands executed"
echo "-----------------------------------------------------------"
# Get today's date
today=$(date +"%Y.%m.%d")
echo "Today's date is $today"

# Debugging: Print the value of $latest_full_base
echo "Value of latest_full_base is $latest_full_base"

# Rename the database file with today's date
echo "Renaming the database file..."
mv "$temp_dir/$latest_full_base.db" "$temp_dir/RDS_${today}_curated.db"
echo "Database file renamed to RDS_${today}_curated.db"

# Optionally, move the new database file back to the original folder
echo "Moving the new database file back to present working directory..."
mv "$temp_dir/RDS_${today}_curated.db" "$PWD/"
echo "New database file moved"

# Remove the temporary directory
echo "Removing temporary directory..."
rm -r "$temp_dir"
echo "Temporary directory removed"
echo "-----------------------------------------------------------"
echo ""
if [ "$user_response" == "yes" ]; then
  echo "Starting the conversion process..."
  ./convert_rds_csv.sh
  echo "Conversion completed."
else
  echo "Exiting without conversion."
fi
echo ""
echo "==========================================================="
# Script completed
echo "Script completed successfully."

