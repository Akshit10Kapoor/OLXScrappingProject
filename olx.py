from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

# Initialize titles list
titles = []

# --- Setup Chrome options ---
options = Options()
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_experimental_option("excludeSwitches", ["enable-automation"])
options.add_experimental_option('useAutomationExtension', False)
options.add_argument("--start-maximized")

# Add these options to help with SSL errors
options.add_argument('--ignore-certificate-errors')
options.add_argument('--ignore-ssl-errors')

driver = webdriver.Chrome(service=Service(), options=options)

# Bypass navigator.webdriver detection
driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {
    "source": """
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined
      });
    """
})

wait = WebDriverWait(driver, 20)

try:
    print("Opening OLX...")
    driver.get("https://www.olx.in/")
    time.sleep(5)  # Initial page load

    # Accept cookies if the popup appears
    try:
        cookie_accept = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "button[id='onetrust-accept-btn-handler']")))
        cookie_accept.click()
        print("Accepted cookies")
        time.sleep(1)
    except:
        print("No cookie popup found")

    print("Searching for 'car covers'...")
    try:
        search_box = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "input[data-aut-id='searchBox']")))
        search_box.clear()
        search_box.send_keys("car covers")
        time.sleep(1)
        search_box.send_keys(Keys.ENTER)
    except Exception as e:
        print("Error in search:", e)
        raise

    print("Waiting for results...")
    try:
        # Wait for results to load
        wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "div[data-aut-id='itemsList'], div[data-aut-id='noResults']")))
        
        # Check if no results found
        no_results = driver.find_elements(By.CSS_SELECTOR, "div[data-aut-id='noResults']")
        if no_results:
            print("No results found for 'car covers'")
        else:
            print("Results found, collecting data...")
            # Scroll to load more items
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2)
            
            # Get all items
            items = wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "li[data-aut-id='itemBox']")))
            
            for idx, item in enumerate(items[:6]):  # Limit to first 6 items
                try:
                    title_el = item.find_element(By.CSS_SELECTOR, "span[data-aut-id='itemTitle']")
                    title = title_el.text.strip()
                    if title:
                        titles.append(title)
                        print(f"{len(titles)}. {title}")
                except Exception as e:
                    print(f"Skipping item {idx+1} due to error: {str(e)[:100]}...")
                    continue
    except Exception as e:
        print("Error in results processing:", e)

except Exception as e:
    print("Error during scraping:", e)
finally:
    driver.quit()

# Save results
if titles:
    with open("car_covers.txt", "w", encoding="utf-8") as f:
        for i, title in enumerate(titles, 1):
            f.write(f"{i}. {title}\n")
    print(f"Top {len(titles)} car covers saved to car_covers.txt")
else:
    print("No titles found.")