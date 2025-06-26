# library(dplyr)
# library(httr)
# library(xml2)
# library(stringr)
# 
# # Function to get JSON response from the API
# geo_get_xml_response <- function(acc_no) {
# 	# Construct the URL
# 	url <- paste0("https://ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=", acc_no, "&targ=self&form=xml&view=quick")
# 	
# 	# Make the GET request
# 	response <- GET(url)
# 	
# 	# Check the status code
# 	if (status_code(response) != 200) {
# 		return("not accessible / wrong accession number") # Return NULL if the status code is not 200
# 	}
# 	
# 	# Parse the JSON response
# 	content <- content(response, as = "text", encoding = "UTF-8")
# 	
# 	# Check if the content contains the "Could not find a public or private accession" message
# 	if (grepl("Could not find a public or private accession", content)) {
# 		return("not accessible / wrong accession number")
# 	}
# 	
# 	# print(content)
# 	xml_content <- read_xml(content)  # Use xml2 to parse the XML content
# 	
# 	return(xml_content)
# }
# 
# geo_extract_accession_and_supplementary <- function(acc_no) {
# 	
# 	xml_content <- geo_get_xml_response(acc_no)
# 	# print(xml_content)
# 	
# 	# Parse the XML content
# 	if (!inherits(xml_content, "xml_document")) { return("not accessible / wrong accession number")}
# 	
# 	# Define the namespace
# 	ns <- c(x = "http://www.ncbi.nlm.nih.gov/geo/info/MINiML")
# 	
# 	# Extract sample IDs (iid from <Sample iid="GSM4891024">)
# 	accession_numbers <- xml_find_all(xml_content, "//x:Sample", ns = ns) %>%
# 		xml_attr("iid")
# 	accession_numbers <- str_trim(accession_numbers)
# 	
# 	# # Print the length of found accessions for debugging
# 	# print(paste("Found", length(accession_numbers), "accession numbers"))
# 	
# 	# Extract supplementary data URLs where type="TAR"
# 	supplementary_files <- xml_find_all(xml_content,"//x:Supplementary-Data",ns = ns) %>% xml_text()
# 	supplementary_files <- str_trim(supplementary_files)
# 	# # Print the length of found supplementary files for debugging
# 	# print(paste("Found", length(supplementary_files), "supplementary files"))
# 	
# 	# Return as a list
# 	return(list(accession_numbers = accession_numbers, supplementary_files = supplementary_files))
# }
# 
# geo_get_access <- function(acc_no) {
# 	
# 	result <- geo_extract_accession_and_supplementary(acc_no)
# 	
# 	# Check if the result is NULL
# 	if (is.null(result)) {
# 		return("no data in the repo")
# 	}
# 	
# 	# Ensure result is a list before trying to access its elements
# 	if (is.list(result)) {
# 		# Check for accessions or supplementary files in the list
# 		if (length(result$accession_numbers) > 0 || length(result$supplementary_files) > 0) {
# 			return("public")
# 		}
# 	}
# 	
# 	# Return result if no conditions are met
# 	return(result)
# }

# # Call the function
# extracted_elements <- geo_extract_accession_and_supplementary("GSE161173")
# # Print the extracted elements
# print(extracted_elements)
# print(geo_get_access("GSE161173"))

library(dplyr)
library(httr)
library(xml2)
library(stringr)

# Centralized error handler
handle_error <- function(e, custom_msg = NULL) {
	msg <- if (!is.null(custom_msg)) custom_msg else "Error occurred"
	warning(paste(msg, e$message))
	return(NULL)
}

# Get XML response with improved error handling
geo_get_xml_response <- function(acc_no) {
	url <- sprintf("https://ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=%s&targ=self&form=xml&view=quick", acc_no)
	
	response <- tryCatch({
		GET(url)
	}, error = \(e) handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) return(NULL)
	
	content <- rawToChar(response$content)
	if (grepl("Could not find a public or private accession", content)) return(NULL)
	
	tryCatch({
		read_xml(content)
	}, error = \(e) handle_error(e, "Failed to parse XML"))
}

# Extract accessions with improved validation
geo_extract_samples <- function(acc_no) {
	xml_content <- geo_get_xml_response(acc_no)
	if (!inherits(xml_content, "xml_document")) return("not accessible / wrong accession number")
	
	ns <- c(x = "http://www.ncbi.nlm.nih.gov/geo/info/MINiML")
	
	datasets = xml_find_all(xml_content, "//x:Sample", ns = ns) %>%
		xml_attr("iid") %>%
		str_trim()
}

geo_get_all_files <- function(acc_no,directory="") {
	# Extract the numeric part of the accession number
	numeric_part <- sub("GSE", "", acc_no)
	numeric_part <- as.numeric(numeric_part)  # Ensure it's treated as a number
	
	# Determine the subdirectory (e.g., GSE1nnn, GSE10nnn, etc.)
	base_part <- floor(numeric_part / 1000)  # Integer division to group into thousands
	acc_nnn <- paste0("GSE", base_part, "nnn/")
	
	# Generate the full URL
	ftp_link <- paste0("https://ftp.ncbi.nlm.nih.gov/geo/series/", acc_nnn, "/", acc_no, "/",directory)
	
	response <- tryCatch({
		GET(ftp_link)
	}, error = \(e) handle_error(e, "Failed to connect"))
	
	html_doc <- tryCatch({
		read_html(content(response, as = "text", encoding = "UTF-8"))
	}, error = \(e) handle_error(e, "Failed to parse HTML"))
	
# Extract entries from the HTML table
	entries <- html_doc %>%
		html_nodes("a") %>%
		html_text(trim = TRUE)
	
	# Filter out "Parent Directory" or other irrelevant links
	entries <- entries[!grepl("Parent Directory", entries)]
	entries <- entries[!grepl("HHS Vulnerability Disclosure", entries)]
	
	# Separate files and directories
	files <- entries[!grepl("/$", entries)]
	directories <- entries[grepl("/$", entries)]
	
	# Prepend directory path to file names
	files <- paste0(directory, files)
	
	# Remove empty entries
	files <- files[files != ""]
	
	# Recursively process directories and gather files
	for (subdir in directories) {
		sub_files <- geo_get_all_files(acc_no, paste0(directory, subdir))
		files <- c(files, sub_files)
	}
	
	return(files)
}



# Unified processing function
geo_process_accession <- function(acc_no) {
	datasets = geo_extract_samples(acc_no)
	files = geo_get_all_files(acc_no)
	return (list(
		access = if (!is.null(datasets) || !is.null(files) ) "public" else "not accessible",
		datasets = geo_extract_samples(acc_no),
		files = geo_get_all_files(acc_no))
	)
}

print(geo_process_accession("GSE1009"))