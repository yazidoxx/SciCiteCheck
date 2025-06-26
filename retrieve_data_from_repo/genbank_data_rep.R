library(dplyr)
library(httr)
library(xml2)
library(stringr)
library(jsonlite)

# Centralized error handler
handle_error <- function(e, custom_msg = NULL) {
	msg <- if (!is.null(custom_msg)) custom_msg else "Error occurred"
	warning(paste(msg, e$message))
	return(NULL)
}


# Get the dataset response 
genbank_get_response <- function(acc_no) {
	dataset_url <- paste0("https://www.ncbi.nlm.nih.gov/nuccore/", acc_no)
	response <- tryCatch({
		GET(dataset_url)
	}, error = \(e) handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) {
		return("not accessible / wrong accession number")
	}
	
	content <- content(response, as = "text", encoding = "UTF-8")
	
	return(read_html(content))
}


genbank_get_files <- function(acc_no) {
	content <- genbank_get_response(acc_no)
	
	files <- content %>%
		html_nodes("h1") %>%
		html_text(trim = TRUE)
	return(files[2])
}

print(genbank_get_files("GM1287853"))