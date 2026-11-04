import asyncio


def create_event_loop() -> asyncio.AbstractEventLoop:
    """Psycopg async connections require a Selector loop, including on Windows."""
    return asyncio.SelectorEventLoop()
