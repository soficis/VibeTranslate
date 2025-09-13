import time
import random
import logging
from functools import wraps

# Configure logging
logger = logging.getLogger(__name__)

class RateLimiter:
    """
    A rate limiter that uses an exponential backoff strategy.
    """
    def __init__(self, initial_delay=1.0, max_delay=60.0, factor=2.0, jitter=0.5, max_retries=5):
        self.initial_delay = initial_delay
        self.max_delay = max_delay
        self.factor = factor
        self.jitter = jitter
        self.max_retries = max_retries
        self.delay = initial_delay
        self.retries = 0
        self.adaptive_delay = None

    def wait(self):
        """
        Waits for the calculated delay time.
        """
        if self.retries > 0:
            if self.adaptive_delay:
                delay = self.adaptive_delay
                self.adaptive_delay = None  # Reset after use
            else:
                delay = self.delay + random.uniform(0, self.jitter)
            
            logger.info(f"Rate limit hit. Waiting for {delay:.2f} seconds.")
            time.sleep(delay)

    def success(self):
        """
        Resets the delay and retry count after a successful request.
        """
        self.delay = self.initial_delay
        self.retries = 0

    def failure(self, retry_after=None):
        """
        Increases the delay and retry count after a failed request.
        If retry_after is provided, it will be used as the delay.
        """
        if retry_after:
            self.adaptive_delay = retry_after
        else:
            self.delay = min(self.delay * self.factor, self.max_delay)
        self.retries += 1

    def should_retry(self):
        """
        Checks if the request should be retried based on the retry count.
        """
        return self.retries < self.max_retries

def rate_limited(rate_limiter):
    """
    A decorator to apply rate limiting to a function.
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            while True:
                rate_limiter.wait()
                try:
                    result = func(*args, **kwargs)
                    rate_limiter.success()
                    return result
                except Exception as e:
                    logger.warning(f"Request failed: {e}")
                    rate_limiter.failure()
                    if not rate_limiter.should_retry():
                        logger.error("Max retries exceeded.")
                        raise
        return wrapper
    return decorator
