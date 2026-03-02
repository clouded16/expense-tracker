from services.parsers.ocr import OCRParser
from datetime import date

parser = OCRParser()

test_cases = {
    "swiggy": """
    SWIGGY INSTAMART PVT LTD
    Order ID: 12345
    Total: ₹260.50
    Date: 12/02/2026
    """,

    "amazon": """
    AMAZON SELLER SERVICES
    Invoice No 998877
    Grand Total 1,299.00
    2026-02-15
    """,

    "petrol": """
    INDIAN OIL PETROL PUMP
    Petrol 2L
    Amount Rs 450
    10-02-2026
    """,

    "noise": """
    RANDOM TEXT
    Invoice Ref 998877665544
    Something something
    """
}

for name, text in test_cases.items():
    print(f"\n--- {name.upper()} ---")
    result = parser.parse(text, None, None)
    print(result)