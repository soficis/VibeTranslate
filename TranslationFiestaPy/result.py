#!/usr/bin/env python3
"""
result.py

Result/Either pattern implementation for type-safe error handling.
Following functional programming principles similar to Flutter's Either type.
"""

from __future__ import annotations
from typing import Generic, TypeVar, Union, Callable, Any, Optional
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime

from exceptions import TranslationFiestaError

T = TypeVar('T')  # Success type
E = TypeVar('E')  # Error type


class Result(Generic[T, E], ABC):
    """Base class for Result type (Either pattern)"""

    def __init__(self):
        pass

    @abstractmethod
    def is_success(self) -> bool:
        """Returns True if this is a success result"""
        pass

    @abstractmethod
    def is_failure(self) -> bool:
        """Returns True if this is a failure result"""
        pass

    @abstractmethod
    def fold(self, on_success: Callable[[T], Any], on_failure: Callable[[E], Any]) -> Any:
        """Pattern matching for Result values"""
        pass

    @abstractmethod
    def map(self, transform: Callable[[T], Any]) -> Result[Any, E]:
        """Transform the success value if this is Success"""
        pass

    @abstractmethod
    def map_error(self, transform: Callable[[E], Any]) -> Result[T, Any]:
        """Transform the error value if this is Failure"""
        pass

    @abstractmethod
    def flat_map(self, transform: Callable[[T], Result[Any, E]]) -> Result[Any, E]:
        """Transform the success value to another Result if this is Success"""
        pass

    @abstractmethod
    def get_or_else(self, default: Callable[[], T]) -> T:
        """Get the success value or return the provided default"""
        pass

    @abstractmethod
    def get_or_null(self) -> Optional[T]:
        """Get the success value or return None if this is Failure"""
        pass

    @abstractmethod
    def on_success(self, action: Callable[[T], None]) -> Result[T, E]:
        """Execute action if this is Success, return self"""
        pass

    @abstractmethod
    def on_failure(self, action: Callable[[E], None]) -> Result[T, E]:
        """Execute action if this is Failure, return self"""
        pass


@dataclass
class Success(Generic[T, E], Result[T, E]):
    """Represents a successful result"""
    value: T

    def is_success(self) -> bool:
        return True

    def is_failure(self) -> bool:
        return False

    def fold(self, on_success: Callable[[T], Any], on_failure: Callable[[E], Any]) -> Any:
        return on_success(self.value)

    def map(self, transform: Callable[[T], Any]) -> Result[Any, E]:
        try:
            return Success(transform(self.value))
        except Exception as e:
            return Failure(e)

    def map_error(self, transform: Callable[[E], Any]) -> Result[T, Any]:
        return Success(self.value)  # No transformation needed for success

    def flat_map(self, transform: Callable[[T], Result[Any, E]]) -> Result[Any, E]:
        try:
            return transform(self.value)
        except Exception as e:
            return Failure(e)

    def get_or_else(self, default: Callable[[], T]) -> T:
        return self.value

    def get_or_null(self) -> Optional[T]:
        return self.value

    def on_success(self, action: Callable[[T], None]) -> Result[T, E]:
        try:
            action(self.value)
        except Exception:
            pass  # Best effort, don't change result
        return self

    def on_failure(self, action: Callable[[E], None]) -> Result[T, E]:
        return self  # No action for success

    def __str__(self) -> str:
        return f"Success({self.value})"

    def __eq__(self, other) -> bool:
        return isinstance(other, Success) and self.value == other.value


@dataclass
class Failure(Generic[T, E], Result[T, E]):
    """Represents a failed result"""
    error: E

    def is_success(self) -> bool:
        return False

    def is_failure(self) -> bool:
        return True

    def fold(self, on_success: Callable[[T], Any], on_failure: Callable[[E], Any]) -> Any:
        return on_failure(self.error)

    def map(self, transform: Callable[[T], Any]) -> Result[Any, E]:
        return Failure(self.error)  # No transformation for failure

    def map_error(self, transform: Callable[[E], Any]) -> Result[T, Any]:
        try:
            return Failure(transform(self.error))
        except Exception as e:
            return Failure(e)

    def flat_map(self, transform: Callable[[T], Result[Any, E]]) -> Result[Any, E]:
        return Failure(self.error)  # No transformation for failure

    def get_or_else(self, default: Callable[[], T]) -> T:
        return default()

    def get_or_null(self) -> Optional[T]:
        return None

    def on_success(self, action: Callable[[T], None]) -> Result[T, E]:
        return self  # No action for failure

    def on_failure(self, action: Callable[[E], None]) -> Result[T, E]:
        try:
            action(self.error)
        except Exception:
            pass  # Best effort, don't change result
        return self

    def __str__(self) -> str:
        return f"Failure({self.error})"

    def __eq__(self, other) -> bool:
        return isinstance(other, Failure) and self.error == other.error


# Type aliases for common use cases
TranslationResult = Result[str, TranslationFiestaError]
FileResult = Result[str, TranslationFiestaError]
StorageResult = Result[Any, TranslationFiestaError]


# Utility functions
def success(value: T) -> Result[T, Any]:
    """Create a successful result"""
    return Success(value)


def failure(error: E) -> Result[Any, E]:
    """Create a failed result"""
    return Failure(error)


def from_nullable(value: Optional[T], error: E) -> Result[T, E]:
    """Create a Result from a nullable value"""
    if value is None:
        return Failure(error)
    return Success(value)


def from_exception(func: Callable[[], T]) -> Result[T, Exception]:
    """Execute a function and wrap result in Result, catching exceptions"""
    try:
        return Success(func())
    except Exception as e:
        return Failure(e)


def sequence(results: list[Result[T, E]]) -> Result[list[T], E]:
    """Convert a list of Results to a Result of list"""
    values = []
    for result in results:
        if result.is_failure():
            return Failure(result.error)  # type: ignore
        values.append(result.value)  # type: ignore
    return Success(values)


def traverse(results: list[Result[T, E]], transform: Callable[[T], Any]) -> Result[list[Any], E]:
    """Transform each success value and collect results"""
    transformed = []
    for result in results:
        if result.is_failure():
            return Failure(result.error)  # type: ignore
        try:
            transformed.append(transform(result.value))  # type: ignore
        except Exception as e:
            return Failure(e)
    return Success(transformed)


# Convenience functions for common patterns
def map2(
    result1: Result[T, E],
    result2: Result[Any, E],
    combine: Callable[[T, Any], Any]
) -> Result[Any, E]:
    """Combine two Results using a function"""
    if result1.is_failure():
        return Failure(result1.error)  # type: ignore
    if result2.is_failure():
        return Failure(result2.error)  # type: ignore

    try:
        return Success(combine(result1.value, result2.value))  # type: ignore
    except Exception as e:
        return Failure(e)


def recover(result: Result[T, E], recovery: Callable[[E], T]) -> Result[T, E]:
    """Recover from a failure by providing a default value"""
    if result.is_success():
        return result
    try:
        return Success(recovery(result.error))  # type: ignore
    except Exception as e:
        return Failure(e)


def recover_with(result: Result[T, E], recovery: Callable[[E], Result[T, E]]) -> Result[T, E]:
    """Recover from a failure by providing a recovery function that returns a Result"""
    if result.is_success():
        return result
    try:
        return recovery(result.error)  # type: ignore
    except Exception as e:
        return Failure(e)