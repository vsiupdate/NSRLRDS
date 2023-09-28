# NSRLRDS

## What is the NSRL?
The National Software Reference Library (NSRL), a part of the U.S. Department of Commerce's National Institute of Standards and Technology, serves as a comprehensive resource for computer forensics. It consists of a large collection of software packages, a database with detailed metadata about each file in those packages, and a publicly accessible Reference Data Set (RDS) updated quarterly. 

The RDS provides crucial data like cryptographic hash values and file origins to uniquely identify files. This data aids in swiftly recognizing files during forensic investigations, mainly to rule out known files like those from operating systems or applications, thereby streamlining the investigative process.

## Download and Conversion 
For versions of the NSRL dataset after RDSv3, the dataset must be converted to CSV format to be imported into OSForensics. The two shell scripts are designed to convert the data to the appropriate format. 

NOTE: these require the bash shell is required to perform the conversion.  Sqlite3 must be installed.  Plenty of drive space must be available. 

Download latest FULL SQL and DELTA datasets from https://www.nist.gov/itl/ssd/software-quality-group/national-software-reference-library-nsrl/nsrl-download/current-rds and place them appropriate folders (i.e. Modern_Minimal, Legacy,_Minimal, Android_Minimal, iOS_Minimal).

Place both scripts in the root of each folder and run from there: 

```
cd /path/to/scripts
chmod +x update_rds.sh
chmod +x convert_rds_csv.sh
./update_rds.sh
```

## update_rds.sh
NIST NSRL RDS Hash Set Update
Script Actions:
- Dynamically identifies the latest ZIP files for both the full and delta RDS datasets
- Extracts these ZIP files into a temporary directory
- Applies delta changes to full RDS database using SQLite3
- Renames the updated database file with today's date and moves it back to the original folder
- Once complete, the RDS can be converted to CSV

## convert_rds_csv.sh
Convert RDS Curated Database to CSV Files
Script Actions:
- Automatically identifies the most recent curated.db file
- Initializes SQLite with performance tuning PRAGMAs
- Exports various tables to CSV files



