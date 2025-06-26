library(dplyr)
library(httr)
library(jsonlite)

# Function to get JSON response from the API
ena_get_json_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ebi.ac.uk/ena/portal/api/filereport?accession=", 
															acc_no, "&result=read_run&fields=run_accession,fastq_ftp,submitted_ftp,sra_ftp,bam_ftp&format=json&download=false&limit=0")

	
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content)
	
	# Modify the relevant columns to keep only the element after the last slash
	json_data$fastq_ftp <- sub(".*/", "", json_data$fastq_ftp)
	json_data$submitted_ftp <- sub(".*/", "", json_data$submitted_ftp)
	json_data$sra_ftp <- sub(".*/", "", json_data$sra_ftp)
	json_data$bam_ftp <- sub(".*/", "", json_data$bam_ftp)
	
	return(json_data)
}

print(ena_get_json_response("ERP000038"))
