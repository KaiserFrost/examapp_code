
#!/usr/bin/env python3
"""
generate_exam_json.py
----------------------------------------------------
Scraper for ExamTopics discussion pages that generates a single JSON file.
"""

import os
import re
import json
import time
import random
import logging
import argparse
from pathlib import Path
from urllib.parse import urljoin, urlparse
import urllib.robotparser
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter, Retry

# ---------- CONFIG ----------
DELAY_SECONDS = 1.5
TIMEOUT = 20
MAX_RETRIES = 3
DEFAULT_CONCURRENCY = 4
# ----------------------------

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) "
    "Version/18.0 Safari/605.1.15",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:132.0) "
    "Gecko/20100101 Firefox/132.0",
]

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

def can_fetch(url: str) -> bool:
    """Check robots.txt to ensure scraping is allowed."""
    parsed = urlparse(url)
    robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"
    rp = urllib.robotparser.RobotFileParser()
    try:
        rp.set_url(robots_url)
        rp.read()
        allowed = rp.can_fetch(USER_AGENTS[0], url)
        if not allowed:
            logging.warning("robots.txt disallows scraping %s", url)
        return allowed
    except Exception as e:
        logging.warning("Could not read robots.txt (%s): %s", robots_url, e)
        return True

def make_session():
    """Create HTTP session with retry + random UA."""
    s = requests.Session()
    ua = random.choice(USER_AGENTS)
    s.headers.update({"User-Agent": ua})
    retries = Retry(total=MAX_RETRIES, backoff_factor=1,
                    status_forcelist=[429, 500, 502, 503, 504])
    s.mount("https://", HTTPAdapter(max_retries=retries))
    s.mount("http://", HTTPAdapter(max_retries=retries))
    return s

def extract_links(html: str, base_url: str):
    """Extract discussion links from a listing page."""
    soup = BeautifulSoup(html, "html.parser")
    links = []
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        if not href.startswith("/discussions/"):
            continue
        title = a.get_text(strip=True)
        if title:
            links.append((title, urljoin(base_url, href)))
    return links

def extract_question_data(soup: BeautifulSoup, url: str) -> dict:
    """Extracts structured data for a single question."""
    data = {"url": url}

    # Extract title
    title_tag = soup.find("h1", class_="discussion-list-header")
    if not title_tag:
        title_tag = soup.find("title")
    data["title"] = title_tag.get_text(strip=True) if title_tag else "No Title"


    # Extract topic and question number from title
    topic_match = re.search(r"topic\W*(\d+)", data["title"], re.I)
    question_match = re.search(r"question\W*(\d+)", data["title"], re.I)
    data["topic"] = f"Topic {int(topic_match.group(1))}" if topic_match else "Misc"
    data["question_number"] = int(question_match.group(1)) if question_match else None

    # Extract question text
    question_body = soup.find("div", class_="question-body")
    if question_body:
        p_tag = question_body.find("p", class_="card-text")
        if p_tag:
            data["question_text"] = p_tag.get_text(strip=True, separator='\n')

    # Extract choices
    choices = []
    choices_container = soup.find("div", class_="question-choices-container")
    if choices_container:
        for choice_item in choices_container.find_all("li", class_="multi-choice-item"):
            letter = choice_item.find("span", class_="multi-choice-letter").get_text(strip=True).replace(".", "")
            text = choice_item.get_text(strip=True).replace(letter + ".", "").strip()
            choices.append({"letter": letter, "text": text})
    data["choices"] = choices

    # Extract correct answer
    correct_answer_span = soup.find("span", class_="correct-answer")
    if correct_answer_span:
        data["correct_answer"] = correct_answer_span.get_text(strip=True)
    else:
        data["correct_answer"] = None

    # Extract vote distribution from voting-summary div
    data["vote_distribution"] = []
    voting_summary = soup.find("div", class_="voting-summary")
    if voting_summary:
        vote_bars = voting_summary.find_all("div", class_="vote-bar")
        for bar in vote_bars:
            text = bar.get_text(strip=True)
            match = re.search(r"([A-Z]) \((\d+)%\)", text)
            if match:
                answer_letter = match.group(1)
                percentage = int(match.group(2))
                data["vote_distribution"].append({"answer": answer_letter, "percentage": percentage})
        
    # Extract discussion
    discussion = []
    comments_container = soup.find("div", class_="discussion-container")
    if comments_container:
        for comment in comments_container.find_all("div", class_="comment-container"):
            selected_answer_tag = comment.find("div", class_="comment-selected-answers")
            if selected_answer_tag:
                author_tag = comment.find("h5", class_="comment-username")
                date_tag = comment.find("span", class_="comment-date")
                comment_content_tag = comment.find("div", class_="comment-content")
                
                if author_tag and date_tag and comment_content_tag:
                    selected_answer = selected_answer_tag.find("span").get_text(strip=True)
                    discussion.append({
                        "author": author_tag.get_text(strip=True),
                        "date": date_tag.get("title"),
                        "comment": comment_content_tag.get_text(strip=True, separator='\n'),
                        "selected_answer": selected_answer
                    })
    data["discussion"] = discussion

    return data

