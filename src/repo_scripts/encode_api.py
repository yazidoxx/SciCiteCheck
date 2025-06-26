import requests
import re
import json
import logging
from functools import lru_cache
from typing import Dict, List, Union, Optional
from utils import format_size, format_date

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class EncodeClient:
    """
    Client for interacting with the ENCODE API.
    
    This class provides methods to check repository access and retrieve file information
    from ENCODE repositories.
    """
    
    # Constants
    BASE_URL = "https://www.encodeproject.org"
    REQUEST_TIMEOUT = 10
    CACHE_SIZE = 128
    
    def __init__(self):
        """Initialize the ENCODE client with a requests session."""
        self.session = requests.Session()
    
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
        Get JSON response from ENCODE API for a given accession number.
        
        Args:
            acc_no (str): ENCODE accession number
        
        Returns:
            Optional[Dict]: JSON response data or None if request fails
        """
        url = f"{self.BASE_URL}/files/{acc_no}/?format=json"
        
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
    
    def get_file_metadata(self, acc_no: str) -> Dict:
        """
        Get file metadata from ENCODE API for a given accession number.
        
        Args:
            acc_no (str): ENCODE accession number
        
        Returns:
            Dict: Dictionary containing file metadata
        """
        data = self.get_json_response(acc_no)
        
        if data is None:
            return {"files": []}
        
        # Extract file size and format it
        file_size = data.get('file_size')
        formatted_size = format_size(file_size) if file_size else "unknown"
        
        # Extract date created and format it
        date_created = data.get('date_created')
        formatted_date = format_date(date_created) if date_created else "unknown"
        
        # Get file name
        href = data.get('href', '')
        match = re.search(r'.*/@@download/(.*)', href)
        file_name = match.group(1) if match else f"{acc_no}.{data.get('file_format', '')}"
        
        # Build download link
        download_link = f"{self.BASE_URL}/files/{acc_no}/@@download/{file_name}"
        
        # Create file entry
        file_entry = {
            "name": file_name,
            "size": formatted_size,
            "last_modified": formatted_date,
            "download_url": download_link
        }
        
        return {"files": [file_entry]}
    
    def get_access(self, acc_no: str) -> str:
        """
        Check if an accession is publicly accessible.
        
        Args:
            acc_no (str): ENCODE accession number
        
        Returns:
            str: Access status (public, not yet released, or error message)
        """
        data = self.get_json_response(acc_no)
        
        if data is None:
            return "Wrong accession code"
        if data.get('no_file_available') == "false" and data.get('status') != "released":
            return "no data deposited"
        
        return "public" if data.get('status') == "released" else "not yet released"
    
    def process_accession(self, acc_no: str) -> Dict:
        """
        Process an ENCODE accession and return its access status and files.
        
        Args:
            acc_no (str): The ENCODE accession number
        
        Returns:
            Dict: Dictionary containing access status and list of files with metadata
        """
        return {
            "access": self.get_access(acc_no),
            "data": self.get_file_metadata(acc_no)
        }


# Create a singleton instance for use throughout the application
encode_client = EncodeClient()


def process_accession(acc_no: str) -> Dict:
    """
    Process an ENCODE accession using the EncodeClient.
    
    This is a convenience function that uses the singleton EncodeClient instance.
    
    Args:
        acc_no (str): The ENCODE accession number
    
    Returns:
        Dict: Dictionary containing access status and list of files with metadata
    """
    return encode_client.process_accession(acc_no)


if __name__ == "__main__":
    result = process_accession("ENCFF682WPF")
    logger.info(json.dumps(result, indent=2))