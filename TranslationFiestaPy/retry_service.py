#!/usr/bin/env python3
"""
retry_service.py

Retry service with exponential backoff and jitter.
"""

from __future__ import annotations

import asyncio
import random
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Awaitable, Callable, Optional, TypeVar

from exceptions import MaxRetriesExceededError, NetworkError, TimeoutError, UnexpectedError
from result import Failure, Result, Success

T = TypeVar('T')


class RetryConfig:
    """Configuration for retry behavior"""

    def __init__(
        self,
        max_attempts: int = 4,
        initial_delay_seconds: float = 0.5,
        backoff_multiplier: float = 2.0,
        max_delay_seconds: float = 30.0,
        jitter_range_seconds: float = 0.5,
        retryable_exceptions: Optional[tuple[type[Exception], ...]] = None
    ):
        self.max_attempts = max_attempts
        self.initial_delay_seconds = initial_delay_seconds
        self.backoff_multiplier = backoff_multiplier
        self.max_delay_seconds = max_delay_seconds
        self.jitter_range_seconds = jitter_range_seconds
        self.retryable_exceptions = retryable_exceptions or (
            NetworkError,
            TimeoutError,
            ConnectionError,
            OSError,  # Network-related OS errors
        )

    def is_retryable_exception(self, exception: Exception) -> bool:
        """Check if an exception should trigger a retry"""
        return isinstance(exception, self.retryable_exceptions)