def crawl_pages_parallel(base_url: str, keyword: str, num_pages: int, crawl_concurrency: int):
    """Crawl listing pages in parallel and collect matching links."""
    if not can_fetch(base_url):
        raise SystemExit("robots.txt disallows scraping this path.")

    base_url = base_url.rstrip("/") + "/"
    page_urls = [urljoin(base_url, f"{i}/") for i in range(1, num_pages + 1)]
    collected = []
    seen = set()
    lock = Lock()

    def fetch_listing(url):
        time.sleep(DELAY_SECONDS + random.random() * 0.15)
        sess = make_session()
        try:
            r = sess.get(url, timeout=TIMEOUT)
            if r.status_code == 404:
                logging.info("Listing %s returned 404", url)
                return []
            r.raise_for_status()
        except Exception as e:
            logging.warning("Error fetching listing %s: %s", url, e)
            return []

        links = extract_links(r.text, url)
        matches = []
        for title, link in links:
            if keyword.lower() in title.lower():
                matches.append({"title": title, "url": link})

        with lock:
            added = 0
            for it in matches:
                if it["url"] not in seen:
                    seen.add(it["url"])
                    collected.append(it)
                    added += 1
        if added:
            logging.info("Found %d new matches on %s", added, url)
        return matches

    logging.info("Crawling %d listing pages with concurrency=%d", num_pages, crawl_concurrency)
    with ThreadPoolExecutor(max_workers=crawl_concurrency) as ex:
        futures = {ex.submit(fetch_listing, u): u for u in page_urls}
        for fut in as_completed(futures):
            try:
                fut.result()
            except Exception as e:
                logging.debug("Listing worker error: %s", e)

    logging.info("Crawl complete, total matches: %d", len(collected))
    return collected

def fetch_and_process_page(item, per_request_delay):
    """Fetches a single discussion page and extracts its data."""
    url = item["url"]
    logging.info("Downloading %s", url)

    time.sleep(per_request_delay + random.random() * 0.25)
    session_local = make_session()
    session_local.headers.update({"Accept-Language": "en-US,en;q=0.9"})

    try:
        r = session_local.get(url, timeout=TIMEOUT)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        return extract_question_data(soup, url)
    except Exception as e:
        logging.error("Failed to fetch or process %s: %s", url, e)
        return None

def main():
    parser = argparse.ArgumentParser(description="Download ExamTopics discussions to a JSON file.")
    parser.add_argument("--base", required=True, help="Base discussion URL (e.g. https://www.examtopics.com/discussions/amazon/)")
    parser.add_argument("--keyword", required=True, help="Keyword or exam name (e.g. SAA-C03)")
    parser.add_argument("--pages", type=int, default=10, help="Number of pages to crawl")
    parser.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY, help="Number of parallel downloads")
    parser.add_argument("--output", type=str, default="questions.json", help="Output JSON file name")
    args = parser.parse_args()

    results = crawl_pages_parallel(
        args.base,
        args.keyword,
        args.pages,
        crawl_concurrency=max(1, args.concurrency),
    )

    if not results:
        print("No matches found.")
        return

    all_questions = []
    with ThreadPoolExecutor(max_workers=args.concurrency) as ex:
        futures = {ex.submit(fetch_and_process_page, item, DELAY_SECONDS): item for item in results}
        for fut in as_completed(futures):
            try:
                data = fut.result()
                if data:
                    all_questions.append(data)
            except Exception as e:
                logging.error("Worker error: %s", e)

    # Sort questions by topic and question number
    all_questions.sort(key=lambda x: (x.get('topic', ''), x.get('question_number', 0)))

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(all_questions, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Downloaded {len(all_questions)} discussions matching '{args.keyword}'.")
    print(f"JSON data saved to: {Path(args.output).resolve()}")

if __name__ == "__main__":
    main()
