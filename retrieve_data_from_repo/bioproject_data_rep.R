library(dplyr)
library(httr)
library(xml2)
library(stringr)
library(rlang)
library(rvest)

bioproject_get_dataset_html_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ncbi.nlm.nih.gov/bioproject/?term=", acc_no)

	# Make the GET request
	response <- GET(url)

	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	# Parse the HTML content
	content <- content(response, as = "text", encoding = "UTF-8")
	html_doc <- read_html(content)

	# Return the parsed HTML document
	return(html_doc)
}

bioproject_extract_id <- function(input_string) {
	# Use regular expression to extract digits at the end of the string
	result <- sub(".*?(\\d+)$", "\\1", input_string)
	return(result)
}

bioproject_get_accesion_html_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ncbi.nlm.nih.gov/sra?linkname=bioproject_sra_all&from_uid=", bioproject_extract_id(acc_no))

	# Make the GET request
	response <- GET(url)

	# Check the status code
	if (status_code(response) != 200) {
		return(NULL) # Return NULL if the status code is not 200
	}
	# Parse the HTML content
	content <- content(response, as = "text", encoding = "UTF-8")
	html_doc <- read_html(content)

	# Return the parsed HTML document
	return(html_doc)
}

bioproject_extract_datasets <- function(acc_no) {
	main_html_doc <- bioproject_get_dataset_html_response(acc_no)
	if (!is_null(main_html_doc)){
	html_doc <- bioproject_get_accesion_html_response(acc_no)

	# Extract multiple file names from <a> inside <p class="title">
	file_names <- html_doc %>%
		html_nodes(".title a") %>%
		html_text(trim = TRUE)

	# Extract multiple accession codes from <dd> tag
	accession_codes <- html_doc %>%
		html_nodes("dd") %>%
		html_text(trim = TRUE)

	# Combine the extracted data into a list of data frames for each dataset
	datasets <- data.frame(
		file_name = file_names,
		accession_code = accession_codes,
		stringsAsFactors = FALSE
	)

	# Return the list of datasets (or data frame with all extracted info)
	return(datasets)
	}
	else { return (NULL) }
}

bioproject_get_access <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ncbi.nlm.nih.gov/bioproject/?term=", acc_no)

	# Make the GET request
	response <- GET(url)

	# Check the status code
	if (status_code(response) != 200) {
		return(FALSE) # Return False if the status code is not 200
	}

	# Parse the HTML content
	content <- content(response, as = "text", encoding = "UTF-8")

	# Check for the presence of the specific sentence
	if (grepl("No public data is linked to this project\\.", content)) {
		return("restricted") # Return FALSE if the sentence is found
	} else {
		return("public") # Return TRUE otherwise
	}

}

# print(bioproject_get_access('PRJNA812410'))
# print(bioproject_extract_datasets('PRJNA713953'))

library(dplyr)
library(httr)
library(xml2)
library(rvest)

# Centralized error handler
bioproject_handle_error <- function(e, custom_msg = NULL) {
	msg <- if (!is.null(custom_msg)) custom_msg else "Error occurred"
	warning(paste(msg, e$message))
	return(NULL)
}

# Get HTML response with improved error handling
bioproject_get_html_response <- function(url) {
	response <- tryCatch({
		GET(url)
	}, error = \(e) bioproject_handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) return(NULL)
	
	tryCatch({
		read_html(rawToChar(response$content))
	}, error = \(e) bioproject_handle_error(e, "Failed to parse HTML"))
}

# Extract ID with regex
bioproject_extract_id <- function(input_string) {
	sub(".*?(\\d+)$", "\\1", input_string)
}

# Get dataset HTML
bioproject_get_dataset_response <- function(acc_no) {
	url <- sprintf("https://www.ncbi.nlm.nih.gov/bioproject/?term=%s", acc_no)
	bioproject_get_html_response(url)
}

# Get accession HTML
bioproject_get_accession_response <- function(acc_no) {
	url <- sprintf("https://www.ncbi.nlm.nih.gov/sra?linkname=bioproject_sra_all&from_uid=%s",
																bioproject_extract_id(acc_no))
	bioproject_get_html_response(url)
}

# Extract accession codes as a list with improved error handling
bioproject_extract_datasets <- function(acc_no) {
	main_html <- bioproject_get_dataset_response(acc_no)
	if (is.null(main_html)) return(NULL)
	
	html_doc <- bioproject_get_accession_response(acc_no)
	if (is.null(html_doc)) return(NULL)
	
	tryCatch({
		# Extract and return the accession codes as a list
		html_doc %>%
			html_nodes("dd") %>%
			html_text(trim = TRUE) 
	}, error = \(e) bioproject_handle_error(e, "Failed to extract accession codes"))
}

# Get access status with improved validation
bioproject_get_access <- function(acc_no) {
	html_doc <- bioproject_get_dataset_response(acc_no)
	if (is.null(html_doc)) return("error")
	
	content <- html_doc %>% html_text()
	if (grepl("No public data is linked to this project\\.", content)) {
		"restricted"
	} else {
		"public"
	}
}

# Unified processing function
bioproject_process_accession <- function(acc_no) {
	list(
		access = bioproject_get_access(acc_no),
		datasets = bioproject_extract_datasets(acc_no)
	)
}

print(bioproject_process_accession('PRJEB41631'))
