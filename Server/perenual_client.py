import httpx
import logging
import json
import os
import diskcache
from typing import Optional, List, Dict, Any
from pathlib import Path
from dotenv import load_dotenv

# --- Logging Setup ---
# Use a logger specific to this module
logger = logging.getLogger("perenual_client")
# Prevent adding multiple handlers if imported multiple times
if not logger.hasHandlers():
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO) # Set default level for this logger

# --- Load Environment Variables ---
load_dotenv() # Load .env file from project root or current directory

# --- Cache Directory Setup ---
# Define cache directory relative to this file's location
# This makes it independent of where you run the main server script from
try:
    CACHE_DIR = Path(__file__).parent.resolve() / "cache"
    CACHE_DIR.mkdir(parents=True, exist_ok=True) # Ensure ./cache exists
    logger.info(f"Cache directory set to: {CACHE_DIR}")
except NameError:
    # Fallback if __file__ is not defined (e.g., interactive session)
    CACHE_DIR = Path("./cache")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"Cache directory (fallback) set to: {CACHE_DIR.resolve()}")
except OSError as e:
    logger.error(f"CRITICAL: Failed to create cache directory at {CACHE_DIR}: {e}. Caching will likely fail.", exc_info=True)
    # Depending on requirements, might want to raise an error here

