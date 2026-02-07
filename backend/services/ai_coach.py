def rephrase_insights(feed, tone="coach"):
    """
    Mock AI layer that rewrites messages.
    Replace with real AI later.
    """

    rewritten = []

    for item in feed:
        message = item["message"]

        if tone == "coach":
            message = f"Here’s something to consider: {message}"
        elif tone == "friendly":
            message = f"Just a heads up 🙂 {message}"

        item["message"] = message
        rewritten.append(item)

    return rewritten
