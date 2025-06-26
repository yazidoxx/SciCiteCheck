import requests
from bs4 import BeautifulSoup
from typing import Dict, List, Union, Optional, Tuple
import pandas as pd
import logging
from functools import lru_cache
from concurrent.futures import ThreadPoolExecutor
from utils import format_size, format_date
import json

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class OSFClient:
    """
    Client for interacting with the Open Science Framework (OSF) API.
    
    This class provides methods to check repository access and retrieve file information
    from OSF repositories.
    """
    
    # Constants
    BASE_URL = "https://osf.io"
    API_BASE_URL = "https://api.osf.io/v2"
    DOWNLOAD_URL = f"{BASE_URL}/download"
    REQUEST_TIMEOUT = 10
    MAX_WORKERS = 10
    CACHE_SIZE = 128
    
    def __init__(self):
        """Initialize the OSF client with a requests session."""
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
    def check_access(self, repo_id: str) -> str:
        """
        Check if a repository is accessible and determine its type.
        
        Args:
            repo_id (str): The OSF repository ID
            
        Returns:
            str: Repository type or access status message
        """
        url = f"{self.BASE_URL}/{repo_id}"
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            repo_type = soup.find('button', class_='btn btn-default disabled')
            
            if repo_type and repo_type.text.strip():
                return repo_type.text.strip()
            return "No access information found"
            
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to connect")
            return "not accessible / wrong repository ID"
    
    @lru_cache(maxsize=CACHE_SIZE)
    def get_json_response(self, repo_id: str, folder_id: Optional[str] = None) -> Optional[Dict]:
        """
        Get JSON response from the OSF API for a repository or folder.
        
        Args:
            repo_id (str): The OSF repository ID
            folder_id (Optional[str]): The folder ID within the repository
            
        Returns:
            Optional[Dict]: JSON response data or None if request failed
        """
        base_url = f"{self.API_BASE_URL}/nodes/{repo_id}/files/osfstorage/"
        url = f"{base_url}{folder_id}/" if folder_id else base_url
        
        try:
            response = self.session.get(url, timeout=self.REQUEST_TIMEOUT)
            response.raise_for_status()
            return response.json()['data']
        except requests.exceptions.RequestException as e:
            self.handle_error(e, "Failed to connect")
            return None
    
    def process_folder(self, args: Tuple[str, str]) -> List[Dict]:
        """
        Process a folder to extract file information.
        
        Args:
            args (Tuple[str, str]): Tuple containing repository ID and folder ID
            
        Returns:
            List[Dict]: List of dictionaries containing file information
        """
        repo_id, folder_id = args
        folder_data = self.get_json_response(repo_id, folder_id)
        if folder_data:
            folder_df = pd.json_normalize(folder_data)
            files_info = []
            for _, row in folder_df.iterrows():
                if 'attributes.materialized_path' in folder_df.columns:
                    files_info.append({
                        'name': row['attributes.materialized_path'],
                        'size': format_size(row.get('attributes.size', 0)),
                        'modified': format_date(row.get('attributes.date_modified', '')),
                        'download_url': f"{self.DOWNLOAD_URL}/{row.get('id', '')}" if row.get('attributes.kind') == 'file' else ''
                    })
            return files_info
        return []
    
    def get_all_file_names(self, repo_id: str) -> List[Dict]:
        """
        Get information about all files in a repository.
        
        Args:
            repo_id (str): The OSF repository ID
            
        Returns:
            List[Dict]: List of dictionaries containing file information
        """
        main_data = self.get_json_response(repo_id)
        
        if not main_data:
            return []
        
        main_df = pd.json_normalize(main_data)
        
        files_info = []
        # Process files in main directory
        file_rows = main_df[main_df['attributes.kind'] == 'file']
        for _, row in file_rows.iterrows():
            files_info.append({
                'name': row['attributes.materialized_path'],
                'size': format_size(row.get('attributes.size', 0)),
                'last_modified': format_date(row.get('attributes.date_modified', '')),
                'download_url': f"{self.DOWNLOAD_URL}/{row.get('id', '')}"
            })

        folder_ids = main_df[main_df['attributes.kind'] == 'folder']['id'].tolist()

        # Process folders concurrently
        with ThreadPoolExecutor(max_workers=min(len(folder_ids), self.MAX_WORKERS)) as executor:
            folder_results = executor.map(self.process_folder, [(repo_id, fid) for fid in folder_ids])
            for result in folder_results:
                files_info.extend(result)
        
        return files_info
    
    def process_accession(self, repo_id: str) -> Dict:
        """
        Process an OSF repository accession and return its access status and files.
        
        Args:
            repo_id (str): The OSF repository ID
        
        Returns:
            Dict: Dictionary containing access status and list of files with metadata
        """
        repo_access = self.check_access(repo_id)
        
        if repo_access in ["not accessible / wrong repository ID", "Failed to fetch data", "No access information found"]:
            return {
                "access": repo_access,
                "data": {
                    "files": []
                }
            }
        
        files_info = self.get_all_file_names(repo_id)
        
        return {
            "access": repo_access.lower(),
            "data": {
                "files": files_info
            }
        }


# Create a singleton instance for use throughout the application
osf_client = OSFClient()


def process_accession(repo_id: str) -> Dict:
    """
    Process an OSF repository accession using the OSFClient.
    
    This is a convenience function that uses the singleton OSFClient instance.
    
    Args:
        repo_id (str): The OSF repository ID
    
    Returns:
        Dict: Dictionary containing access status and list of files with metadata
    """
    return osf_client.process_accession(repo_id)


if __name__ == "__main__":
    result = process_accession("bgw73")
    logger.info(json.dumps(result, indent=2))