# --- Perenual Client Class ---
class PerenualClient:
    """
    Client for interacting with the Perenual API, with persistent disk caching
    using the 'diskcache' library. Handles API key loading and provides
    methods for searching species and fetching details, plus cache management.
    """
    def __init__(self):
        """Initializes the client, API key, and disk caches."""
        self.api_key = os.getenv("PERENUAL_API_KEY")
        if not self.api_key:
            logger.warning("PERENUAL_API_KEY environment variable not found in .env file. Perenual API features will be disabled.")
            # Optionally raise ValueError("PERENUAL_API_KEY not set.")

        self._api_base_url = "https://perenual.com/api"

        # Initialize disk caches within the designated directory
        details_cache_path = CACHE_DIR / "perenual_details"
        search_cache_path = CACHE_DIR / "perenual_search"
        logger.info(f"Initializing details disk cache at: {details_cache_path}")
        logger.info(f"Initializing search disk cache at: {search_cache_path}")

        try:
            # diskcache.Cache handles directory creation if needed, locking, etc.
            self._details_cache = diskcache.Cache(str(details_cache_path))
            self._search_cache = diskcache.Cache(str(search_cache_path))
        except Exception as e:
            logger.error(f"CRITICAL: Failed to initialize diskcache objects: {e}. Caching disabled.", exc_info=True)
            # Set caches to None or dummy objects if error occurs?
            self._details_cache = None
            self._search_cache = None           

        logger.info("PerenualClient initialized.")


    async def search_species_by_name(self, query_name: str) -> Optional[List[Dict[str, Any]]]:
        """
        Searches Perenual species list by name. Checks disk cache first.
        Caches results (including empty lists for non-matches) for 7 days.
        Returns None if search fails, API key missing, or query is invalid.
        Returns an empty list if the search was successful but yielded no results.
        """
        if not self.api_key:
            logger.warning("Cannot perform Perenual search: API key is missing.")
            return None
        if not self._search_cache:
            logger.error("Cannot perform Perenual search: Search cache is not initialized.")
            return None # Cache failed to initialize
        if not query_name or not isinstance(query_name, str) or \
           query_name.strip().lower() in ["unknown", "classification failed", "unknown species in map", ""]:
            logger.info(f"Skipping Perenual search for ambiguous or invalid name: '{query_name}'")
            return None # Return None for invalid queries, don't cache

        # Use normalized query for cache key consistency
        normalized_query = query_name.strip().lower()

        # 1. Check cache
        try:
            # Use get() which returns None if key doesn't exist
            cached_result = self._search_cache.get(normalized_query)
            if cached_result is not None: # Must check for None, as [] (empty list) is a valid cached value
                logger.info(f"Disk Cache HIT for Perenual search: '{normalized_query}'")
                # Return the list (could be empty), not None
                return cached_result
        except Exception as e:
             # Log error but proceed to API call if cache access fails
             logger.error(f"Error accessing search cache for '{normalized_query}': {e}", exc_info=True)

        logger.info(f"Disk Cache MISS for Perenual search: '{normalized_query}'")

        # 2. Prepare and execute API call
        encoded_query = query_name.strip().replace(" ", "%20")
        url = f"{self._api_base_url}/v2/species-list?key={self.api_key}&q={encoded_query}"
        # Hide API key in log message for security
        log_url = url.replace(self.api_key, '***')
        logger.info(f"Requesting Perenual API (Search): {log_url}")

        async with httpx.AsyncClient(timeout=15.0) as client: # Slightly longer timeout
            try:
                response = await client.get(url)
                response.raise_for_status() # Raises exception for 4xx/5xx responses
                data = response.json()
                # Assume results are in the 'data' field based on Perenual docs
                species_list = data.get("data", [])
                log_msg_suffix = "results" if species_list else "no results"
                logger.info(f"Perenual search API successful for '{query_name}', received {len(species_list)} {log_msg_suffix}.")

                # 3. Cache the result (even if empty)
                try:
                    # Cache successful results (including empty list) for 7 days
                    self._search_cache.set(normalized_query, species_list, expire=60*60*24*7)
                    logger.info(f"Stored search result for '{normalized_query}' in disk cache.")
                except Exception as e:
                     # Log error but return the fetched data anyway
                     logger.error(f"Error saving search result to cache for '{normalized_query}': {e}", exc_info=True)

                return species_list # Return the list (could be empty)

            # --- Error Handling for API Call ---
            except httpx.HTTPStatusError as e:
                # Specific logging for different HTTP errors
                if e.response.status_code == 429: # Too Many Requests
                     logger.warning(f"Perenual API rate limit hit (429) during search for '{query_name}'.")
                elif e.response.status_code == 401: # Unauthorized
                     logger.error(f"Perenual API key invalid or unauthorized (401) during search for '{query_name}'.")
                # Add other specific codes if needed (400 Bad Request, etc.)
                else:
                     # General HTTP error logging
                     logger.error(f"Perenual API search HTTP error for '{query_name}': Status {e.response.status_code} - Response: {e.response.text[:200]}...") # Log start of response text
                return None # Return None on API errors
            except httpx.RequestError as e:
                 # Network-level errors (DNS, connection timeout, etc.)
                 logger.error(f"Network error during Perenual API search for '{query_name}': {e}", exc_info=True)
                 return None
            except json.JSONDecodeError as e:
                 # If Perenual returns invalid JSON
                 logger.error(f"Failed to decode JSON response from Perenual search API for '{query_name}': {e}. Response starts: {response.text[:200]}...", exc_info=True)
                 return None
            except Exception as e:
                 # Catch-all for other unexpected errors during the process
                 logger.error(f"Unexpected error during Perenual API search processing for '{query_name}': {e}", exc_info=True)
                 return None


    async def get_species_details(self, species_id: int) -> Optional[Dict[str, Any]]:
        """
        Fetches species details by ID from Perenual. Checks disk cache first.
        Caches successful results for 30 days. Returns None on failure.
        """
        if not self.api_key:
            logger.warning("Cannot fetch Perenual details: API key is missing.")
            return None
        if not self._details_cache:
             logger.error("Cannot fetch Perenual details: Details cache is not initialized.")
             return None # Cache failed to initialize
        if not isinstance(species_id, int) or species_id <= 0:
             logger.warning(f"Invalid Perenual species ID provided for details fetch: {species_id}")
             return None

        # 1. Check cache
        try:
            cached_result = self._details_cache.get(species_id)
            if cached_result:
                logger.info(f"Disk Cache HIT for Perenual details: ID {species_id}")
                return cached_result
        except Exception as e:
             logger.error(f"Error accessing details cache for ID {species_id}: {e}", exc_info=True)
             # Proceed to API call if cache access fails

        logger.info(f"Disk Cache MISS for Perenual details: ID {species_id}")

        # 2. Prepare and execute API call
        url = f"{self._api_base_url}/v2/species/details/{species_id}?key={self.api_key}"
        log_url = url.replace(self.api_key, '***')
        logger.info(f"Requesting Perenual API (Details): {log_url}")

        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()
                logger.info(f"Perenual API details fetched successfully for species ID {species_id}.")

                # 3. Cache the successful result
                try:
                    # Cache details for 30 days
                    self._details_cache.set(species_id, data, expire=60*60*24*30)
                    logger.info(f"Stored details for ID {species_id} in disk cache.")
                except Exception as e:
                    logger.error(f"Error saving details result to cache for ID {species_id}: {e}", exc_info=True)
                    # Return fetched data even if caching fails

                return data # Return the fetched data

            # --- Error Handling for API Call ---
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404: # Not Found - Plant ID doesn't exist on Perenual
                     logger.warning(f"Perenual API details returned 404 Not Found for ID {species_id}. This ID likely does not exist on Perenual.")                     
                elif e.response.status_code == 429:
                     logger.warning(f"Perenual API rate limit hit (429) fetching details for ID {species_id}.")
                elif e.response.status_code == 401:
                     logger.error(f"Perenual API key invalid or unauthorized (401) fetching details for ID {species_id}.")
                else:
                     logger.error(f"Perenual API details HTTP error for ID {species_id}: Status {e.response.status_code} - Response: {e.response.text[:200]}...")
                return None # Return None on API errors
            except httpx.RequestError as e:
                 logger.error(f"Network error during Perenual API details fetch for ID {species_id}: {e}", exc_info=True)
                 return None
            except json.JSONDecodeError as e:
                 logger.error(f"Failed to decode JSON response from Perenual details API for ID {species_id}: {e}. Response starts: {response.text[:200]}...", exc_info=True)
                 return None
            except Exception as e:
                 logger.error(f"Unexpected error during Perenual API details processing for ID {species_id}: {e}", exc_info=True)
                 return None

    # --- Manual Cache Management Methods ---

    def add_or_update_details_cache(self, species_id: int, details_data: Dict[str, Any]) -> bool:
        """
        Manually adds or updates an entry in the details disk cache.
        Sets expiration to None (persists indefinitely until updated/deleted).
        Use this via a separate script for maintenance.
        Returns True on success, False on failure.
        """
        if not self._details_cache:
            logger.error("[Manual Cache] Details cache not initialized, cannot set entry.")
            return False
        if not isinstance(species_id, int) or species_id <= 0:
            logger.error(f"[Manual Cache] Invalid species ID provided for set: {species_id}")
            return False
        if not isinstance(details_data, dict) or not details_data:
             logger.error(f"[Manual Cache] Invalid or empty details data dict provided for ID {species_id}")
             return False

        try:
            # expire=None means the entry will not expire automatically
            logger.info(f"[Manual Cache] Successfully set/updated details for ID {species_id} in disk cache.")
            return True
        except Exception as e:
             logger.error(f"[Manual Cache] Failed to set/update details for ID {species_id} in cache: {e}", exc_info=True)
             return False

    def get_cached_detail_entry(self, species_id: int) -> Optional[Dict[str, Any]]:
        """
        Retrieves an entry directly from the details cache, bypassing API checks.
        Returns the cached data dict or None if not found or error occurs.
        """
        if not self._details_cache:
            logger.error("[Manual Cache] Details cache not initialized, cannot get entry.")
            return None
        if not isinstance(species_id, int) or species_id <= 0:
             logger.warning(f"[Manual Cache] Invalid species ID provided for get: {species_id}")
             return None
        try:
            entry = self._details_cache.get(species_id)
            if entry:
                 logger.info(f"[Manual Cache] Retrieved details for ID {species_id} from cache.")
            else:
                 logger.info(f"[Manual Cache] Details for ID {species_id} not found in cache.")
            return entry # Returns None if not found
        except Exception as e:
             logger.error(f"[Manual Cache] Error getting details for ID {species_id} from cache: {e}", exc_info=True)
             return None

    def delete_detail_entry(self, species_id: int) -> bool:
         """
         Deletes an entry from the details cache.
         Returns True if deletion occurred or key didn't exist, False on error.
         """
         if not self._details_cache:
             logger.error("[Manual Cache] Details cache not initialized, cannot delete entry.")
             return False
         if not isinstance(species_id, int) or species_id <= 0:
             logger.warning(f"[Manual Cache] Invalid species ID provided for delete: {species_id}")
             return False
         try:
             # Use __contains__ for checking existence
             if species_id in self._details_cache:
                 del self._details_cache[species_id] # Use del for removal
                 logger.info(f"[Manual Cache] Removed entry for ID {species_id} from details cache.")
                 return True
             else:
                 logger.warning(f"[Manual Cache] Entry for ID {species_id} not found in details cache for deletion.")
                 return True # Considered success if key doesn't exist
         except Exception as e:
              logger.error(f"[Manual Cache] Error deleting details for ID {species_id} from cache: {e}", exc_info=True)
              return False

    # --- Cache Closure ---
    def close_caches(self):
         """Closes the disk cache connections cleanly."""
         logger.info("Attempting to close Perenual disk caches...")
         closed_details, closed_search = True, True
         try:
            if self._details_cache:
                self._details_cache.close()
            else:
                 logger.warning("Details cache was not initialized, cannot close.")
                 closed_details = False
         except Exception as e:
             logger.error(f"Error closing details disk cache: {e}", exc_info=True)
             closed_details = False

         try:
             if self._search_cache:
                 self._search_cache.close()
             else:
                  logger.warning("Search cache was not initialized, cannot close.")
                  closed_search = False
         except Exception as e:
              logger.error(f"Error closing search disk cache: {e}", exc_info=True)
              closed_search = False

         if closed_details and closed_search:
              logger.info("Perenual disk caches closed.")
         else:
              logger.warning("One or both Perenual disk caches did not close cleanly.")


