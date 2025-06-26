library(dplyr)
library(httr)
library(xml2)
library(stringr)
library(jsonlite)

# Centralized error handler
pdb_handle_error <- function(e, custom_msg = NULL) {
	msg <- if (!is.null(custom_msg)) custom_msg else "Error occurred"
	warning(paste(msg, e$message))
	return(NULL)
}

# Get the dataset response (FASTA file content)
pdb_get_dataset_response <- function(acc_no) {
	dataset_url <- paste0("https://www.rcsb.org/fasta/entry/", acc_no, "/display")
	response <- tryCatch({
		GET(dataset_url)
	}, error = \(e) pdb_handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) {
		return("not accessible / wrong accession number")
	}
	
	content <- content(response, as = "text", encoding = "UTF-8")
	return(content)
}

# Extract files from the dataset content
pdb_extract_files <- function(acc_no) {
	dataset_content <- pdb_get_dataset_response(acc_no)
	
	if (dataset_content == "not accessible / wrong accession number") {
		return("not accessible / wrong accession number")
	}
	
	# Split by ">" character and remove empty entries
	split_strings <- strsplit(dataset_content, split = ">")[[1]]
	split_strings <- split_strings[split_strings != ""]
	
	return(split_strings)
}

# Get the access status for the PDB entry
pdb_get_access <- function(acc_no) {
	access_url <- paste0("https://data.rcsb.org/rest/v1/core/entry/", acc_no)
	
	response <- tryCatch({
		GET(access_url)
	}, error = \(e) pdb_handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) {
		return("not accessible / wrong accession number")
	}
	
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- tryCatch({
		fromJSON(content, simplifyVector = FALSE)
	}, error = \(e) pdb_handle_error(e, "Failed to parse JSON"))
	
	pdbx_status <- json_data$pdbx_database_status
	
	status_mapping <- list(
		"PROC" = "Processing in progress",
		"WAIT" = "Awaiting author approval",
		"REL" = "public",
		"HOLD" = "On hold until further date",
		"HPUB" = "On hold until publication",
		"OBS" = "Entry has been obsoleted",
		"WDRN" = "Entry has been withdrawn by depositor"
	)
	
	if (!is.null(pdbx_status) && "status_code" %in% names(pdbx_status)) {
		status_code <- pdbx_status$status_code
		status_description <- status_mapping[[status_code]]
		
		if (!is.null(status_description)) {
			return(status_description)
		} else {
			return(paste("Status code", status_code, "not found in the description mapping"))
		}
	} else {
		return("Status code not found in the response")
	}
}

# Unified function to get access status and file data
pdb_process_accession <- function(acc_no) {
	# Get access status first
	repo_access <- pdb_get_access(acc_no)
	
	if (repo_access %in% c("not accessible / wrong accession number", "Status code not found in the response")) {
		return(list(access = repo_access, files = NULL))
	}
	
	# If access is valid, extract files
	file_names <- pdb_extract_files(acc_no)
	
	# Check if file_names contains the error message
	if (any(file_names == "not accessible / wrong accession number")) {
		return(list(access = "not accessible / wrong accession number", files = NULL))
	}
	
	# Return both access status and file data
	return(list(access = tolower(repo_access), files = file_names))
}

# Example usage
acc_no <- "7T0Z"  # Replace with actual PDB accession number
print(pdb_process_accession(acc_no))



