import requests
import json
import logging
from typing import Dict, List, Union, Optional
from functools import lru_cache
from utils import format_size, format_date

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ZenodoClient:
    """
    Client for interacting with the Zenodo API.
    
    This class provides methods to check repository access and retrieve file information
    from Zenodo repositories.
    """
    
    # Constants
    BASE_URL = "https://zenodo.org"
    API_BASE_URL = "https://zenodo.org/api"
    REQUEST_TIMEOUT = 10
    CACHE_SIZE = 128
    
    def __init__(self):
        """Initialize the Zenodo client with a requests session."""
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
    
    def format_file_info(self, data: Dict) -> List[Dict]:
        """
        Format file information from API response.
        
        Args:
            data (Dict): API response data
            
        Returns:
            List[Dict]: Formatted file information
        """
        formatted_files = []
        if data.get("entries"):
            for file_info in data["entries"]:
                formatted_files.append({
                    "name": file_info.get("key", "unknown"),
                    "size": format_size(file_info.get("size", 0)),
                    "last_modified": format_date(file_info.get("updated", "")),
                    "download_url": file_info.get("links", {}).get("content", ""),
                })
        return formatted_files
    
    @lru_cache(maxsize=CACHE_SIZE)
    def get_json_response(self, repo_id: str) -> Optional[Dict]:
        """
        Get JSON response from Zenodo API for a given repository ID.
        
        Args:
            repo_id (str): Zenodo repository ID
        
        Returns:
            Optional[Dict]: JSON response data or None if request fails
        """
        url = f"{self.API_BASE_URL}/records/{repo_id}/files"
        
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
    
    def process_accession(self, repo_id: str) -> Dict:
        """
        Process a Zenodo repository accession and return its access status and files.
        
        Args:
            repo_id (str): The Zenodo repository ID
        
        Returns:
            Dict: Dictionary containing access status and list of files with metadata
        """
        data = self.get_json_response(repo_id)
        if not data:
            return {
                "access": "not accessible / wrong repository ID",
                "data": {"files": []}
            }
        
        access_status = "public" if data.get("enabled", False) else "restricted"
        files = self.format_file_info(data)
        
        return {
            "access": access_status,
            "data": {
                "files": files
            }
        }


# Create a singleton instance for use throughout the application
zenodo_client = ZenodoClient()


def process_accession(repo_id: str) -> Dict:
    """
    Process a Zenodo repository accession using the ZenodoClient.
    
    This is a convenience function that uses the singleton ZenodoClient instance.
    
    Args:
        repo_id (str): The Zenodo repository ID
    
    Returns:
        Dict: Dictionary containing access status and list of files with metadata
    """
    return zenodo_client.process_accession(repo_id)


if __name__ == "__main__":
    result = process_accession("7059087")
    logger.info(json.dumps(result, indent=2))