class RetryService:
    """Service for handling retry logic with exponential backoff and jitter"""

    def __init__(self, config: Optional[RetryConfig] = None):
        self.config = config or RetryConfig()
        self._random = random.Random()

    def _calculate_delay(self, attempt: int) -> float:
        """Calculate delay with exponential backoff and jitter"""
        # Exponential backoff: initial_delay * (multiplier ^ (attempt - 1))
        exponential_delay = (
            self.config.initial_delay_seconds *
            (self.config.backoff_multiplier ** (attempt - 1))
        )

        # Cap at maximum delay
        exponential_delay = min(exponential_delay, self.config.max_delay_seconds)

        # Add jitter to prevent thundering herd
        jitter = self._random.uniform(
            -self.config.jitter_range_seconds,
            self.config.jitter_range_seconds
        )

        # Ensure delay is not negative
        delay = max(0.1, exponential_delay + jitter)

        return delay

    def _sleep_with_jitter(self, delay: float) -> None:
        """Sleep for the specified delay"""
        time.sleep(delay)

    async def _async_sleep_with_jitter(self, delay: float) -> None:
        """Async sleep for the specified delay"""
        await asyncio.sleep(delay)

    def execute_with_retry(
        self,
        operation: Callable[[], Result[T, Exception]],
        operation_name: str = "operation",
        status_callback: Optional[Callable[[str], None]] = None,
        custom_config: Optional[RetryConfig] = None
    ) -> Result[T, Exception]:
        """
        Execute an operation with retry logic

        Args:
            operation: Function that returns a Result
            operation_name: Name of the operation for logging
            status_callback: Optional callback for status updates
            custom_config: Optional custom retry configuration

        Returns:
            Result of the operation
        """
        config = custom_config or self.config

        for attempt in range(1, config.max_attempts + 1):
            try:
                result = operation()

                if result.is_success():
                    if attempt > 1:
                        self._log_success_after_retry(operation_name, attempt)
                    return result

                # Operation failed
                error = result.error  # type: ignore

                if attempt >= config.max_attempts:
                    return Failure(
                        MaxRetriesExceededError(
                            config.max_attempts,
                            operation_name,
                            details=f"Final error: {error}"
                        )
                    )

                if not config.is_retryable_exception(error):
                    # Non-retryable error, fail immediately
                    return result

                # Calculate delay and retry
                delay = self._calculate_delay(attempt)
                self._log_retry_attempt(operation_name, attempt, config.max_attempts, delay, error)

                if status_callback:
                    status_callback(
                        f"Error in {operation_name}. Retrying in {delay:.1f}s "
                        f"(attempt {attempt}/{config.max_attempts})"
                    )

                self._sleep_with_jitter(delay)

            except Exception as e:
                # Unexpected error during operation execution
                if attempt >= config.max_attempts:
                    return Failure(
                        MaxRetriesExceededError(
                            config.max_attempts,
                            operation_name,
                            details=f"Unexpected error: {e}"
                        )
                    )

                if not config.is_retryable_exception(e):
                    return Failure(e)

                delay = self._calculate_delay(attempt)
                self._log_retry_attempt(operation_name, attempt, config.max_attempts, delay, e)

                if status_callback:
                    status_callback(
                        f"Unexpected error in {operation_name}. Retrying in {delay:.1f}s "
                        f"(attempt {attempt}/{config.max_attempts})"
                    )

                self._sleep_with_jitter(delay)

        # This should never be reached, but just in case
        return Failure(
            UnexpectedError(f"Retry loop completed unexpectedly for {operation_name}")
        )

    async def execute_with_retry_async(
        self,
        operation: Callable[[], Awaitable[Result[T, Exception]]],
        operation_name: str = "operation",
        status_callback: Optional[Callable[[str], None]] = None,
        custom_config: Optional[RetryConfig] = None
    ) -> Result[T, Exception]:
        """
        Execute an async operation with retry logic

        Args:
            operation: Async function that returns a Result
            operation_name: Name of the operation for logging
            status_callback: Optional callback for status updates
            custom_config: Optional custom retry configuration

        Returns:
            Result of the operation
        """
        config = custom_config or self.config

        for attempt in range(1, config.max_attempts + 1):
            try:
                result = await operation()

                if result.is_success():
                    if attempt > 1:
                        self._log_success_after_retry(operation_name, attempt)
                    return result

                # Operation failed
                error = result.error  # type: ignore

                if attempt >= config.max_attempts:
                    return Failure(
                        MaxRetriesExceededError(
                            config.max_attempts,
                            operation_name,
                            details=f"Final error: {error}"
                        )
                    )

                if not config.is_retryable_exception(error):
                    # Non-retryable error, fail immediately
                    return result

                # Calculate delay and retry
                delay = self._calculate_delay(attempt)
                self._log_retry_attempt(operation_name, attempt, config.max_attempts, delay, error)

                if status_callback:
                    status_callback(
                        f"Error in {operation_name}. Retrying in {delay:.1f}s "
                        f"(attempt {attempt}/{config.max_attempts})"
                    )

                await self._async_sleep_with_jitter(delay)

            except Exception as e:
                # Unexpected error during operation execution
                if attempt >= config.max_attempts:
                    return Failure(
                        MaxRetriesExceededError(
                            config.max_attempts,
                            operation_name,
                            details=f"Unexpected error: {e}"
                        )
                    )

                if not config.is_retryable_exception(e):
                    return Failure(e)

                delay = self._calculate_delay(attempt)
                self._log_retry_attempt(operation_name, attempt, config.max_attempts, delay, e)

                if status_callback:
                    status_callback(
                        f"Unexpected error in {operation_name}. Retrying in {delay:.1f}s "
                        f"(attempt {attempt}/{config.max_attempts})"
                    )

                await self._async_sleep_with_jitter(delay)

        # This should never be reached, but just in case
        return Failure(
            UnexpectedError(f"Async retry loop completed unexpectedly for {operation_name}")
        )

    def execute_backtranslation_with_retry(
        self,
        first_operation: Callable[[], Result[T, Exception]],
        second_operation_factory: Callable[[T], Result[Any, Exception]],
        original_text: str,
        status_callback: Optional[Callable[[str], None]] = None,
        custom_config: Optional[RetryConfig] = None
    ) -> Result[tuple[T, Any], Exception]:
        """
        Execute backtranslation with proper retry handling for both steps

        Args:
            first_operation: First translation operation (e.g., English -> Japanese)
            second_operation_factory: Factory for second operation using first result
            original_text: Original text for context
            status_callback: Optional callback for status updates
            custom_config: Optional custom retry configuration

        Returns:
            Result containing tuple of (first_result, second_result)
        """
        start_time = datetime.now(timezone.utc)
        config = custom_config or self.config

        # First translation
        if status_callback:
            status_callback("Starting first translation...")

        first_result = self.execute_with_retry(
            first_operation,
            "first translation",
            status_callback,
            config
        )

        if first_result.is_failure():
            return Failure(first_result.error)  # type: ignore

        first_value = first_result.value  # type: ignore

        # Second translation
        if status_callback:
            status_callback("Starting second translation...")

        def second_operation():
            return second_operation_factory(first_value)

        second_result = self.execute_with_retry(
            second_operation,
            "second translation",
            status_callback,
            config
        )

        if second_result.is_failure():
            return Failure(second_result.error)  # type: ignore

        second_value = second_result.value  # type: ignore
        total_duration = datetime.now(timezone.utc) - start_time

        self._log_backtranslation_success(
            len(original_text),
            len(str(first_value)),
            len(str(second_value)),
            total_duration
        )

        return Success((first_value, second_value))

    def _log_retry_attempt(
        self,
        operation_name: str,
        attempt: int,
        max_attempts: int,
        delay: float,
        error: Exception
    ) -> None:
        """Log retry attempt details"""
        print(f"[RETRY] {operation_name} attempt {attempt}/{max_attempts} failed: {error}")
        print(f"[RETRY] Waiting {delay:.1f}s before retry...")

    def _log_success_after_retry(self, operation_name: str, attempt: int) -> None:
        """Log successful operation after retries"""
        print(f"[SUCCESS] {operation_name} succeeded on attempt {attempt}")

    def _log_backtranslation_success(
        self,
        original_length: int,
        first_length: int,
        second_length: int,
        duration: timedelta
    ) -> None:
        """Log successful backtranslation completion"""
        print(
            f"[BACKTRANSLATION] Completed successfully: "
            f"{original_length} -> {first_length} -> {second_length} chars "
            f"in {duration.total_seconds():.2f}s"
        )


# Convenience functions for common retry patterns
def with_retry(
    operation: Callable[[], Result[T, Exception]],
    operation_name: str = "operation",
    max_attempts: int = 4,
    status_callback: Optional[Callable[[str], None]] = None
) -> Result[T, Exception]:
    """Convenience function for executing operations with retry"""
    config = RetryConfig(max_attempts=max_attempts)
    service = RetryService(config)
    return service.execute_with_retry(operation, operation_name, status_callback)


async def with_retry_async(
    operation: Callable[[], Awaitable[Result[T, Exception]]],
    operation_name: str = "operation",
    max_attempts: int = 4,
    status_callback: Optional[Callable[[str], None]] = None
) -> Result[T, Exception]:
    """Convenience function for executing async operations with retry"""
    config = RetryConfig(max_attempts=max_attempts)
    service = RetryService(config)
    return await service.execute_with_retry_async(operation, operation_name, status_callback)
