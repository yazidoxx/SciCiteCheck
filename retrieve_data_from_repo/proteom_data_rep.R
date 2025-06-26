library(dplyr)
library(httr)
library(xml2)
library(stringr)

# Function to get JSON response from the API
proteom_get_xml_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=", acc_no, "&outputMode=XML&test=no")
	# print(url)
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	# print(content)
	xml_content <- read_xml(content)  # Use xml2 to parse the XML content
	
	return(xml_content)
}

# proteom_get_all_file_names <- function(acc_no) {
# 	xml_content <- proteom_get_xml_response(acc_no)
# 	# print(xml_content)
# 	
# 	# Parse the XML content
# 	if (!inherits(xml_content, "xml_document")) { stop("Input must be an xml_document object.")}
# 	
# 	 # Extract all DatasetFile nodes
#   dataset_files <- xml_find_all(xml_content, "//DatasetFile")
#   
#   # Extract the 'name' attribute for each file
#   file_names <- xml_attr(dataset_files, "name")
#   
#   # Return the extracted file names
#   return(file_names)
# }

proteom_get_all_file_names <- function(acc_no) {
	url <- paste0("https://www.ebi.ac.uk/pride/ws/archive/v3/projects/", acc_no,"/files/all")
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return("no data files / wrong accession number")
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content, simplifyVector = FALSE) 
	
	# Extract file names
	file_names <- lapply(json_data, function(file) file$fileName)
	return(unlist(file_names))
	
	}
	
proteom_get_access <- function(acc_no){
	url <- paste0("https://www.ebi.ac.uk/pride/ws/archive/v3/status/", acc_no)
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return("wrong accession number")
	}
	content <- content(response, as = "text", encoding = "UTF-8")
	
	if (tolower(content) == 'public') {return("public")}
	else if ((tolower(content) == 'not_found')) {
		return("wrong accession number")
		}
	return(tolower(content))
}

# print(proteom_get_access("PXD029398"))
# print(proteom_get_all_file_names("PXD029398"))

library(httr)
library(jsonlite)

# Function to get all file names for a given project
proteom_get_all_file_names <- function(acc_no) {
	url <- paste0("https://www.ebi.ac.uk/pride/ws/archive/v3/projects/", acc_no, "/files/all")
	
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return("no data files / wrong accession number")
	}
	
	# Parse the JSON response
	content <- content(response, as = "text", encoding = "UTF-8")
	json_data <- fromJSON(content, simplifyVector = FALSE) 
	
	# Extract file names
	file_names <- lapply(json_data, function(file) file$fileName)
	return(unlist(file_names))
}

# Function to get access status of the project
proteom_get_access <- function(acc_no) {
	url <- paste0("https://www.ebi.ac.uk/pride/ws/archive/v3/status/", acc_no)
	
	# Make the GET request
	response <- GET(url)
	
	# Check the status code
	if (status_code(response) != 200) {
		return("wrong accession number")
	}
	
	content <- content(response, as = "text", encoding = "UTF-8")
	
	# Check access status
	if (tolower(content) == 'public') {
		return("public")
	} else if (tolower(content) == 'not_found') {
		return("wrong accession number")
	}
	
	return(tolower(content))
}

# Unified function to process both access status and file names
proteom_process_accession <- function(acc_no) {
	# Get access status first
	repo_access <- proteom_get_access(acc_no)
	
	# Handle case when access is invalid
	if (repo_access %in% c("wrong accession number", "no data files / wrong accession number")) {
		return(list(access = repo_access, files = NULL))
	}
	
	# If access is valid, extract file names
	file_names <- proteom_get_all_file_names(acc_no)
	
	# Handle case when there are no files found
	if (identical(file_names, "no data files / wrong accession number")) {
		return(list(access = "no data files / wrong accession number", files = NULL))
	}
	
	# Return both access status and file names
	return(list(access = tolower(repo_access), files = file_names))
}

print(proteom_process_accession("PXD027956"))