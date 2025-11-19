#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 getweb.py                                                         ┃
#┃ 📙Brief     📝 Volvo VSIB Supplier Scorecard Web Scraper                         ┃
#┃ 🧾Details   🔎 Selenium-based batch scraper for Volvo supplier data with auth    ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-19 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import os
import json
from datetime import datetime

def setup_logging():
    """Setup logging to log.txt file"""
    import logging
    logging.basicConfig(
        filename='log.txt',
        level=logging.ERROR,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    return logging

def manual_chrome_driver(headless=False, user_data_dir=None):
    """
    Manual Chrome driver setup with authentication support
    
    Args:
        headless: Run in headless mode (False for manual login)
        user_data_dir: Path to Chrome user data directory to persist sessions
    """
    chrome_options = Options()
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--window-size=1920,1080")
    
    # Add options to mimic real browser and avoid detection
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    chrome_options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    
    # Use persistent profile to keep cookies/session
    if user_data_dir:
        chrome_options.add_argument(f"--user-data-dir={user_data_dir}")
        chrome_options.add_argument("--profile-directory=Default")
    
    # Enable headless for batch processing
    if headless:
        chrome_options.add_argument("--headless=new")
    
    try:
        driver = webdriver.Chrome(options=chrome_options)
        
        # Remove webdriver properties to avoid detection
        driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        
        return driver
    except Exception as e:
        print(f"Error creating Chrome driver: {e}")
        return None

def manual_login(driver, login_url="https://vsib.srv.volvo.com"):
    """
    Allow manual login - opens browser for user to login manually
    """
    print("🔑 Please login manually...")
    print(f"   Opening browser to: {login_url}")
    
    driver.get(login_url)
    
    input("\n⏸️  Press Enter after you have logged in successfully...")
    
    # Save cookies for future use
    cookies = driver.get_cookies()
    print(f"   💾 Saved {len(cookies)} cookies")
    
    return cookies

def wait_for_page_load(driver, timeout=60):
    """
    Wait for page to fully load including dynamic content
    """
    try:
        # Wait for document ready state
        WebDriverWait(driver, timeout).until(
            lambda d: d.execute_script("return document.readyState") == "complete"
        )
        
        # Wait for specific supplier scorecard elements
        try:
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.ID, "frmSearch"))
            )
            print("   ✅ Form element detected")
        except:
            print("   ⚠️  Form element not found - might be login page")
        
        # Additional wait for AJAX/dynamic content
        time.sleep(5)
        
        # Check if ViewState is present (indicates ASP.NET page loaded)
        try:
            viewstate = driver.find_element(By.ID, "__VIEWSTATE")
            if viewstate:
                print("   ✅ ViewState detected - page fully loaded")
        except:
            print("   ⚠️  ViewState not found")
        
        return True
    except Exception as e:
        print(f"   ❌ Timeout waiting for page load: {e}")
        return False

