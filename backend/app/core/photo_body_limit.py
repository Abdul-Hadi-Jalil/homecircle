from starlette.responses import JSONResponse


class PhotoBodyLimit:
    """Bound photo JSON before FastAPI buffers/parses it, including chunked bodies."""

    def __init__(self, app, max_bytes=8 * 1024 * 1024):
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope, receive, send):
        path = scope.get("path", "")
        photo = (
            scope.get("method") == "PUT" and "/inventory/" in path and path.endswith("/photo")
        ) or (scope.get("method") == "POST" and "/tasks/" in path and path.endswith("/attachments"))
        if scope["type"] != "http" or not photo:
            return await self.app(scope, receive, send)
        messages, size = [], 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            size += len(message.get("body", b""))
            if size > self.max_bytes:
                return await JSONResponse(
                    {
                        "error": {
                            "code": "photo_too_large",
                            "message": "Photo request is too large.",
                        }
                    },
                    status_code=413,
                )(scope, receive, send)
            messages.append(message)
            if not message.get("more_body", False):
                break
        iterator = iter(messages)

        async def replay():
            message = next(iterator, None)
            return message if message is not None else await receive()

        await self.app(scope, replay, send)
