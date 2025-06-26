library(dplyr)
library(httr)
library(xml2)
library(stringr)

# Define the function
clinvar_extract_variation_id <- function(url) {
	# Extract the string between "variation/" and "/?oq"
	result <- sub(".*variation/([0-9]+)/\\?", "\\1", url)
	return(result)
}


clinvar_get_dataset_json_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ncbi.nlm.nih.gov/clinvar/?term=", acc_no)
	
	# Make the GET request
	response <- GET(url)
	
	# Get variation id
	variation_id <- clinvar_extract_variation_id(response$url)
	print
	# Construct the dataset URL
	dataset_url <- paste0("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=clinvar&id=", variation_id, "&retmode=json")
	
	# Make the GET request
	response <- GET(dataset_url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	# Parse the content
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content)
	
	return(json_data)
}


clinvar_extract_uid_data <- function(acc_no) {
	
	#get the parsed data
	parsed_data <- clinvar_get_dataset_json_response(acc_no)
	
	# Extract UIDs
	uids <- parsed_data$result$uids
	
	# Initialize a list to store results
	results <- list()
	
	for (uid in uids) {
		# Navigate to the specific UID data
		uid_data <- parsed_data$result[[uid]]
		
		# Extract required fields
		accession <- uid_data$accession
		scvs <- uid_data$supporting_submissions$scv
		rcvs <- uid_data$supporting_submissions$rcv
		
		# Store the results for the UID
		results[[uid]] <- list(
			accession = accession,
			scvs = scvs,
			rcvs = rcvs
		)
	}
	
	return(results)
}

print(clinvar_extract_uid_data("SCV002599428"))