def scrape_volvo_scorecard(supplier_id, driver=None, close_driver=True, wait_time=60):
    """
    Scrape content from Volvo supplier scorecard page for specific supplier ID
    
    Args:
        supplier_id: The supplier ID to scrape
        driver: Existing driver instance (if None, creates new one)
        close_driver: Whether to close driver after scraping
        wait_time: Maximum wait time for page load
    """
    url = f"https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId={supplier_id}"
    
    # Create driver if not provided
    driver_created = False
    if not driver:
        driver = manual_chrome_driver(headless=True)
        driver_created = True
        
    if not driver:
        error_msg = f"Failed to initialize Chrome driver for supplier {supplier_id}"
        print(f"❌ {error_msg}")
        return None, error_msg
    
    try:
        print(f"🌐 Processing Supplier ID: {supplier_id}")
        print(f"   Navigating to: {url}")
        driver.get(url)
        
        # Wait for page to load completely
        print("   ⏳ Waiting for page to load...")
        if not wait_for_page_load(driver, wait_time):
            print("   ⚠️  Page load timeout")
        
        # Get page information
        current_url = driver.current_url
        page_title = driver.title
        html_content = driver.page_source
        
        print(f"   📄 Page Title: {page_title}")
        print(f"   🔗 Current URL: {current_url}")
        print(f"   📊 Content Length: {len(html_content)} characters")
        
        # Check for common issues
        page_source_lower = html_content.lower()
        
        # Check for login/authentication
        if any(term in page_title.lower() or term in page_source_lower for term in ['login', 'sign in', 'authenticate', 'logon']):
            error_msg = f"Login page detected for supplier {supplier_id} - authentication required"
            print(f"   ⚠️  {error_msg}")
            return None, error_msg
            
        # Check for access denied
        if any(term in page_source_lower for term in ['access denied', 'permission denied', 'not authorized', 'forbidden']):
            error_msg = f"Access denied for supplier {supplier_id}"
            print(f"   ❌ {error_msg}")
            return None, error_msg
        
        # Check for supplier not found
        if 'supplier not found' in page_source_lower or 'no supplier' in page_source_lower:
            error_msg = f"Supplier {supplier_id} not found"
            print(f"   ❌ {error_msg}")
            return None, error_msg
            
        # Check if we got the scorecard content
        if 'supplier scorecard' in page_source_lower and '__viewstate' in page_source_lower:
            print("   ✅ Supplier scorecard content successfully retrieved")
        else:
            print("   ⚠️  Page content may be incomplete")
            
        # Check for key scorecard elements
        key_elements = ['supplier spend', 'dependency', 'ppm', 'qpm', 'dispatch precision']
        found_elements = sum(1 for elem in key_elements if elem in page_source_lower)
        print(f"   📋 Found {found_elements}/{len(key_elements)} key scorecard elements")
        
        return {
            'html_content': html_content,
            'page_title': page_title,
            'current_url': current_url,
            'supplier_id': supplier_id,
            'timestamp': datetime.now().isoformat(),
            'content_length': len(html_content),
            'key_elements_found': found_elements
        }, None
        
    except Exception as e:
        error_msg = f"Error scraping supplier {supplier_id}: {str(e)}"
        print(f"   ❌ {error_msg}")
        
        # Take screenshot for debugging
        try:
            screenshot_name = f"data/error_screenshot_{supplier_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
            os.makedirs('data', exist_ok=True)
            driver.save_screenshot(screenshot_name)
            print(f"   📸 Screenshot saved as '{screenshot_name}'")
        except Exception as screenshot_error:
            print(f"   ⚠️  Could not save screenshot: {screenshot_error}")
            
        return None, error_msg
        
    finally:
        # Close the browser only if we created it and close_driver is True
        if driver_created and close_driver:
            try:
                driver.quit()
                print("   🔚 Browser closed")
            except:
                pass

def save_supplier_data(results, data_dir="data"):
    """
    Save scraping results for a single supplier
    """
    if not results:
        return None
    
    # Create data directory if it doesn't exist
    os.makedirs(data_dir, exist_ok=True)
    
    supplier_id = results['supplier_id']
    
    # Save HTML content
    html_filename = f"{data_dir}/{supplier_id}.html"
    try:
        with open(html_filename, "w", encoding="utf-8") as f:
            f.write(results['html_content'])
        print(f"   💾 HTML content saved to: {html_filename}")
        return html_filename
    except Exception as e:
        error_msg = f"Error saving HTML file for supplier {supplier_id}: {e}"
        print(f"   ❌ {error_msg}")
        return None

