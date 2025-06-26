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
massive_get_response <- function(acc_no) {
	response_url <- paste0("https://massive.ucsd.edu/ProteoSAFe/FindDatasets?query=", acc_no)
	response <- tryCatch({
		GET(response_url)
	}, error = \(e) handle_error(e, "Failed to connect"))
	
	if (is.null(response) || status_code(response) != 200) {
		return("not accessible / wrong accession number")
	}
	
	return(response)
}

massive_get_access <- function(acc_no) {
	# Fetch the response from the API or website
	response <- massive_get_response(acc_no) 
	content <- content(response, as = "text", encoding = "UTF-8")
	
	# Parse the HTML content
	html_content <- read_html(content)
	
	# Extract the text inside the <span> tag with class "tag"
	access_state <- html_content %>%
		html_nodes(".tag") %>%  # Select elements with class 'tag'
		html_text(trim = TRUE) %>%  # Extract and trim the text
		.[2]  # Select the first occurrence (if multiple)
	
	return(tolower(access_state))
}



massive_get_task_id <- function(acc_no) {
	response <- massive_get_response(acc_no)
	task_id <- sub(".*task=([^&]+).*", "\\1", response$url)
}

massive_get_all_files <- function(acc_no){
	task_id <- massive_get_task_id(acc_no)
	dataset_url <- paste0("https://massive.ucsd.edu/ProteoSAFe/dataset_files.jsp?task=", task_id)
	
	response <- tryCatch({
		GET(dataset_url)
	}, error = \(e) handle_error(e, "Failed to connect"))
	
	content <- content(response, as = "text", encoding = "UTF-8")
	
	scripts <- read_html(content) %>%
		html_nodes("script") %>%
		html_text(trim = TRUE)
	
	# Extract file names from the script containing dataset_files
	file_names <- NULL
	for (script in scripts) {
		if (grepl("var dataset_files\\s*=\\s*\\{", script)) {
			# Extract only the JSON object between the curly braces
			json_str <- sub(".*?var\\s+dataset_files\\s*=\\s*(\\{.*?\\});.*", "\\1", script)
			
			tryCatch({
				data <- jsonlite::fromJSON(json_str)
				if (!is.null(data$row_data)) {
					file_names <- data$row_data$name
					break  # Exit loop once we find and successfully parse dataset_files
				}
			}, error = function(e) {
				warning("Failed to parse JSON: ", e$message)
			})
		}
	}
	
	return(file_names)
}

massive_process_accession <- function(acc_no){
	list(
		access = massive_get_access(acc_no),
		files = massive_get_all_files(acc_no)
	)
	}

print(massive_process_accession("MSV000088042"))