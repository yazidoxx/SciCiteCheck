from typing import Optional, List, Dict
import requests
import json
import logging
from functools import lru_cache
from utils import format_size, format_date

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class EMDBClient:
    """
    Client for interacting with the EMDB API.
    
    This class provides methods to retrieve file information from EMDB repositories.
    """
    
    # Constants
    BASE_URL = "https://www.ebi.ac.uk/emdb"
    API_BASE_URL = "https://www.ebi.ac.uk/emdb/api"
    FTP_BASE_URL = "https://ftp.ebi.ac.uk/pub/databases/emdb/structures"
    REQUEST_TIMEOUT = 10
    CACHE_SIZE = 128
    
    def __init__(self):
        """Initialize the EMDB client with a requests session."""
        self.session = requests.Session()
        self.access = "public"
    
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
    def get_dataset_json_response(self, acc_no: str) -> Optional[Dict]:
        """
        Get JSON response from EMDB API for a given accession number.
        
        Args:
            acc_no (str): EMDB accession number
        
        Returns:
            Optional[Dict]: JSON response data or None if request fails
        """
        dataset_url = f"{self.API_BASE_URL}/entry/{acc_no}"
        
        try:
            response = self.session.get(dataset_url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to connect")
            return None
    
    def get_file_details(self, acc_no: str) -> Optional[List[Dict]]:
        """
        Get file details from EMDB API for a given accession number.
        
        Args:
            acc_no (str): EMDB accession number
        
        Returns:
            Optional[List[Dict]]: List of file details or None if request fails
        """
        json_data = self.get_dataset_json_response(acc_no)
        if not json_data:
            return None
        
        files = []
        
        # Extract the modification date from the 'update' field in 'key_dates'
        modification_date = "unknown"
        if 'admin' in json_data and 'key_dates' in json_data['admin']:
            key_dates = json_data['admin']['key_dates']
            modification_date = key_dates.get('update')
        
        def search_files(obj):
            if isinstance(obj, dict):
                if 'file' in obj and 'size_kbytes' in obj:
                    # Determine the base path for the link
                    base_path = "map" if 'additional_map_list' not in obj else "other"
                    
                    file_info = {
                        "name": obj['file'],
                        "size": format_size(obj['size_kbytes'] * 1024),
                        "last_modified": format_date(modification_date),  # Use the extracted modification date
                        "download_url": f"{self.FTP_BASE_URL}/{acc_no}/{base_path}/{obj['file']}"
                    }
                    files.append(file_info)
                # Recursively search all elements
                for value in obj.values():
                    search_files(value)
            elif isinstance(obj, list):
                # Handle lists/arrays
                for item in obj:
                    search_files(item)
        
        # Start recursive search
        search_files(json_data)
        
        # Return None if no files found
        if not files:
            return None
        return files
    
    def get_access(self, acc_no: str) -> str:
        """
        Check if an accession is publicly accessible.
        
        Args:
            acc_no (str): EMDB accession number
        
        Returns:
            str: Access status (public or not accessible / wrong repository ID)
        """
        data = self.get_dataset_json_response(acc_no)
        
        if data is None:
            return "not accessible / wrong repository ID"
        
        return "public"
    
    def process_accession(self, acc_no: str) -> Dict:
        """
        Process an EMDB accession and return its access status and files.
        
        Args:
            acc_no (str): The EMDB accession number
        
        Returns:
            Dict: Dictionary containing access status and list of file details
        """
        access_status = self.get_access(acc_no)
        files = self.get_file_details(acc_no)
        
        return {
            "access": access_status,
            "data": {
                "files": files if files else []
            }
        }


# Create a singleton instance for use throughout the application
emdb_client = EMDBClient()


def process_accession(acc_no: str) -> Dict:
    """
    Process an EMDB accession using the EMDBClient.
    
    This is a convenience function that uses the singleton EMDBClient instance.
    
    Args:
        acc_no (str): The EMDB accession number
    
    Returns:
        Dict: Dictionary containing list of file details
    """
    return emdb_client.process_accession(acc_no)


if __name__ == "__main__":
    acc_no = "EMD-25583"
    result = process_accession(acc_no)
    logger.info(json.dumps(result, indent=2))