def save_batch_metadata(supplier_data, data_dir="data"):
    """
    Save batch processing metadata
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    metadata_filename = f"{data_dir}/batch_metadata_{timestamp}.json"
    
    try:
        with open(metadata_filename, "w", encoding="utf-8") as f:
            json.dump(supplier_data, f, indent=2)
        print(f"📊 Batch metadata saved to: {metadata_filename}")
    except Exception as e:
        print(f"Error saving batch metadata: {e}")

def process_supplier_batch(supplier_ids, data_dir="data", use_manual_login=False, user_data_dir=None):
    """
    Process a batch of supplier IDs
    
    Args:
        supplier_ids: List of supplier IDs to process
        data_dir: Directory to save HTML files
        use_manual_login: If True, open browser for manual login first
        user_data_dir: Chrome user data directory to persist sessions
    """
    logging = setup_logging()
    
    print("🚀 Starting Volvo Supplier Scorecard Batch Scraper")
    print("=" * 60)
    print(f"📋 Processing {len(supplier_ids)} supplier IDs")
    print(f"💾 Saving files to: {data_dir}/")
    print("=" * 60)
    
    # Create data directory
    os.makedirs(data_dir, exist_ok=True)
    
    driver = None
    
    # Handle manual login if required
    if use_manual_login:
        print("\n🔑 Manual Login Mode")
        print("-" * 50)
        driver = manual_chrome_driver(headless=False, user_data_dir=user_data_dir)
        if driver:
            manual_login(driver)
        else:
            print("❌ Failed to create driver for manual login")
            return []
    
    successful_scrapes = 0
    failed_scrapes = 0
    batch_results = []
    
    for i, supplier_id in enumerate(supplier_ids, 1):
        print(f"\n[{i}/{len(supplier_ids)}] Processing Supplier ID: {supplier_id}")
        print("-" * 50)
        
        # If we have a driver from manual login, reuse it
        results, error_msg = scrape_volvo_scorecard(
            supplier_id, 
            driver=driver if use_manual_login else None,
            close_driver=False if use_manual_login else True
        )
        
        if results and results['html_content']:
            # Save the HTML file
            filename = save_supplier_data(results, data_dir)
            
            if filename:
                successful_scrapes += 1
                batch_results.append({
                    'supplier_id': supplier_id,
                    'status': 'success',
                    'filename': filename,
                    'page_title': results['page_title'],
                    'content_length': results['content_length'],
                    'key_elements_found': results.get('key_elements_found', 0),
                    'timestamp': results['timestamp']
                })
                print(f"   ✅ Successfully processed supplier {supplier_id}")
            else:
                failed_scrapes += 1
                error_msg = f"Failed to save file for supplier {supplier_id}"
                logging.error(error_msg)
                batch_results.append({
                    'supplier_id': supplier_id,
                    'status': 'failed',
                    'error': error_msg,
                    'timestamp': datetime.now().isoformat()
                })
                print(f"   ❌ {error_msg}")
        else:
            failed_scrapes += 1
            if error_msg:
                logging.error(error_msg)
            batch_results.append({
                'supplier_id': supplier_id,
                'status': 'failed',
                'error': error_msg or "Unknown error",
                'timestamp': datetime.now().isoformat()
            })
            print(f"   ❌ Failed to process supplier {supplier_id}")
        
        # Add a small delay between requests to be respectful to the server
        if i < len(supplier_ids):
            print("   ⏳ Waiting before next request...")
            time.sleep(2)
    
    # Close driver if we created one for manual login
    if driver:
        try:
            driver.quit()
            print("\n🔚 Closing browser session")
        except:
            pass
    
    # Save batch metadata
    save_batch_metadata({
        'total_suppliers': len(supplier_ids),
        'successful': successful_scrapes,
        'failed': failed_scrapes,
        'success_rate': f"{(successful_scrapes/len(supplier_ids))*100:.1f}%" if len(supplier_ids) > 0 else "0%",
        'processing_date': datetime.now().isoformat(),
        'results': batch_results
    }, data_dir)
    
    # Print summary
    print("\n" + "=" * 60)
    print("🎉 BATCH PROCESSING COMPLETED!")
    print("=" * 60)
    print(f"📊 Summary:")
    print(f"   ✅ Successful: {successful_scrapes}")
    print(f"   ❌ Failed: {failed_scrapes}")
    print(f"   📈 Success Rate: {(successful_scrapes/len(supplier_ids))*100:.1f}%" if len(supplier_ids) > 0 else "0%")
    print(f"   💾 Files saved to: {data_dir}/")
    print(f"   📝 Error log: log.txt")
    
    return batch_results

def load_supplier_ids_from_toml(toml_path="./conf/hr.toml"):
    """
    Load unique supplier IDs (PARMA codes) from hr.toml file
    
    Args:
        toml_path: Path to the hr.toml file
        
    Returns:
        List of unique supplier IDs sorted in ascending order, or None if error
    """
    try:
        import tomli
    except ImportError:
        try:
            import tomllib as tomli
        except ImportError:
            print("❌ Error: tomli/tomllib library not available.")
            print("   Install with: pip install tomli")
            return None
    
    try:
        with open(toml_path, 'rb') as f:
            data = tomli.load(f)
        
        # Extract all parma_codes from all people
        all_codes = []
        for person in data.get('people', []):
            parma_codes = person.get('parma_codes', [])
            all_codes.extend(parma_codes)
        
        # Get unique codes and sort them
        unique_codes = sorted(set(all_codes))
        
        if not unique_codes:
            print(f"❌ Error: No PARMA codes found in {toml_path}")
            return None
        
        print(f"📋 Loaded {len(unique_codes)} unique PARMA codes from {toml_path}")
        print(f"   Codes: {unique_codes}")
        
        return unique_codes
        
    except FileNotFoundError:
        print(f"❌ Error: {toml_path} not found.")
        return None
    except Exception as e:
        print(f"❌ Error reading {toml_path}: {e}")
        return None

def main():
    """
    Main function to run the batch scraper
    """
    # Load supplier IDs from hr.toml file
    supplier_ids = load_supplier_ids_from_toml("./conf/hr.toml")
    
    if not supplier_ids:
        print("\n❌ Cannot proceed without supplier IDs. Exiting.")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("VSIB SUPPLIER SCORECARD SCRAPER")

    print("\n✅ Using headless mode")
    results = process_supplier_batch(supplier_ids, "data")

if __name__ == "__main__":
    main()