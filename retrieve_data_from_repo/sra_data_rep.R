library(dplyr)
library(httr)
library(xml2)
library(stringr)

###### only limited to 20 per page (pagination with js can't risk simulating it)
sra_get_dataset_html_response <- function(acc_no) {
	# Construct the URL
	url <- paste0("https://www.ncbi.nlm.nih.gov/sra/?term=", acc_no)
	
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

# Function to extract the id from the input tag
sra_extract_datasets <- function(acc_no) {
	
	html_doc <- sra_get_dataset_html_response(acc_no)
	
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

print(sra_extract_datasets('PRJNA812410'))