# --- Singleton Instance ---
# Create a single, module-level instance of the client.
# Other modules (like server_main.py) will import this instance.
perenual_client = PerenualClient()


# --- Example Usage (for testing this file directly) ---
if __name__ == "__main__":
    import asyncio

    async def test_client():
        print("\n--- Testing Perenual Client ---")
        # Ensure .env file has PERENUAL_API_KEY

        # Test Search (Use a common plant name)
        test_query = "Monstera deliciosa" # Use a specific, common name
        print(f"\n[Test] Searching for: '{test_query}'...")
        search_results = await perenual_client.search_species_by_name(test_query)

        first_id = None
        if search_results is not None: # Check for None (API failure)
            print(f"[Test] Search returned {len(search_results)} result(s).")
            if search_results: # Check if list is not empty
                first_result = search_results[0]
                first_id = first_result.get('id')
                print(f"[Test] First result ID: {first_id}, Name: {first_result.get('common_name')}")
            else:
                print("[Test] Search returned zero results.")
        else:
            print("[Test] Search failed (returned None - check logs for errors like API key).")

        # Test Details Fetch (if ID was found)
        if first_id:
            print(f"\n[Test] Fetching details for ID: {first_id}...")
            details = await perenual_client.get_species_details(first_id)
            if details:
                print(f"[Test] Details found. Common name: {details.get('common_name')}, Watering: {details.get('watering')}")
            else:
                print("[Test] Failed to fetch details (returned None).")

            # Test Details Cache Hit
            print(f"\n[Test] Fetching details again for ID: {first_id} (expecting cache hit)...")
            details_cached = await perenual_client.get_species_details(first_id)
            if details_cached:
                print(f"[Test] Details found from cache for ID {first_id}.")
            else:
                print("[Test] Failed to fetch details from cache (unexpected).")

        # Test Manual Cache Management
        print("\n--- [Test] Manual Cache Management ---")
        test_id = 999999 # Dummy ID unlikely to exist
        dummy_data = {"id": test_id, "common_name": "Manual Test Plant", "watering": "Manual", "description": "Manually added via script"}

        print(f"\n[Test] Manually adding/updating details for ID {test_id}...")
        success_set = perenual_client.add_or_update_details_cache(test_id, dummy_data)
        print(f"[Test] Manual set successful: {success_set}")

        print(f"\n[Test] Retrieving manually cached details for ID {test_id}...")
        manual_entry = perenual_client.get_cached_detail_entry(test_id)
        if manual_entry:
            print(f"[Test] Retrieved manual entry: {manual_entry}")
        else:
            print("[Test] Manual entry not found (check logs for set errors).")

        print(f"\n[Test] Deleting manually cached details for ID {test_id}...")
        success_del = perenual_client.delete_detail_entry(test_id)
        print(f"[Test] Manual delete successful: {success_del}")

        print(f"\n[Test] Verifying deletion for ID {test_id}...")
        deleted_entry = perenual_client.get_cached_detail_entry(test_id)
        if not deleted_entry:
            print("[Test] Verified: Deleted entry correctly not found in cache.")
        else:
             print("[Test] Error: Deleted entry still found in cache.")


        # Test Search Cache Hit
        print(f"\n[Test] Searching again for: '{test_query}' (expecting cache hit)...")
        search_results_cached = await perenual_client.search_species_by_name(test_query)
        if search_results_cached is not None:
             print(f"[Test] Found {len(search_results_cached)} results for search from cache.")
        else:
             print("[Test] Search failed from cache (unexpected).")

        # Test Unknown Search (should return [], get cached)
        unknown_query = "xyz123abcplantthatdoesntexist"
        print(f"\n[Test] Searching for unknown plant '{unknown_query}'...")
        unknown_results = await perenual_client.search_species_by_name(unknown_query)
        if unknown_results == []: # Expect empty list for successful search with no results
            print(f"[Test] Correctly received empty list for unknown plant search.")
            # Test cache for unknown
            print(f"\n[Test] Searching again for unknown plant '{unknown_query}' (expecting cache hit)...")
            unknown_results_cached = await perenual_client.search_species_by_name(unknown_query)
            if unknown_results_cached == []:
                 print(f"[Test] Correctly received empty list from cache for unknown plant search.")
            else:
                 print(f"[Test] Incorrect cache result for unknown plant: {unknown_results_cached}")
        elif unknown_results is None:
             print("[Test] Search for unknown plant failed (returned None).")
        else:
             print(f"[Test] Incorrect result for unknown plant: {unknown_results}")


        # Test Details for Non-existent ID (e.g., 999998)
        non_existent_id = 999998
        print(f"\n[Test] Fetching details for non-existent ID: {non_existent_id} (expecting 404 or None)...")
        invalid_details = await perenual_client.get_species_details(non_existent_id)
        if invalid_details is None:
             print(f"[Test] Correctly received None for non-existent ID {non_existent_id} details fetch.")
        else:
             print(f"[Test] Incorrectly received details for non-existent ID {non_existent_id}: {invalid_details}")


        print("\n--- Test Complete ---")
        perenual_client.close_caches() # Close caches at end of test run

    # Run the async test function
    asyncio.run(test_client())