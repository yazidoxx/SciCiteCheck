import requests
import json
from bs4 import BeautifulSoup
import re
from functools import lru_cache
import logging
from typing import Dict, List, Union, Optional
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from utils import format_size, format_date

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ArrayExpressClient:
    """
    Client for interacting with the ArrayExpress API.
    
    This class provides methods to check repository access and retrieve file information
    from ArrayExpress repositories.
    """
    
    # Constants
    BASE_BIOSTUDIES_URL = "https://www.ebi.ac.uk/biostudies/files"
    BASE_FTP_URL = "https://ftp.ebi.ac.uk/biostudies/fire/E-MTAB-"
    ACCESSION_PATTERN = r"^E-MTAB-(\d+)$"
    REQUEST_TIMEOUT = 10
    CACHE_SIZE = 128
    
    def __init__(self):
        """Initialize the ArrayExpress client with a requests session with retries."""
        self.session = requests.Session()
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        self.session.mount("https://", HTTPAdapter(max_retries=retry_strategy))
        self.session.mount("http://", HTTPAdapter(max_retries=retry_strategy))
    
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
    
    @lru_cache(maxsize=CACHE_SIZE)
    def get_json_response(self, acc_no: str) -> Optional[Dict]:
        """
        Get JSON response from ArrayExpress API for a given accession number.
        
        Args:
            acc_no (str): ArrayExpress accession number
        
        Returns:
            Optional[Dict]: JSON response data or None if request fails
        """
        url = f"{self.BASE_BIOSTUDIES_URL}/{acc_no}/{acc_no}.json"
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to connect")
            return None
        except json.JSONDecodeError as e:
            self.handle_error(e, "Failed to parse JSON")
            return None
    
    def get_all_file_names(self, acc_no: str) -> List[str]:
        """
        Get all file names from JSON response.
        
        Args:
            acc_no (str): ArrayExpress accession number
        
        Returns:
            List[str]: List of file paths
        """
        json_data = self.get_json_response(acc_no)
        if not json_data:
            return []
        
        files = set()
        
        def extract_paths(obj):
            if isinstance(obj, dict):
                files.add(obj.get('path', ''))
                for value in obj.values():
                    extract_paths(value)
            elif isinstance(obj, list):
                for item in obj:
                    extract_paths(item)
        
        extract_paths(json_data)
        return [f for f in files if f]  # Remove empty strings
    
    @lru_cache(maxsize=CACHE_SIZE)
    def generate_ftp_url(self, acc_no: str) -> Optional[str]:
        """
        Generate FTP URL with caching.
        
        Args:
            acc_no (str): ArrayExpress accession number
        
        Returns:
            Optional[str]: FTP URL or None if invalid accession number
        """
        match = re.match(self.ACCESSION_PATTERN, acc_no)
        if not match:
            return None
        
        numeric_part = match.group(1)
        last_three = numeric_part[-3:]
        return f"{self.BASE_FTP_URL}/{last_three}/{acc_no}/Files"
    
    def get_all_file_names_ftp(self, acc_no: str) -> List[Dict]:
        """
        Get all file names, sizes, and links from FTP.
        
        Args:
            acc_no (str): ArrayExpress accession number
        
        Returns:
            List[Dict]: List of file information dictionaries
        """
        url = self.generate_ftp_url(acc_no)
        if not url:
            return []
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')
            
            files_info = []
            rows = soup.find_all('tr')[3:-1]  # Skip header rows and last row
            
            for row in rows:
                cols = row.find_all('td')
                if len(cols) >= 4:
                    file_link = cols[1].find('a')
                    if file_link:
                        name = file_link.text
                        link = url + '/' + name if not name.startswith('Parent') else None
                        size = cols[3].text.strip()
                        last_modified = cols[2].text.strip()
                        
                        if link:  # Skip parent directory
                            files_info.append({
                                'name': name,
                                'size': size,
                                'last_modified': last_modified,
                                'download_url': link,
                            })
            
            return files_info
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to connect")
            return []
    
    def check_access(self, acc_no: str) -> str:
        """
        Check if the accession is publicly accessible.
        
        Args:
            acc_no (str): ArrayExpress accession number
        
        Returns:
            str: Access status (public, restricted, or error message)
        """
        url = self.generate_ftp_url(acc_no)
        if not url:
            return "not accessible / wrong accession number"
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            return "public"
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to check access")
            return "restricted"
    
    def process_accession(self, acc_no: str) -> Dict:
        """
        Process an ArrayExpress accession and return its access status and files.
        
        Args:
            acc_no (str): The ArrayExpress accession number
        
        Returns:
            Dict: Dictionary containing access status and list of files with metadata
        """
        access_status = self.check_access(acc_no)
        
        if access_status != "public":
            return {
                "access": access_status,
                "data": {
                    "files": []
                }
            }
        
        files_info = self.get_all_file_names_ftp(acc_no)
        
        return {
            "access": access_status,
            "data": {
                "files": files_info
            }
        }


# Create a singleton instance for use throughout the application
array_express_client = ArrayExpressClient()


def process_accession(acc_no: str) -> Dict:
    """
    Process an ArrayExpress accession using the ArrayExpressClient.
    
    This is a convenience function that uses the singleton ArrayExpressClient instance.
    
    Args:
        acc_no (str): The ArrayExpress accession number
    
    Returns:
        Dict: Dictionary containing access status and list of files with metadata
    """
    return array_express_client.process_accession(acc_no)


if __name__ == "__main__":
    logger.info(json.dumps(process_accession("E-MTAB-10759"), indent=2))
