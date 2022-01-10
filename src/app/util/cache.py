import functools
from inspect import signature


# functools.lru_cache does not quite do what we need (cached=False by default, overwritable)
def cached(from_cache_by_default=False):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, from_cache=from_cache_by_default, **kwargs):
            # add positional args to kwargs
            arg_names = list(signature(func).parameters.keys())
            for i, arg_value in enumerate(args):
                kwargs[arg_names[i]] = arg_value

            if not hasattr(func, "cache"):
                func.cache = {}

            # convert kwargs dict into immutable set of tuples
            cache_key = frozenset(kwargs.items())

            # get result from cache if applicable
            if from_cache and cache_key in func.cache:
                result = func.cache[cache_key]
            else:
                result = func(**kwargs)
                func.cache[cache_key] = result

            return result

        return wrapper

    return decorator
