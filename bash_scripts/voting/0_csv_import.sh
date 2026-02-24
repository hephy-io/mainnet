# Import from .csv file with format:
# Action Title | ActionID#Index | Role | Vote | Metadata_File

awk -F',' 'NR > 1 {print $2, $3, $4, $5}' voting.csv > governance.list
