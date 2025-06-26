import requests
from bs4 import BeautifulSoup
from typing import Dict, List, Union, Optional, Tuple, Any
import logging
from functools import lru_cache
import json
import re

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def format_size(size_str: str) -> str:
    """
    Format file size string, assuming bytes if no unit is specified.
    
    Args:
        size_str (str): Size string from HTML response
        
    Returns:
        str: Formatted size string
    """
    # If already formatted with a unit, return as is
    if size_str.strip() == "-" or size_str.strip() == "":
        return "0B"
        
    # Check if the size already has a unit
    if size_str[-1].isalpha():
        return size_str
        
    # Try to convert to number and format with B unit
    try:
        # Remove any commas and convert to float
        size_num = float(size_str.replace(',', ''))
        return f"{size_num}B"
    except ValueError:
        # If conversion fails, return as is
        return size_str


class GWASClient:
    """
    Client for interacting with the GWAS Catalog API and FTP server.
    
    This class provides methods to check repository access and retrieve file information
    from GWAS repositories.
    """
    
    # Constants
    BASE_URL = "https://www.ebi.ac.uk/gwas"
    API_BASE_URL = "https://www.ebi.ac.uk/gwas/rest/api"
    FTP_BASE_URL = "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics"
    REQUEST_TIMEOUT = 10
    
    _instance = None
    
    def __new__(cls):
        """Implement singleton pattern."""
        if cls._instance is None:
            cls._instance = super(GWASClient, cls).__new__(cls)
            cls._instance.session = requests.Session()
        return cls._instance
    
    def handle_error(self, e: Exception, custom_msg: Optional[str] = None) -> None:
        """
        Log error messages and handle exceptions.
        
        Args:
            e (Exception): The exception that occurred
            custom_msg (Optional[str]): Custom message to prepend to the error
        
        Returns:
            None
        """
        msg = custom_msg if custom_msg else "Error occurred"
        logger.warning(f"{msg} - {str(e)}")
        return None
    
    def generate_range_string(self, input_str: str) -> str:
        """
        Generate range string based on input string.
        
        Args:
            input_str (str): The accession number (e.g., "GCST90027158")
            
        Returns:
            str: The range string (e.g., "GCST000001-GCST001000/")
        """
        prefix = input_str[:4]  # e.g., "GCST"
        number = int(input_str[4:])  # Numeric part
        
        # Calculate the range start and end
        range_start = (number // 1000) * 1000 + 1
        range_end = (number // 1000 + 1) * 1000
        
        # Construct the range string
        return f"{prefix}{range_start:06d}-{prefix}{range_end:06d}/"
    
    def get_html_response(self, acc_no: str, directory: str = "") -> Optional[BeautifulSoup]:
        """
        Fetch HTML response for a given accession number.
        
        Args:
            acc_no (str): The accession number
            directory (str): Optional subdirectory path
            
        Returns:
            Optional[BeautifulSoup]: The parsed HTML content or None if error
        """
        # Construct the URL
        base_url = f"{self.FTP_BASE_URL}/{self.generate_range_string(acc_no)}{acc_no}/{directory}"
        
        try:
            response = self.session.get(base_url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()  # Raise exception for 4XX/5XX responses
            return BeautifulSoup(response.text, 'html.parser')
        except Exception as e:
            self.handle_error(e, "Failed to connect or parse HTML")
            return None
    
    def extract_all_files(self, acc_no: str, directory: str = "") -> Union[List[Dict], str]:
        """
        Recursively extract all files from a GWAS repository.
        
        Args:
            acc_no (str): The accession number
            directory (str): Optional subdirectory path
            
        Returns:
            Union[List[Dict], str]: List of file details (name, size, last_modified, link) or error message
        """
        # Fetch the HTML response for the current directory
        html_doc = self.get_html_response(acc_no, directory)
        
        if html_doc is None:
            return "not accessible / wrong accession number"
        
        # Extract entries from the HTML table
        files_info = []
        directories = []
        
        # Base URL for constructing download links
        base_url = f"{self.FTP_BASE_URL}/{self.generate_range_string(acc_no)}{acc_no}/{directory}"
        
        for row in html_doc.select("table tr"):
            # Skip rows without enough columns or header rows
            cols = row.select("td")
            if len(cols) < 4:
                continue
                
            link = cols[1].select_one("a")
            if not link:
                continue
                
            file_name = link.text.strip()
            
            # Skip parent directory
            if "Parent Directory" in file_name:
                continue
                
            # Get last modified date from 3rd column
            last_modified = cols[2].text.strip()
            
            # Get size from 4th column
            size = cols[3].text.strip()
            
            # Check if it's a directory or file
            if file_name.endswith('/'):
                directories.append(file_name)
            else:
                # Construct full file path and download link
                file_path = f"{directory}{file_name}"
                download_link = f"{base_url}{file_name}"
                
                files_info.append({
                    "name": file_path,
                    "size": format_size(size),
                    "last_modified": last_modified,
                    "download_url": download_link
                })
        
        # Recursively process directories and gather files
        for subdir in directories:
            sub_files = self.extract_all_files(acc_no, f"{directory}{subdir}")
            if isinstance(sub_files, list):
                files_info.extend(sub_files)
        
        return files_info
    
    def get_access(self, acc_no: str) -> str:
        """
        Get access status for a GWAS accession number.
        
        Args:
            acc_no (str): The accession number
            
        Returns:
            str: Access status ("public", "not accessible / wrong accession number", or "no files in the given repo")
        """
        url = f"{self.API_BASE_URL}/studies/{acc_no}"
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()  # Raise exception for 4XX/5XX responses
        except Exception as e:
            self.handle_error(e, "Failed to connect")
            return "not accessible / wrong accession number"
        
        # Check if the repository contains files
        files = self.extract_all_files(acc_no)
        
        # Check if the files extraction returned an error string
        if isinstance(files, str) and files == "not accessible / wrong accession number":
            return "not accessible / wrong accession number"
        
        if len(files) == 0:
            return "no files in the given repo"
        
        return "public"
    
    def process_accession(self, acc_no: str) -> Dict[str, Any]:
        """
        Unified processing function for GWAS accession numbers.
        
        Args:
            acc_no (str): The accession number
            
        Returns:
            Dict[str, Any]: Dictionary with access status and file details
        """
        access_status = self.get_access(acc_no)
        
        return {
            "access": access_status,
            "data": {
                "files": self.extract_all_files(acc_no) if access_status == "public" else []
            }
        }


# Singleton instance for easy import
gwas_client = GWASClient()


# Example usage
if __name__ == "__main__":
    result = gwas_client.process_accession("GCST90027158")
    print(json.dumps(result, indent=4))