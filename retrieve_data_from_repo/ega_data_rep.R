library(dplyr)
library(httr)
library(xml2)
library(stringr)
library(rvest)
library(jsonlite)

ega_extract_datasets <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://metadata.ega-archive.org/studies/", acc_no, "/datasets")
	
	# Make the GET request
	response <- GET(url, config = httr::config(http_version = 1.1))
	
	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content, simplifyVector = FALSE) 
	
	# Extract datasets and retrieve accession_ids and access_types
	datasets <- json_data # Assuming the JSON directly contains an array of datasets
	
	# Check if files exist
	if (is.null(datasets) || length(datasets) == 0) {
		return(NULL)  # Return NULL if there are no files
	}
	
	# Extract all accession_ids from the files and combine them into one list
	accession_ids <- unlist(lapply(datasets, function(dataset) dataset$accession_id))
	
}

ega_extract_files <- function(dataset_acc_no) {
	# Construct the URL
	url <- paste0("https://metadata.ega-archive.org/datasets/", dataset_acc_no, "/files")
	
	# Make the GET request with HTTP/1.1
	response <- GET(url, config = httr::config(http_version = 1.1))
	
	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content, simplifyVector = FALSE) 
	
	# Extract files (assuming the JSON directly contains an array of files)
	files <- json_data  # Assuming the JSON directly contains an array of file entries
	
	# Check if files exist
	if (is.null(files) || length(files) == 0) {
		return(NULL)  # Return NULL if there are no files
	}
	
	# Extract all accession_ids from the files and combine them into one list
	accession_ids <- unlist(lapply(files, function(file) file$accession_id))
	
	return(accession_ids)
}

ega_get_access <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://metadata.ega-archive.org/studies/", acc_no, "/datasets")
	
	# Make the GET request
	response <- GET(url, config = httr::config(http_version = 1.1))
	
	# Check the status code
	if (status_code(response) != 200) {
		return(FALSE) # Return FALSE if the status code is not 200
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content, simplifyVector = FALSE) 
	
	# Extract datasets and retrieve accession_ids and access_types
	datasets <- json_data
	
	# Check if files exist
	if (is.null(datasets) || length(datasets) == 0) {
		return(FALSE)  # Return NULL if there are no files
	}
	
	# Extract all accession_ids from the files and combine them into one list
	accession_types <- unlist(lapply(datasets, function(dataset) dataset$access_type))
	
	# Get unique access types
	unique_types <- unique(accession_types)
	
	# If there is only one unique access type, return it directly; otherwise, return a comma-separated string
	if (length(unique_types) == 1) {
		return(unique_types)  # Return the single type
	} else {
		return(paste(unique_types, collapse = ","))  # Return a comma-separated string of types
	}
}

# access <- ega_get_access("EGAS00001005537")
# results <- ega_extract_datasets("EGAS00001005537")
# # files <- ega_extract_files("EGAD50000000624")
# print(results)
# # print(files)
# print(access)


library(dplyr)
library(httr)
library(jsonlite)

# Base configuration
ega_base_config <- function() {
	httr::config(http_version = 1.1)
}

# Centralized API call handler
ega_api_call <- function(endpoint) {
	base_url <- "https://metadata.ega-archive.org"
	url <- paste0(base_url, endpoint)
	
	response <- tryCatch({
		GET(url, config = ega_base_config())
	}, error = function(e) NULL)
	
	if (is.null(response) || status_code(response) != 200) return(NULL)
	
	tryCatch({
		fromJSON(rawToChar(response$content), simplifyVector = FALSE)
	}, error = function(e) NULL)
}

# Extract datasets with improved error handling
ega_extract_datasets <- function(acc_no) {
	json_data <- ega_api_call(sprintf("/studies/%s/datasets", acc_no))
	
	if (is.null(json_data) || length(json_data) == 0) return(NULL)
	
	vapply(json_data, 
								function(dataset) dataset$accession_id, 
								character(1))
}

# Extract files with validation
ega_extract_files <- function(dataset_acc_no) {
	json_data <- ega_api_call(sprintf("/datasets/%s/files", dataset_acc_no))
	
	if (is.null(json_data) || length(json_data) == 0) return(NULL)
	
	vapply(json_data, 
								function(file) file$accession_id, 
								character(1))
}

ega_get_access_dataset<- function(acc_no) {
	json_data <- ega_api_call(sprintf("/datasets/%s", acc_no))
	if (is.null(json_data) || length(json_data) == 0) return("error")
	access_types <- json_data$access_type
	
}

# Get access with improved type handling
ega_get_access <- function(acc_no) {
	json_data <- ega_api_call(sprintf("/studies/%s/datasets", acc_no))
	
	if (is.null(json_data) || length(json_data) == 0) return("error")
	
	access_types <- vapply(json_data,
																								function(dataset) dataset$access_type,
																								character(1))
	
	unique_types <- unique(access_types)
	if (length(unique_types) == 1) unique_types else paste(unique_types, collapse = ",")
}

ega_process_accession <- function(acc_no) {
	if (startsWith(acc_no, "EGAD")) {
		list(
			access = ega_get_access_dataset(acc_no),
			datasets = list(acc_no), # Directly set datasets to the accession number
			files = list(ega_extract_files(acc_no)) # Directly extract files for the accession number
		)
	} else {
		list(
			access = ega_get_access(acc_no),
			datasets = ega_extract_datasets(acc_no),
			files = lapply(ega_extract_datasets(acc_no), ega_extract_files)
		)
	}
}


print(ega_process_accession("EGAS00001005809"))
